/**
 * STATUS ZAPS - Gerente de Monitoramento v2.0
 * - Ciclo 1: Inventário de Usuários (1h)
 * - Ciclo 2: Verificação de Status do WhatsApp (20-30min | 07h-00h)
 * - Melhorias: Retry logic, validações, alertas
 */

const fs = require('fs');
const axios = require('axios');
const { exec } = require('child_process');
const path = require('path');

// --- CONFIGURAÇÕES ---
const CONFIG = {
    FILE_DB: path.join(__dirname, 'userativos.json'),
    CONFIG_FILE: path.join(__dirname, 'config.json'),
    API_LOCAL: 'http://localhost:3000',
    WEBHOOK_URL: 'https://webhook-dev.zapsafe.work/webhook/status-api-mob',
    CMD_LIST_USERS: 'su -c "pm list users"',
    PKG_W4B: 'com.whatsapp.w4b',
    CYCLE_INVENTORY: 60 * 60 * 1000, // 1 Hora
    CYCLE_STATUS_MIN: 20 * 60 * 1000, // 20 min
    CYCLE_STATUS_MAX: 30 * 60 * 1000, // 30 min
    DELAY_USER_MIN: 30 * 1000, // 30 seg
    DELAY_USER_MAX: 90 * 1000, // 90 seg
    WORK_HOUR_START: 7,
    WORK_HOUR_END: 2, // 02:00 da manhã
    MAX_RETRIES: 2,
    RETRY_DELAY: 5000, // 5 segundos
    WEBHOOK_TIMEOUT: 10000, // 10 segundos
    API_TIMEOUT: 60000 // 60 segundos para OCR
};

// Carrega device do config.json
let DEVICE_NAME = 'unknown';
try {
    if (fs.existsSync(CONFIG.CONFIG_FILE)) {
        const configData = JSON.parse(fs.readFileSync(CONFIG.CONFIG_FILE, 'utf8'));
        DEVICE_NAME = configData.device?.name || 'unknown';
        console.log(`📱 Device configurado: ${DEVICE_NAME}`);
    }
} catch (e) {
    console.log(`⚠️ Não foi possível carregar config.json: ${e.message}`);
}

// --- UTILITÁRIOS ---
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const log = (msg) => {
    const ts = new Date().toLocaleString('pt-BR');
    console.log(`[${ts}] ${msg}`);
};

// Gera um delay com distribuição levemente "Gaussiana" (média ponderada)
// Evita padrões robóticos fixos
const getHumanDelay = (min, max) => {
    const rand = (Math.random() + Math.random()) / 2; // Centraliza a aleatoriedade
    const val = Math.floor(rand * (max - min + 1) + min);
    return val;
};

// Executa comandos Shell via Promise
const execShell = (cmd) => {
    return new Promise((resolve) => {
        exec(cmd, (error, stdout, stderr) => {
            // No grep, erro code 1 significa "não encontrado", não é erro de crash
            if (error && error.code !== 1) {
                resolve({ success: false, output: stderr || error.message, code: error.code });
            } else {
                resolve({ success: true, output: stdout.trim(), code: error ? error.code : 0 });
            }
        });
    });
};

// Leitura/Escrita do "Banco de Dados" JSON
const loadDb = () => {
    try {
        if (fs.existsSync(CONFIG.FILE_DB)) {
            return JSON.parse(fs.readFileSync(CONFIG.FILE_DB, 'utf8'));
        }
    } catch (e) { log(`Erro ao ler DB: ${e.message}`); }
    return { success: true, total: 0, users: [] };
};

const saveDb = (data) => {
    try {
        fs.writeFileSync(CONFIG.FILE_DB, JSON.stringify(data, null, 2));
    } catch (e) { log(`Erro ao salvar DB: ${e.message}`); }
};

