#!/data/data/com.termux/files/usr/bin/bash

# =====================================================================
# enviar_midia.sh — V3.5: MULTI-USER + POPUP CHECK (ATUALIZADO)
# =====================================================================

# --- 1. VALIDAÇÕES INICIAIS ---
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ FFmpeg não encontrado! Instale: pkg install ffmpeg"
    exit 1
fi

# --- 2. CONFIGURAÇÕES ---
COORD_CAMPO_LEGENDA="403 1631"
COORD_BTN_VIEW_ONCE="986 1631"
COORD_BTN_ENVIAR="988 1820"
COORD_BTN_VOLTAR="70 80"
COORD_VIDEO_FOCUS="821 1048.5"
COORD_BTN_POPUP_OK="533 1627" # Coordenada atualizada
PKG_WHATSAPP="com.whatsapp.w4b"

# O script trabalha sempre no 0 (onde o Termux tem controle total)
BASE_PATH="/storage/emulated/0/Download"
TMP_MEDIA_DIR="$BASE_PATH/.tmp_media_processed"

# Cria pasta temporária e dá permissão total (para o outro user conseguir ler)
mkdir -p "$TMP_MEDIA_DIR" 2>/dev/null
chmod 777 "$TMP_MEDIA_DIR" 2>/dev/null

# --- 3. ARGUMENTOS (MULTI-USER) ---
USER_ID="$1"
VIEW_ONCE="$2"
MEDIA_FILE="$3"
CAPTION="$4"
LEAD="$5"

# Validações
[ -z "$USER_ID" ] && { echo "❌ User ID não informado"; exit 1; }
[ -z "$LEAD" ] && { echo "❌ Lead não informado"; exit 1; }
[ -z "$MEDIA_FILE" ] && { echo "❌ Arquivo não informado"; exit 1; }

FULL_PATH_SOURCE="$BASE_PATH/$MEDIA_FILE"

if [ ! -f "$FULL_PATH_SOURCE" ]; then
    echo "❌ Arquivo não encontrado: $FULL_PATH_SOURCE"
    exit 1
fi

# ==========================================================
# DETECÇÃO DO TIPO DE ARQUIVO
# ==========================================================
IS_VIDEO=false
IS_IMAGE=false
MIME_TYPE="image/*"
EXTENSAO="${MEDIA_FILE##*.}"
EXTENSAO_LOWER=$(echo "$EXTENSAO" | tr '[:upper:]' '[:lower:]')

if [[ "$EXTENSAO_LOWER" == "mp4" ]]; then
    IS_VIDEO=true
    MIME_TYPE="video/*"
    echo "🎥 Vídeo detectado (.mp4)"
elif [[ "$EXTENSAO_LOWER" =~ ^(jpg|jpeg|png)$ ]]; then
    IS_IMAGE=true
    MIME_TYPE="image/*"
    echo "📸 Imagem detectada (.$EXTENSAO_LOWER)"
else
    echo "❌ Formato não suportado: $EXTENSAO"
    exit 1
fi

# ==========================================================
# PASSO 0: APLICAR FINGERPRINT RANDÔMICA
# ==========================================================
echo "🧬 Gerando fingerprint randômica..."

TMP_OUTPUT="$TMP_MEDIA_DIR/processed_$RANDOM.$EXTENSAO_LOWER"

if [ "$IS_IMAGE" = "true" ]; then
    # FINGERPRINT IMAGEM
    QUALIDADE=$(shuf -i 85-95 -n1)
    BRILHO=$(python3 -c "import random; print(round(random.uniform(-0.02, 0.02), 3))")
    CONTRASTE=$(python3 -c "import random; print(round(random.uniform(0.98, 1.02), 3))")
    SATURACAO=$(python3 -c "import random; print(round(random.uniform(0.98, 1.02), 3))")
    
    CROP_TOP=$(shuf -i 0-3 -n1)
    CROP_BOTTOM=$(shuf -i 0-3 -n1)
    CROP_LEFT=$(shuf -i 0-3 -n1)
    CROP_RIGHT=$(shuf -i 0-3 -n1)
    
    echo "🎨 Aplicando: Q=$QUALIDADE, B=$BRILHO, C=$CONTRASTE, S=$SATURACAO"
    
    VFILTER="eq=brightness=$BRILHO:contrast=$CONTRASTE:saturation=$SATURACAO"
    VFILTER="$VFILTER,crop=iw-$CROP_LEFT-$CROP_RIGHT:ih-$CROP_TOP-$CROP_BOTTOM:$CROP_LEFT:$CROP_TOP"
    
    if ! ffmpeg -y -loglevel error \
        -i "$FULL_PATH_SOURCE" \
        -vf "$VFILTER" \
        -q:v $QUALIDADE \
        -map_metadata -1 \
        "$TMP_OUTPUT"; then
        echo "❌ Erro ao processar imagem"
        exit 1
    fi
    
