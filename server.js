// ============================================================================
// ZAP SERVER v5.4 — Multi-User Edition + Priority Queue
// ============================================================================

const fs = require("fs");
const express = require("express");
const { execFile } = require("child_process");

const app = express();
const PORT = 3000;

app.use(express.json({ limit: "10mb" }));

// ============================================================================
// CONFIGURAÇÕES
// ============================================================================
const HOME_PATH = "/data/data/com.termux/files/home/zap-server";
const TERMUX_BASH = "/data/data/com.termux/files/usr/bin/bash";
const QUEUE_FILE = "queue.json";
const JOB_TIMEOUT_MS = 180000; // 180s para garantir envio de mídia pesada e processamento
const MAX_RETRIES = 2;

// ============================================================================
// ESTADO DO EMULADOR
// ============================================================================
let emulatorBusy = false;
let currentTask = null;

// ============================================================================
// PERSISTÊNCIA DA FILA
// ============================================================================
function loadQueueFromDisk() {
    if (!fs.existsSync(QUEUE_FILE)) return [];
    try {
        return JSON.parse(fs.readFileSync(QUEUE_FILE, "utf8"));
    } catch {
        console.error("WARN: queue.json corrompido. Criando fila vazia.");
        return [];
    }
}

function saveQueueToDisk(queue) {
    const safe = queue.map(job => {
        const { res, ...clean } = job;
        return clean;
    });
    fs.writeFileSync(QUEUE_FILE, JSON.stringify(safe, null, 2));
}

// ============================================================================
// FILA
// ============================================================================
let memoryQueue = loadQueueFromDisk();
let isProcessing = false;

// ============================================================================
// PROCESSADOR
// ============================================================================
function processQueue() {
    if (isProcessing) return;
    if (memoryQueue.length === 0) return;

    isProcessing = true;

    const job = memoryQueue.shift();
    saveQueueToDisk(memoryQueue);

    const { id, scriptName, argsArray, attempts, res, priority } = job;
    const scriptPath = `${HOME_PATH}/${scriptName}`;

    emulatorBusy = true;
    currentTask = scriptName;
    
    if(priority) {
        console.log(`🚨 EXECUTANDO PRIORIDADE: ${scriptName} (Job ${id})`);
    }

    execFile(
        "sudo",
        [TERMUX_BASH, scriptPath, ...argsArray],
        { timeout: JOB_TIMEOUT_MS },
        (error, stdout = "", stderr = "") => {

            const exitCode = error && typeof error.code === "number" ? error.code : 0;

            // ---------------------------------------------------------
            // EXIT 10 → LEAD ERRADO
            // ---------------------------------------------------------
            if (exitCode === 10) {
                emulatorBusy = false;
                currentTask = null;

                let opened = "desconhecido";
                const m = stdout.match(/Conversa aberta com outro lead:\s*(.*)/);
                if (m && m[1]) opened = m[1].trim();

                if (res && !res.headersSent) {
                    res.json({
                        success: false,
                        leadMismatch: true,
                        openedWith: opened,
                        message: "Conversa aberta com outro lead"
                    });
                }

                isProcessing = false;
                return setImmediate(processQueue);
            }

            // ---------------------------------------------------------
            // EXIT != 0 → ERRO
            // ---------------------------------------------------------
            if (exitCode !== 0) {
                emulatorBusy = false;
                currentTask = null;

                if (attempts < MAX_RETRIES) {
                    // Se falhar, volta pro início da fila (mantém prioridade se tiver)
                    memoryQueue.unshift({
                        id, scriptName, argsArray, attempts: attempts + 1, res, priority
                    });
                    saveQueueToDisk(memoryQueue);

                } else {
                    if (res && !res.headersSent) {
                        res.status(500).json({
                            success: false,
                            exitCode,
                            stdout,
                            stderr
                        });
                    }
                }

                isProcessing = false;
                return setImmediate(processQueue);
            }

            // ---------------------------------------------------------
            // EXIT 0 → SUCESSO
            // ---------------------------------------------------------
            emulatorBusy = false;
            currentTask = null;

            if (res && !res.headersSent) {
                res.json({
                    success: true,
                    output: stdout.trim()
                });
            }

            isProcessing = false;
            saveQueueToDisk(memoryQueue);
            setImmediate(processQueue);
        }
    );
}