// Função para limpar e padronizar número brasileiro
const cleanPhoneNumber = (phoneStr) => {
    if (!phoneStr || phoneStr === "no" || phoneStr === "unknown") {
        return phoneStr;
    }
    
    // Remove todos os caracteres não numéricos
    let cleaned = phoneStr.replace(/\D/g, '');
    
    // Se começar com 55, mantém
    // Se não começar com 55, adiciona
    if (!cleaned.startsWith('55') && cleaned.length >= 10) {
        cleaned = '55' + cleaned;
    }
    
    // Valida se tem pelo menos 12 dígitos (55 + DDD + número)
    if (cleaned.length < 12) {
        log(`⚠️ Número inválido após limpeza: ${cleaned} (original: ${phoneStr})`);
        return "invalid";
    }
    
    return cleaned;
};

// Função retry genérica
const retryOperation = async (operation, operationName, maxRetries = CONFIG.MAX_RETRIES) => {
    let lastError = null;
    
    for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
        try {
            const result = await operation();
            if (attempt > 1) {
                log(`✅ ${operationName} bem-sucedido na tentativa ${attempt}`);
            }
            return { success: true, data: result };
        } catch (error) {
            lastError = error;
            if (attempt <= maxRetries) {
                log(`🔄 ${operationName} falhou. Tentativa ${attempt}/${maxRetries + 1}. Aguardando ${CONFIG.RETRY_DELAY/1000}s...`);
                await sleep(CONFIG.RETRY_DELAY);
            }
        }
    }
    
    log(`❌ ${operationName} falhou após ${maxRetries + 1} tentativas: ${lastError.message}`);
    return { success: false, error: lastError };
};

// ============================================================
// 🔄 CICLO 1: INVENTÁRIO DE USUÁRIOS (A CADA 1H)
// ============================================================
async function atualizarInventario() {
    log('📋 [INVENTÁRIO] Iniciando varredura de usuários...');
    
    // 1. Listar Usuários
    const res = await execShell(CONFIG.CMD_LIST_USERS);
    if (!res.success) {
        log(`❌ Erro ao listar usuários: ${res.output}`);
        return;
    }

    const lines = res.output.split('\n');
    const detectedUsers = [];

    // 2. Processar cada usuário encontrado
    for (const line of lines) {
        // Regex para capturar: UserInfo{0:Proprietário:c13}
        const match = line.match(/UserInfo\{(\d+):([^:]+):([^}]+)\}/);
        
        if (match) {
            const userId = parseInt(match[1]);
            const userName = match[2];
            const userFlags = match[3];

            // 3. Verificar se tem WhatsApp Business instalado
            // grep retorna exit code 0 se achar, 1 se não achar
            const cmdCheck = `su -c "pm list packages --user ${userId} | grep ${CONFIG.PKG_W4B}"`;
            const checkRes = await execShell(cmdCheck);
            const hasWpp = (checkRes.code === 0 && checkRes.output.includes(CONFIG.PKG_W4B));

            // Mantém dados antigos se já existirem (para não perder numeroWpp/status)
            const currentDb = loadDb();
            const existingUser = currentDb.users.find(u => u.id === userId);

            detectedUsers.push({
                id: userId,
                name: userName,
                flags: userFlags,
                running: true, // Se apareceu no pm list, está rodando
                "com.whatsapp.w4b": hasWpp,
                // Preserva estado anterior ou define padrão
                numeroWpp: existingUser?.numeroWpp || "unknown", 
                status: existingUser?.status || "unknown"
            });
        }
    }

    // 4. Salvar
    const finalData = {
        success: true,
        total: detectedUsers.length,
        users: detectedUsers,
        last_update: new Date().toISOString()
    };

    saveDb(finalData);
    log(`✅ [INVENTÁRIO] Concluído. ${detectedUsers.length} usuários encontrados.`);
}