elif [ "$IS_VIDEO" = "true" ]; then
    # FINGERPRINT VÍDEO
    VIDEO_BITRATE=$(shuf -i 800-1200 -n1)
    AUDIO_BITRATE=$(shuf -i 64-96 -n1)
    FPS=$(python3 -c "import random; print(round(random.uniform(29.5, 30.5), 2))")
    
    BRILHO=$(python3 -c "import random; print(round(random.uniform(-0.01, 0.01), 3))")
    CONTRASTE=$(python3 -c "import random; print(round(random.uniform(0.99, 1.01), 3))")
    
    CROP_PIXELS=$(shuf -i 0-2 -n1)
    
    echo "🎬 Aplicando: VBR=${VIDEO_BITRATE}k, ABR=${AUDIO_BITRATE}k, FPS=$FPS"
    
    VFILTER="eq=brightness=$BRILHO:contrast=$CONTRASTE"
    
    if [ $CROP_PIXELS -gt 0 ]; then
        VFILTER="$VFILTER,crop=iw-$((CROP_PIXELS*2)):ih-$((CROP_PIXELS*2)):$CROP_PIXELS:$CROP_PIXELS"
    fi
    
    VFILTER="$VFILTER,fps=$FPS"
    
    if ! ffmpeg -y -loglevel error \
        -i "$FULL_PATH_SOURCE" \
        -vf "$VFILTER" \
        -c:v libx264 \
        -b:v ${VIDEO_BITRATE}k \
        -c:a aac \
        -b:a ${AUDIO_BITRATE}k \
        -map_metadata -1 \
        -movflags +faststart \
        "$TMP_OUTPUT"; then
        echo "❌ Erro ao processar vídeo"
        exit 1
    fi
fi

# Verifica se o arquivo foi criado
if [ ! -f "$TMP_OUTPUT" ]; then
    echo "❌ Arquivo temporário não foi criado"
    exit 1
fi

# Garante que qualquer usuário possa ler o arquivo (permissão 777)
chmod 777 "$TMP_OUTPUT"

# ==========================================================
# 🔄 PATH SWAPPING LOGIC (A MÁGICA)
# ==========================================================
# O arquivo físico está em: /storage/emulated/0/Download/...
# Mas para o User X, precisamos dizer que está em: /storage/emulated/X/Download/...

FULL_PATH_SOURCE="$TMP_OUTPUT"

if [ "$USER_ID" == "0" ]; then
    INTENT_PATH="$FULL_PATH_SOURCE"
else
    # Substitui "/storage/emulated/0/" por "/storage/emulated/USER_ID/"
    INTENT_PATH=$(echo "$FULL_PATH_SOURCE" | sed "s|/storage/emulated/0/|/storage/emulated/$USER_ID/|")
    echo "🔄 Path Swap: $FULL_PATH_SOURCE -> $INTENT_PATH"
fi

echo "✅ Fingerprint aplicada: $(basename "$TMP_OUTPUT")"

# ==========================================================
# TRATAMENTO DO NÚMERO (JID)
# ==========================================================
LEAD_NUM=$(echo "$LEAD" | tr -d ' +-' | sed 's/^55//')
JID_NUM=$(echo "$LEAD" | tr -d ' +-')
JID="${JID_NUM}@s.whatsapp.net"

# ==========================================================
# FUNÇÃO: GERADOR DE DIGITAÇÃO HUMANIZADA
# ==========================================================
gerar_comandos_humanos() {
    local TEXTO_INPUT="$1"
    python3 - "$TEXTO_INPUT" << 'EOF'
import sys, random, unicodedata, datetime

texto = sys.argv[1] if len(sys.argv) > 1 else ""

def remove_acentos(s):
    nfkd = unicodedata.normalize("NFD", s)
    return "".join(c for c in nfkd if not unicodedata.combining(c))

texto = remove_acentos(texto).strip()

if not texto:
    print("sleep 0.1")
    sys.exit(0)

hora = datetime.datetime.now().hour
if 6 <= hora <= 9:   min_d, max_d = 0.08, 0.25
elif 10 <= hora <= 14: min_d, max_d = 0.06, 0.18
elif 18 <= hora <= 22: min_d, max_d = 0.06, 0.18
else:                  min_d, max_d = 0.15, 0.40

comandos = []

for char in texto:
    delay = round(random.uniform(min_d, max_d), 3)

    if char == ' ':
        comandos.append('input keyevent 62')
        comandos.append(f'sleep {round(random.uniform(0.25, 0.6), 3)}')
        continue

    if random.random() < 0.05:
        comandos.append('input text x')
        comandos.append('sleep 0.12')
        comandos.append('input keyevent 67')
        comandos.append('sleep 0.15')

    if char == '\\':
        comandos.append('input text "\\\\"')
    elif char == '"':
        comandos.append('input text "\\""')
    elif char == '`':
        comandos.append('input text "\\`"')
    elif char == '$':
        comandos.append('input text "\\$"')
    else:
        comandos.append(f'input text "{char}"')
    
    comandos.append(f'sleep {delay}')

print(';'.join(comandos))
EOF
}

