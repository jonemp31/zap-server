#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# gravar_fake.sh — V18.0: USER 0 ONLY
# Gravação Fake exclusiva para User 0 (Admin)
# Clones usam: intent_audio.sh
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
# PASSO 0: PROCESSAMENTO
# ==========================================================
echo "👤 User 0 (Admin): Modo Gravação Fake"
echo "🧬 Processando áudio..."

TMP_PROC="$HOME/proc_audio_$RANDOM.opus"
BITRATE=$(shuf -i 24000-26000 -n1)

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

# Tempo exato (arredondado simples)
TEMPO_GRAVACAO=$(printf "%.0f" "$DURACAO_REAL")
[ -z "$TEMPO_GRAVACAO" ] && TEMPO_GRAVACAO=5

echo "⏱️ Tempo de Áudio: ${DURACAO_REAL}s"
echo "🎙️ Tempo de Gravação: ${TEMPO_GRAVACAO}s"

# ==========================================================
# PASSO 1: ABRIR WHATSAPP
# ==========================================================
PASTA_ZAP="/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/.Shared"
LEAD_CLEAN=$(echo "$LEAD" | tr -d ' +-' | sed 's/^55//')

echo "🚀 Abrindo WhatsApp..."
am start -a android.intent.action.VIEW \
    -d "https://api.whatsapp.com/send?phone=$LEAD_CLEAN" \
    $PKG_WHATSAPP >/dev/null 2>&1
sleep 3

# ==========================================================
# PASSO 2: GRAVAÇÃO
# ==========================================================
echo "🎙️ Gravando..."
input swipe $COORD_MICROFONE $COORD_CADEADO 2000
sleep 0.5
sleep "$TEMPO_GRAVACAO"

echo "⏸️ Pausando..."
input tap $COORD_PAUSE
sleep 1.5

# ==========================================================
# PASSO 3: BUSCA E INJEÇÃO
# ==========================================================
echo "🔍 Buscando arquivo..."

ARQUIVO_DESTINO=""
TENTATIVAS=0
while [ $TENTATIVAS -lt 3 ]; do
    ARQUIVO_DESTINO=$(find "$PASTA_ZAP" -name "*.opus" -mmin -1 -type f 2>/dev/null | head -n 1)
    if [ -n "$ARQUIVO_DESTINO" ]; then break; fi
    TENTATIVAS=$((TENTATIVAS + 1))
    sleep 0.5
done

if [ -z "$ARQUIVO_DESTINO" ]; then
    echo "❌ Erro: Gravação não encontrada."
    rm "$TMP_PROC"
    exit 1
fi

echo "🎯 Alvo: $(basename "$ARQUIVO_DESTINO")"
echo "💉 Injetando..."

cat "$TMP_PROC" > "$ARQUIVO_DESTINO"
touch "$ARQUIVO_DESTINO"

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
