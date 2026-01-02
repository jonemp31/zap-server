/**
 * SENTINELA PRO V8.2 - CONFIG DINÂMICO (Node.js Edition)
 * - Engine: Dumpsys + SED
 * - Fix: Parsing robusto para remover "String(...)" e encontrar mensagens ocultas
 * - Logic: V7 Stable TTL Core
 * - NEW: Lê DEVICE_NAME do config.json (mesmo nome do tunnel)
 */

const { exec } = require('child_process');
const axios = require('axios');
const util = require('util');
const fs = require('fs');
const path = require('path');

const execPromise = util.promisify(exec);

// --- CARREGAR CONFIG.JSON ---
let externalConfig = {};
const configPath = path.join(__dirname, 'config.json');

try {
    if (fs.existsSync(configPath)) {
        externalConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        console.log(`[CONFIG] ✅ Carregado config.json - Device: ${externalConfig.device?.name || 'N/A'}`);
    } else {
        console.log('[CONFIG] ⚠️ config.json não encontrado, usando valores padrão');
    }
} catch (err) {
    console.error('[CONFIG] ❌ Erro ao ler config.json:', err.message);
}

// --- CONFIGURAÇÃO (com fallbacks) ---
const CONFIG = {
    WEBHOOK_DATA: externalConfig.webhooks?.data || "https://webhook-dev.zapsafe.work/webhook/whatsapp4mumu",
    WEBHOOK_CLEAN: externalConfig.webhooks?.clean || "https://webhook-dev.zapsafe.work/webhook/limparnotificacaozapmu",
    APP_ALVO_PKG: externalConfig.device?.whatsapp_pkg || "com.whatsapp.w4b", 
    DEVICE_NAME: externalConfig.device?.name || "device1",
    DELAY_POLL: 2000,
    TIMEOUT_CLEAN: 30000,
    MAX_RETRIES: 3,
    MAX_QUEUE_SIZE: 500,
    TTL_CACHE: 120000 
};

// --- ESTADO GLOBAL ---
let globalExecID = 1;
const activeProcessMap = new Map();
const cleanupQueue = [];
let isCleaning = false;

// --- UTILITÁRIOS ---
const getTimestamp = () => {
    return new Date().toLocaleString('pt-BR', {
        timeZone: 'America/Sao_Paulo',
        hour12: false
    }).replace(',', '');
};

const log = (msg, type = 'INFO') => {
    const icons = { INFO: 'ℹ️', SUCCESS: '✅', WARN: '⚠️', ERROR: '❌', CLEAN: '🧹', DATA: '📤', WAIT: '⏳', PARSE: '⚙️' };
    console.log(`[${getTimestamp()}] ${icons[type] || ''} ${msg}`);
};

const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const generateCacheKey = (n) => `${n.key}|${n.title}|${n.content}`;

// --- GARBAGE COLLECTOR ---
setInterval(() => {
    const now = Date.now();
    let cleaned = 0;
    for (const [key, timestamp] of activeProcessMap.entries()) {
        if (now - timestamp > CONFIG.TTL_CACHE) {
            activeProcessMap.delete(key);
            cleaned++;
        }
    }
    if (cleaned > 0) log(`[GC] ${cleaned} itens removidos (TTL).`, 'INFO');
}, 30000);

// ============================================================
// 🧹 FUNÇÃO FAXINEIRA (NOVA)
// Remove "String (abc)", aspas extras e espaços inúteis
// ============================================================
function cleanAndroidString(raw) {
    if (!raw || raw === 'null') return null;
    
    // Remove prefixos comuns do Java/Android
    let clean = raw.replace(/^String\s*\(/, '') // Remove "String (" ou "String("
                   .replace(/\)$/, '');          // Remove ")" do final
                   
    // Remove aspas do inicio e fim se sobrarem
    clean = clean.replace(/^"|"$/g, '');
    
    return clean.trim();
}

// ============================================================
// ⚙️ ENGINE V8.1: PARSING MELHORADO
// ============================================================

async function getNotifications() {
    try {
        // Comando mantido (Dumpsys + Sed)
        const cmd = `su -c "dumpsys notification --noredact | sed -n '/pkg=${CONFIG.APP_ALVO_PKG}/,+50p'"`;
        const { stdout } = await execPromise(cmd);
        
        if (!stdout || stdout.trim() === '') return [];

        const parsedNotifications = [];
        const records = stdout.split(/NotificationRecord/);

        for (const record of records) {
            const cleanRecord = record.trim();
            if (!cleanRecord || !cleanRecord.includes(CONFIG.APP_ALVO_PKG)) continue;

            try {
                // 1. KEY e ID
                const keyMatch = cleanRecord.match(/key=([^\s]+)/);
                const key = keyMatch ? keyMatch[1] : null;

                let id = null;
                if (key) {
                    const parts = key.split('|');
                    if (parts.length >= 3) id = parts[2];
                }
                if (!id) {
                    const idMatch = cleanRecord.match(/id=(\d+)/);
                    id = idMatch ? idMatch[1] : null;
                }

                // 2. EXTRAÇÃO DE CAMPOS BRUTOS (Aggressive Regex)
                // Pega tudo depois do "=" até o fim da linha
                
                const rawTitle = (cleanRecord.match(/android\.title=(.*)/) || [])[1];
                const rawText = (cleanRecord.match(/android\.text=(.*)/) || [])[1];
                const rawBigText = (cleanRecord.match(/android\.bigText=(.*)/) || [])[1];
                const rawTicker = (cleanRecord.match(/tickerText=(.*)/) || [])[1];

                // 3. LIMPEZA E PRIORIDADE
                // O WhatsApp às vezes põe a mensagem no bigText, às vezes no text, às vezes no ticker
                
                const title = cleanAndroidString(rawTitle) || "Sem Título";
                
                let content = cleanAndroidString(rawBigText); // Tenta BigText primeiro (geralmente msg completa)
                if (!content) content = cleanAndroidString(rawText); // Tenta Text normal
                if (!content) content = cleanAndroidString(rawTicker); // Tenta Ticker (notificação topo de tela)
                
                if (!content) content = "Conteúdo Oculto/Mídia"; // Desistência

                // Outros campos
                const groupMatch = cleanRecord.match(/groupKey=([^\s]+)/);
                const tagMatch = cleanRecord.match(/tag=([^\s]+)/);

                if (id) {
                    parsedNotifications.push({
                        id: id,
                        title: title,
                        content: content,
                        packageName: CONFIG.APP_ALVO_PKG,
                        key: key,
                        tag: tagMatch ? tagMatch[1] : null,
                        group: groupMatch ? groupMatch[1] : null
                    });
                }

            } catch (parseErr) {
                continue; 
            }
        }

        return parsedNotifications;

    } catch (e) {
        log(`Erro Shell: ${e.message}`, 'ERROR');
        return [];
    }
}