# ==========================================================
# PASSO 1: ABRIR TELA DE ENVIO (INTENT ROOT MULTI-USER)
# ==========================================================
echo "🚀 Abrindo Intent ($MIME_TYPE) no User $USER_ID..."
echo "📂 Usando arquivo: file://$INTENT_PATH"

# Usamos o $INTENT_PATH que tem o ID do usuário correto no caminho
su -c "am start --user $USER_ID \
  -a android.intent.action.SEND \
  -t $MIME_TYPE \
  --eu android.intent.extra.STREAM file://$INTENT_PATH \
  --es jid '$JID' \
  $PKG_WHATSAPP" >/dev/null 2>&1

# Ajuste para vídeo
if [ "$IS_VIDEO" = "true" ]; then
    sleep 0.5
    input tap $COORD_VIDEO_FOCUS
fi

sleep 2.5

# ==========================================================
# PASSO 2: LEGENDA
# ==========================================================
if [ ! -z "$CAPTION" ]; then
    echo "📝 Focando legenda..."
    input tap $COORD_CAMPO_LEGENDA
    sleep 1

    echo "⌨️ Digitando legenda..."
    CMD_DIGITACAO=$(gerar_comandos_humanos "$CAPTION")
    eval "$CMD_DIGITACAO"
else
    echo "⚠️ Sem legenda"
fi

sleep 1

# ==========================================================
# PASSO 3: VIEW ONCE & VERIFICAÇÃO DE POPUP (ATUALIZADO)
# ==========================================================
if [ "$VIEW_ONCE" = "true" ]; then
    echo "👁️ Ativando View Once..."
    input tap $COORD_BTN_VIEW_ONCE
    sleep 0.5
    
    # --- INÍCIO DA NOVA LÓGICA DE POPUP ---
    echo "🔎 Verificando possível Popup..."
    
    # Define caminhos temporários para o OCR (usando ID para evitar conflito)
    IMG_SCREEN="/data/local/tmp/vo_check_$USER_ID.png"
    IMG_LOCAL="$TMP_MEDIA_DIR/vo_check_$USER_ID.png"
    TXT_RESULT="$TMP_MEDIA_DIR/vo_result_$USER_ID"
    
    # 1. Printa a tela
    su -c "screencap -p $IMG_SCREEN"
    cp "$IMG_SCREEN" "$IMG_LOCAL" 2>/dev/null || su -c "cat $IMG_SCREEN" > "$IMG_LOCAL"
    
    # 2. Executa Tesseract (OCR)
    if command -v tesseract &> /dev/null; then
        tesseract "$IMG_LOCAL" "$TXT_RESULT" -l por >/dev/null 2>&1
        CONTEUDO_TELA=$(cat "${TXT_RESULT}.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        
        # 3. Verifica as frases
        DETECTOU_POPUP=false
        
        if [[ "$CONTEUDO_TELA" == *"as mensagens de visualização única"* ]] || \
           [[ "$CONTEUDO_TELA" == *"as fotos, vídeos ou mensagens"* ]] || \
           [[ "$CONTEUDO_TELA" == *"para maior privacidade, o destinatário não pode compartilhar"* ]]; then
            DETECTOU_POPUP=true
        fi
        
        # Se detectou, executa a ação de fechar
        if [ "$DETECTOU_POPUP" = "true" ]; then
            echo "⚠️ Popup detectado! Clicando em OK..."
            sleep 1 # Tempo aumentado conforme pedido
            input tap $COORD_BTN_POPUP_OK
            sleep 0.6
        else
            echo "✅ Nenhum popup detectado."
        fi
    else
        echo "⚠️ Tesseract não instalado. Pulando verificação OCR."
    fi
    
    # Limpeza dos arquivos de verificação
    rm -f "$IMG_LOCAL" "${TXT_RESULT}.txt" 2>/dev/null
    su -c "rm -f $IMG_SCREEN" 2>/dev/null
    # --- FIM DA NOVA LÓGICA DE POPUP ---
fi

# ==========================================================
# PASSO 4: ENVIAR
# ==========================================================
echo "📨 Enviando..."
input tap $COORD_BTN_ENVIAR

# Delay humanizado
DELAY_VOLTAR=$(python3 -c "import random; print(round(random.uniform(0.8, 1.8), 2))")
sleep $DELAY_VOLTAR

echo "🔙 Voltando..."
input tap $COORD_BTN_VOLTAR

# ==========================================================
# LIMPEZA: Remove arquivos com mais de 24h
# ==========================================================
echo "🧹 Limpando arquivos antigos..."
find "$TMP_MEDIA_DIR" -name "processed_*" -mtime +1 -delete 2>/dev/null

echo "✅ Mídia enviada com sucesso!"
exit 0