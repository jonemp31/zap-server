#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# gravar_fake.sh — V17.0: THE HYBRID PROTOCOL
# Lógica Dupla: Simples para User 0 / Freeze+Expandido para Clones
# ==========================================================

# --- 1. VALIDAÇÕES ---
if ! command -v ffmpeg &> /dev/null; then echo "❌ FFmpeg ausente"; exit 1; fi

# --- 2. CONFIGURAÇÕES ---
COORD_MICROFONE="1001 1837"
COORD_CADEADO="986 1318"
COORD_PAUSE="536 1811"
COORD_ENVIAR="986 1822"
PKG_WHATSAPP="com.whatsapp.w4b"

# --- 3. ARGUMENTOS ---
USER_ID="${1:-0}"
NOME_ARQUIVO="${2:-3novo.opus}"
INPUT_TEMPO="$3"
LEAD="$4"

[ -z "$LEAD" ] && { echo "❌ Lead não informado"; exit 1; }

# --- 4. PREPARAÇÃO DO ARQUIVO ---
BASE_PATH="/storage/emulated/0/Download"
FULL_PATH_SOURCE="$BASE_PATH/$NOME_ARQUIVO"

if [ ! -f "$FULL_PATH_SOURCE" ]; then
    echo "❌ Arquivo fonte não encontrado: $FULL_PATH_SOURCE"
    exit 1
fi

# ==========================================================
# PASSO 0: PROCESSAMENTO (PADRONIZADO)
# ==========================================================
echo "🧬 Processando áudio..."
TMP_PROC="$HOME/proc_audio_$RANDOM.opus"
BITRATE=$(shuf -i 24000-26000 -n1)

# A conversão padronizada garante compatibilidade para ambos os casos
if ! ffmpeg -y -loglevel error -i "$FULL_PATH_SOURCE" \
    -af "aresample=48000" \
    -map_metadata -1 \
    -c:a libopus -b:a ${BITRATE} -ar 48000 \
    -vbr on -application voip "$TMP_PROC"; then
    echo "❌ Erro FFmpeg"
    exit 1
fi

# Pega a duração real do áudio processado
DURACAO_REAL=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP_PROC" 2>/dev/null)

# ==========================================================
# PASSO 1: CÁLCULO DE TEMPO (A REGRA DOS 5.7x)
# ==========================================================
if [ "$USER_ID" == "0" ]; then
    echo "👤 User 0 (Admin): Modo Nativo"
    # User 0: Tempo exato (arredondado simples)
    TEMPO_GRAVACAO=$(printf "%.0f" "$DURACAO_REAL")
    [ -z "$TEMPO_GRAVACAO" ] && TEMPO_GRAVACAO=5
else
    echo "👥 User Clone ($USER_ID): Modo Expandido (Anti-Corte)"
    # User Clones: Multiplicador 5.7x para criar container grande
    # Usando python para cálculo preciso de float
    TEMPO_GRAVACAO=$(python3 -c "print(int($DURACAO_REAL * 5.7) + 1)")
fi

echo "⏱️ Tempo de Áudio: ${DURACAO_REAL}s"
echo "🎙️ Tempo de Gravação Definido: ${TEMPO_GRAVACAO}s"

# ==========================================================
# PASSO 2: CAMINHOS E UI
# ==========================================================
if [ "$USER_ID" == "0" ]; then
    PASTA_ZAP="/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/.Shared"
else
    PASTA_ZAP="/data/media/$USER_ID/Android/media/com.whatsapp.w4b/WhatsApp Business/.Shared"
fi

echo "📂 Alvo: $PASTA_ZAP"
LEAD_CLEAN=$(echo "$LEAD" | tr -d ' +-' | sed 's/^55//')

echo "🚀 Abrindo WhatsApp..."
su -c "am start --user $USER_ID -a android.intent.action.VIEW \
    -d 'https://api.whatsapp.com/send?phone=$LEAD_CLEAN' \
    $PKG_WHATSAPP" >/dev/null 2>&1