// ============================================================================
// ENFILEIRAR JOB (COM PRIORIDADE)
// ============================================================================
let JOB_COUNTER = Date.now();

// 🆕 Alteração: Adicionado parâmetro 'priority' (padrão false)
function enqueue(scriptName, argsArray, res, priority = false) {
    const job = {
        id: ++JOB_COUNTER,
        scriptName,
        argsArray,
        attempts: 1,
        res,
        timestamp: new Date().toISOString(),
        priority: priority // Flag para log/debug
    };

    // 🆕 Lógica de Prioridade: Fura a fila ou vai pro final
    if (priority) {
        console.log(`🚨 PRIORIDADE MÁXIMA: Job ${job.id} (${scriptName}) furou a fila!`);
        memoryQueue.unshift(job); // Coloca no INÍCIO do array
    } else {
        memoryQueue.push(job); // Coloca no FINAL do array
    }

    saveQueueToDisk(memoryQueue);

    // Resposta imediata apenas se fila estiver grande e NÃO for prioridade
    // Se for prioridade, deixamos ele aguardar um pouco pois será rápido
    if (memoryQueue.length > 3 && !priority) {
        if (!res.headersSent) {
            res.json({
                success: true,
                status: "queued_async",
                jobId: job.id,
                position: memoryQueue.length
            });
            job.res = null;
        }
    }

    processQueue();
}

// ============================================================================
// ROTAS
// ============================================================================

// STATUS (GLOBAL)
app.get("/health", (req, res) => {
    res.json({
        status: "online",
        mode: "ROOT/SUDO",
        queueSize: memoryQueue.length,
        isProcessing,
        uptime: process.uptime()
    });
});

app.get("/state", (req, res) => {
    res.json({
        busy: emulatorBusy,
        currentTask,
        queueSize: memoryQueue.length,
        isProcessing,
        uptime: process.uptime()
    });
});

// ============================================================================
// ROTAS DE AÇÃO (AGORA COM :userId)
// ============================================================================

// VOLTAR
app.post("/:userId/voltar", (req, res) => 
    enqueue("voltar.sh", [req.params.userId], res)
);

// BUSCAR
app.post("/:userId/buscar", (req, res) =>
    enqueue("buscar_lead.sh", [
        req.params.userId, 
        String(req.body.numero)
    ], res)
);

// PEGAR NÚMERO
app.post("/:userId/numeroWpp", (req, res) =>
    enqueue("pegar_numero.sh", [req.params.userId], res)
);

// LIMPAR NOTIFICAÇÕES (ABRIR CONVERSA)
app.post("/:userId/limparnotificacoes", (req, res) => {
    const { action, byPhone, byTag, byKey, contents } = req.body;
    const userId = req.params.userId;
    
    // Se é a ação de abrir conversa do TTL
    if (action === "open_conversation") {
        console.log(`[LIMPAR] 📱 User ${userId}: Pedido para abrir conversa: ${byPhone}`);
        
        // Enfileira script para abrir conversa
        return enqueue("abrir_conversa.sh", [
            userId,
            String(byPhone || ""),
            String(byTag || ""),
            String(byKey || "")
        ], res);
    }
    
    // Fallback: resposta imediata sem processar
    return res.json({
        success: true,
        message: "Notificação recebida",
        action: action || "unknown",
        userId: userId
    });
});

// TEXTO
app.post("/:userId/texto", (req, res) =>
    enqueue("enviar_texto.sh", [
        req.params.userId,
        String(req.body.msg),
        String(req.body.lead)
    ], res)
);

app.post("/:userId/texto2", (req, res) =>
    enqueue("enviar_texto2.sh", [
        req.params.userId,
        String(req.body.msg)
    ], res)
);