// ============================================================
// LÓGICA DE WORKERS MANTIDA
// ============================================================

async function sendDataWebhook(payload) {
    let tentativa = 1;
    while (tentativa <= CONFIG.MAX_RETRIES) {
        try {
            log(`[DATA] Enviando ID ${payload.notification_id}...`, 'DATA');
            await axios.post(CONFIG.WEBHOOK_DATA, payload, {
                timeout: 10000,
                validateStatus: s => s >= 200 && s < 300
            });
            log(`[DATA] Sucesso ID ${payload.notification_id}`, 'SUCCESS');
            return true;
        } catch (error) {
            log(`[DATA] Falha ID ${payload.notification_id}: ${error.message}`, 'WARN');
            if (tentativa < CONFIG.MAX_RETRIES) await sleep(2000 * tentativa);
        }
        tentativa++;
    }
    return false;
}

async function processCleanupQueue() {
    if (isCleaning) return;
    isCleaning = true;

    while (cleanupQueue.length > 0) {
        const item = cleanupQueue.shift();
        const { payload } = item;
        
        log(`[CLEAN] Solicitando limpeza ID ${payload.notification_id}.`, 'CLEAN');

        let tentativa = 1;
        let limpoComSucesso = false;

        while (tentativa <= CONFIG.MAX_RETRIES && !limpoComSucesso) {
            try {
                const response = await axios.post(CONFIG.WEBHOOK_CLEAN, payload, {
                    timeout: CONFIG.TIMEOUT_CLEAN,
                    validateStatus: s => s >= 200 && s < 300
                });

                const data = response.data;
                const check = data?.notificacoeslimpas;
                
                if (String(check).toLowerCase() === 'true') {
                    limpoComSucesso = true;
                    log(`[CLEAN] Confirmado N8N ID ${payload.notification_id}`, 'SUCCESS');
                } else {
                    throw new Error(`Resposta inválida`);
                }

            } catch (error) {
                const isTimeout = error.code === 'ECONNABORTED';
                log(`[CLEAN] Erro ID ${payload.notification_id}: ${isTimeout ? 'TIMEOUT' : error.message}`, 'WARN');
                if (tentativa < CONFIG.MAX_RETRIES) await sleep(2000);
            }
            tentativa++;
        }
        if (!limpoComSucesso) log(`[CLEAN] Falha ID ${payload.notification_id}`, 'ERROR');
        await sleep(200);
    }
    isCleaning = false;
}

function addToCleanupQueue(data) {
    cleanupQueue.push(data);
    processCleanupQueue();
}

async function maestroLoop() {
    log(`Sentinela V8.1 (Parser Fix) Iniciado.`, 'INFO');

    while (true) {
        try {
            if (cleanupQueue.length > CONFIG.MAX_QUEUE_SIZE) {
                log(`[MAESTRO] Fila cheia. Pausando.`, 'WARN');
                await sleep(CONFIG.DELAY_POLL);
                continue;
            }

            const notifications = await getNotifications();

            if (notifications.length > 0) {
                for (const notif of notifications) {
                    const cacheKey = generateCacheKey(notif);

                    if (activeProcessMap.has(cacheKey)) continue;

                    activeProcessMap.set(cacheKey, Date.now());

                    const payload = {
                        titulo: notif.title,
                        mensagem: notif.content,
                        app: notif.packageName,
                        notification_id: notif.id,
                        notification_tag: notif.tag,
                        android_key: notif.key,
                        group_id: notif.group,
                        device: CONFIG.DEVICE_NAME,
                        timestamp: getTimestamp(),
                        execID: globalExecID
                    };

                    globalExecID++;

                    handleNotificationFlow(payload, cacheKey).catch(err => {
                        log(`Erro fluxo: ${err}`, 'ERROR');
                        activeProcessMap.delete(cacheKey);
                    });
                }
            }
        } catch (err) {
            log(`Erro Crítico no Maestro: ${err.message}`, 'ERROR');
        }
        await sleep(CONFIG.DELAY_POLL);
    }
}

async function handleNotificationFlow(payload, cacheKey) {
    const dataSent = await sendDataWebhook(payload);
    if (dataSent) {
        addToCleanupQueue({ payload, cacheKey });
    } else {
        activeProcessMap.delete(cacheKey);
    }
}

maestroLoop();