sleep 3

# Gravação (Comum a ambos, mas com tempos diferentes definidos acima)
echo "🎙️ Gravando..."
input swipe $COORD_MICROFONE $COORD_CADEADO 2000
sleep 0.5
sleep "$TEMPO_GRAVACAO"

echo "⏸️ Pausando..."
input tap $COORD_PAUSE
sleep 1.5

# ==========================================================
# PASSO 3: INJEÇÃO HÍBRIDA (A BIFURCAÇÃO)
# ==========================================================
echo "🔍 Buscando arquivo..."

ARQUIVO_DESTINO=""
TENTATIVAS=0
while [ $TENTATIVAS -lt 3 ]; do
    if [ "$USER_ID" == "0" ]; then
        ARQUIVO_DESTINO=$(find "$PASTA_ZAP" -name "*.opus" -mmin -1 -type f 2>/dev/null | head -n 1)
    else
        ARQUIVO_DESTINO=$(su -c "find '$PASTA_ZAP' -name '*.opus' -mmin -1 -type f" 2>/dev/null | head -n 1)
    fi
    
    if [ -n "$ARQUIVO_DESTINO" ]; then break; fi
    TENTATIVAS=$((TENTATIVAS + 1))
    sleep 0.5
done

if [ -z "$ARQUIVO_DESTINO" ]; then
    echo "❌ Erro: Gravação não encontrada."; rm "$TMP_PROC"; exit 1
fi

echo "🎯 Alvo: $(basename "$ARQUIVO_DESTINO")"

# --- LÓGICA DO USER 0 (SIMPLES) ---
if [ "$USER_ID" == "0" ]; then
    echo "💉 Injetando (Modo Simples - User 0)..."
    cat "$TMP_PROC" > "$ARQUIVO_DESTINO"
    
    # User 0 não precisa de freeze, segue direto para envio
    echo "⚡ Pular Freeze Protocol (User 0)"

# --- LÓGICA DOS CLONES (FREEZE + PERMISSÕES) ---
else
    echo "💉 Injetando (Modo Root - User $USER_ID)..."
    
    # Captura permissões e injeta via su
    PERMS=$(su -c "stat -c '%u:%g' '$ARQUIVO_DESTINO'")
    cat "$TMP_PROC" | su -c "cat > '$ARQUIVO_DESTINO'"
    su -c "chown $PERMS '$ARQUIVO_DESTINO'"
    su -c "chmod 660 '$ARQUIVO_DESTINO'"
    
    # O PROTOCOLO DE CONGELAMENTO
    echo "❄️  Iniciando Freeze Protocol..."
    
    # 1. Sync e Drop Caches
    su -c "sync"
    su -c "echo 3 > /proc/sys/vm/drop_caches"
    
    # 2. Congelar Processo (5 SEGUNDOS)
    PID_ZAP=$(su -c "ps -ef | grep $PKG_WHATSAPP | grep u${USER_ID}_ | awk '{print \$2}' | head -n 1")
    
    if [ -n "$PID_ZAP" ]; then
        echo "🥶 Congelando PID $PID_ZAP por 5s..."
        su -c "kill -SIGSTOP $PID_ZAP"
        
        sleep 5
        
        echo "🔥 Descongelando..."
        su -c "kill -SIGCONT $PID_ZAP"
        sleep 1.5
    else
        echo "⚠️ PID não encontrado, pulando freeze."
    fi
fi

# Atualiza timestamp por garantia (para ambos)
su -c "touch '$ARQUIVO_DESTINO'"

# ==========================================================
# PASSO 4: ENVIAR
# ==========================================================
echo "📨 Enviando..."
input tap $COORD_ENVIAR

sleep 2
rm "$TMP_PROC"
input keyevent 4

echo "✅ Processo finalizado."
exit 0