// ============================================================
// 🕵️ CICLO 2: FISCAL DE STATUS (20-30 MIN)
// ============================================================
async function verificarStatusZap() {
    log('🕵️ [FISCAL] Iniciando ciclo de verificação...');

    // 1. Verificação de Horário (dinâmico baseado em CONFIG)
    const hora = new Date().getHours();
    // Trabalha até chegar na hora limite (ex: se END=2, às 02:00 ele já para)
    // Pausa se: Hora for MAIOR/IGUAL ao Fim (2) E MENOR que o Início (7)
    if (hora >= CONFIG.WORK_HOUR_END && hora < CONFIG.WORK_HOUR_START) {
        log(`💤 [FISCAL] Horário de descanso (${CONFIG.WORK_HOUR_END}:00-${CONFIG.WORK_HOUR_START - 1}:59). Aguardando próximo ciclo...`);
        return scheduleNextRun();
    }

    // 2. Carregar Usuários
    let db = loadDb();
    const usersToCheck = db.users.filter(u => u["com.whatsapp.w4b"] === true);

    if (usersToCheck.length === 0) {
        log('⚠️ [FISCAL] Nenhum usuário com WhatsApp Business encontrado.');
        return scheduleNextRun();
    }

    log(`🔍 [FISCAL] ${usersToCheck.length} usuários na fila para verificação.`);

    // Contadores para análise de anomalias
    let openCount = 0;
    let closedCount = 0;

    // 3. Loop Sequencial (1 por 1)
    for (const user of usersToCheck) {
        log(`👉 [FISCAL] Verificando User ID: ${user.id} (${user.name})...`);

        let statusResult = "close";
        let numeroResult = "no";

        // Tentar obter o número (retry apenas para falhas de comunicação)
        const apiOperation = async () => {
            try {
                log(`📡 Chamando API: POST ${CONFIG.API_LOCAL}/${user.id}/numeroWpp`);
                const response = await axios.post(
                    `${CONFIG.API_LOCAL}/${user.id}/numeroWpp`, 
                    {}, 
                    { timeout: CONFIG.API_TIMEOUT }
                );
                
                // IMPORTANTE: Se chegou resposta HTTP (200, 500, etc), NÃO faz retry
                // Pois o server.js já tem seu próprio retry interno
                
                if (response.data && response.data.success) {
                    // Sucesso: OCR leu o número
                    try {
                        const outputJson = JSON.parse(response.data.output);
                        if (outputJson.numerowhatsapp) {
                            // Limpa e padroniza o número
                            const cleanedNumber = cleanPhoneNumber(outputJson.numerowhatsapp);
                            
                            if (cleanedNumber !== "invalid" && cleanedNumber !== "no") {
                                statusResult = "open";
                                numeroResult = cleanedNumber;
                            }
                        }
                    } catch (parseErr) {
                        log(`⚠️ Erro parse output ID ${user.id}: ${parseErr.message}`);
                    }
                } else {
                    // Resposta de erro lógico (WhatsApp banido, etc) - NÃO faz retry
                    log(`⚠️ WhatsApp ID ${user.id} retornou erro: ${JSON.stringify(response.data)}`);
                    statusResult = "close";
                    numeroResult = "no";
                }
                
                // Retorna resultado sem erro (para não triggerar retry)
                return { statusResult, numeroResult };
                
            } catch (error) {
                // Apenas erros de COMUNICAÇÃO (timeout, ECONNREFUSED, etc) fazem retry
                if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT' || error.code === 'ENOTFOUND' || !error.response) {
                    throw error; // Propaga erro para fazer retry
                }
                
                // Se foi erro HTTP (500, 404, etc), NÃO faz retry
                if (error.response) {
                    const errorData = typeof error.response.data === 'object' 
                        ? JSON.stringify(error.response.data) 
                        : error.response.data;
                    log(`⛔ WhatsApp ID ${user.id} retornou HTTP ${error.response.status}: ${errorData || error.message}`);
                    statusResult = "close";
                    numeroResult = "no";
                    return { statusResult, numeroResult };
                }
                
                throw error; // Outros erros desconhecidos
            }
        };

        // Executa com retry APENAS para falhas de comunicação
        const apiResult = await retryOperation(
            apiOperation,
            `Comunicação API Local ID ${user.id}`,
            CONFIG.MAX_RETRIES
        );

        if (apiResult.success && apiResult.data) {
            statusResult = apiResult.data.statusResult;
            numeroResult = apiResult.data.numeroResult;
        } else {
            // Falha de comunicação após todas as tentativas
            log(`⛔ Falha de COMUNICAÇÃO com API Local para ID ${user.id}`);
            statusResult = "close";
            numeroResult = "no";
        }

        // Contabiliza para análise de anomalias
        if (statusResult === "open") {
            openCount++;
        } else {
            closedCount++;
        }

        // 4. Atualizar DB em memória e disco
        user.status = statusResult;
        user.numeroWpp = numeroResult;
        
        // Atualiza o registro no array principal e salva
        const index = db.users.findIndex(u => u.id === user.id);
        if (index !== -1) {
            db.users[index] = user;
            saveDb(db);
        }

        // 5. Enviar Webhook com retry
        const payloadWebhook = {
            device: DEVICE_NAME,
            id: user.id,
            name: user.name,
            flags: user.flags,
            running: user.running,
            "com.whatsapp.w4b": user["com.whatsapp.w4b"],
            numeroWpp: numeroResult,
            status: statusResult,
            timestamp: new Date().toISOString()
        };

        const webhookOperation = async () => {
            await axios.post(
                CONFIG.WEBHOOK_URL, 
                payloadWebhook, 
                { timeout: CONFIG.WEBHOOK_TIMEOUT }
            );
            return true;
        };

        const webhookResult = await retryOperation(
            webhookOperation,
            `Webhook ID ${user.id}`,
            CONFIG.MAX_RETRIES
        );

        if (webhookResult.success) {
            log(`📤 [WEBHOOK] Enviado para ID ${user.id} (Status: ${statusResult})`);
        } else {
            log(`⚠️ [WEBHOOK] Falha definitiva ao enviar ID ${user.id}, continuando...`);
        }

        // 6. Delay Gaussiano entre usuários (30s a 90s)
        const delay = getHumanDelay(CONFIG.DELAY_USER_MIN, CONFIG.DELAY_USER_MAX);
        log(`⏳ Aguardando ${delay/1000}s para o próximo usuário...`);
        await sleep(delay);
    }

    // 7. Verificar anomalias (mais de 50% fechados)
    const totalChecked = openCount + closedCount;
    if (totalChecked > 0) {
        const closedPercentage = (closedCount / totalChecked) * 100;
        log(`📊 [STATS] Open: ${openCount}, Closed: ${closedCount} (${closedPercentage.toFixed(1)}% fechados)`);
        
        if (closedPercentage > 50) {
            log(`🚨 [ALERTA] Mais de 50% dos WhatsApp estão FECHADOS!`);
            
            // Enviar alerta especial
            const alertPayload = {
                device: DEVICE_NAME,
                type: "ALERT",
                message: "Anomalia detectada: Mais de 50% dos WhatsApp estão offline/banidos",
                stats: {
                    total: totalChecked,
                    open: openCount,
                    closed: closedCount,
                    closedPercentage: closedPercentage.toFixed(1)
                },
                timestamp: new Date().toISOString()
            };

            const alertOperation = async () => {
                await axios.post(
                    CONFIG.WEBHOOK_URL,
                    alertPayload,
                    { timeout: CONFIG.WEBHOOK_TIMEOUT }
                );
                return true;
            };

            const alertResult = await retryOperation(
                alertOperation,
                "Alerta de Anomalia",
                CONFIG.MAX_RETRIES
            );

            if (alertResult.success) {
                log(`🚨 [ALERTA] Webhook de alerta enviado com sucesso`);
            }
        }
    }

    log('🏁 [FISCAL] Ciclo finalizado.');
    scheduleNextRun();
}

// Agendador do próximo ciclo do Fiscal
function scheduleNextRun() {
    const nextCycleDelay = getHumanDelay(CONFIG.CYCLE_STATUS_MIN, CONFIG.CYCLE_STATUS_MAX);
    const nextTime = new Date(Date.now() + nextCycleDelay).toLocaleTimeString('pt-BR');
    
    log(`📅 [AGENDA] Próxima verificação às ${nextTime} (daqui a ${Math.round(nextCycleDelay/60000)} min).`);
    
    setTimeout(verificarStatusZap, nextCycleDelay);
}

// ============================================================
// 🚀 INICIALIZAÇÃO
// ============================================================
log('🚀 STATUS ZAPS v2.0 INICIADO');
log(`📱 Device: ${DEVICE_NAME}`);

// Inicia Inventário (Imediato e depois a cada 1h)
atualizarInventario();
setInterval(atualizarInventario, CONFIG.CYCLE_INVENTORY);

// Inicia Fiscal (Imediato - depois entra no loop de agendamento)
verificarStatusZap();