app.post("/:userId/texto3", (req, res) =>
    enqueue("enviar_texto3.sh", [
        req.params.userId,
        String(req.body.msg),
        String(req.body.lead)
    ], res)
);

// ÁUDIO
app.post("/:userId/audio", (req, res) =>
    enqueue("gravar_fake.sh", [
        req.params.userId,
        String(req.body.arquivo || ""),
        String(req.body.tempo || ""),
        String(req.body.lead || "")
    ], res)
);

// SALVAR CONTATO
app.post("/:userId/salvarcontato", (req, res) =>
    enqueue("salvar_contato.sh", [
        req.params.userId,
        String(req.body.lead || ""),
        String(req.body.salvarcomo || "")
    ], res)
);

// LIGAÇÃO
app.post("/:userId/ligar", (req, res) =>
    enqueue("fazer_ligacao.sh", [
        req.params.userId,
        String(req.body.lead || ""),
        String(req.body.call || "")
    ], res)
);

// MÍDIA
app.post("/:userId/midia", (req, res) =>
    enqueue("enviar_midia.sh", [
        req.params.userId,
        (String(req.body.viewOnce).toLowerCase() === "true") ? "true" : "false",
        String(req.body.media || ""),   // Arg 3: Nome do arquivo (Arg 2 no shell)
        String(req.body.caption || ""), // Arg 4: Legenda
        String(req.body.lead || "")     // Arg 5: Lead
    ], res)
);

// CALIBRAR
app.post("/:userId/calibrar", (req, res) =>
    enqueue("calibrar.sh", [req.params.userId], res)
);

// AUTOCLIQUE
app.post("/:userId/clique", (req, res) =>
    enqueue("autoclique.sh", [
        req.params.userId,
        String(req.body.x),
        String(req.body.y),
        String(req.body.delay || "")
    ], res)
);

// PIX
app.post("/:userId/pix", (req, res) =>
    enqueue("pix.sh", [
        req.params.userId,
        String(req.body.lead || "")
    ], res)
);

// CHAT
app.post("/:userId/chat", (req, res) =>
    enqueue("chat.sh", [
        req.params.userId,
        String(req.body.lead || "")
    ], res)
);

// 🆕 REJEITAR CALL (COM PRIORIDADE E SUPORTE A BODY)
app.post("/:userId/rejeitarcall", (req, res) =>
    enqueue("rejeitacall.sh", [
        req.params.userId,              // $1: User ID
        String(req.body.lead || "")     // $2: Número do Lead (Novo)
    ], res, true)                       // true = PRIORIDADE MÁXIMA (Fura Fila)
);

// ============================================================================
// 🧹 ROTA: LIMPAR FILA (CORRIGIDA - HARD RESET)
// ============================================================================
app.post("/clearqueue", (req, res) => {
    try {
        // 1. Zera a fila na memória
        memoryQueue = [];
        
        // 2. Salva o arquivo vazio no disco
        saveQueueToDisk(memoryQueue);

        // 3. [IMPORTANTE] Força o reset das variáveis de estado
        // Isso "destrava" o processador se ele estiver preso em uma tarefa fantasma
        isProcessing = false;
        emulatorBusy = false;
        currentTask = null;

        console.log("🧹 Fila limpa e estados resetados via /clearqueue");
        
        return res.json({ 
            success: true, 
            message: "Fila limpa e processador resetado com sucesso", 
            queueSize: 0 
        });
    } catch (err) {
        console.error("Erro ao limpar fila:", err);
        return res.status(500).json({ success: false, error: err.message });
    }
});

// ============================================================================
// START
// ============================================================================
app.listen(PORT, () => {
    console.log("==================================================");
    console.log("🚀 ZAP SERVER v5.4 (Multi-User + Priority) INICIADO");
    console.log("📍 Porta:", PORT);
    console.log("🔐 Execução ROOT/SUDO");
    console.log("👥 Modo Multi-Usuário Ativo (/:userId/rota)");
    console.log("==================================================");
});