#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# gravar_fake.sh — V18.0: INTENT PROTOCOL
# User 0: Gravação Fake (original)
# Clones: Envio direto via Intent (novo método)
# ==========================================================

# --- 1. VALIDAÇÕES ---
if ! command -v ffmpeg &> /dev/null; then echo "❌ FFmpeg ausente"; exit 1; fi

# --- 2. CONFIGURAÇÕES ---
# Coordenadas para User 0 (modo gravação)
COORD_MICROFONE="1001 1837"
COORD_CADEADO="986 1318"
COORD_PAUSE="536 1811"
COORD_ENVIAR="986 1822"

# Coordenadas para Clones (modo Intent)
COORD_CONFIRMAR_ENVIO="811 1035"
COORD_VOLTAR="63 90"

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

# Limpa o lead (remove espaços e prefixo 55)
LEAD_CLEAN=$(echo "$LEAD" | tr -d ' +-' | sed 's/^55//')
# JID para o Intent
LEAD_JID="55${LEAD_CLEAN}@s.whatsapp.net"

# ==========================================================
# BIFURCAÇÃO: USER 0 vs CLONES
# ==========================================================

if [ "$USER_ID" == "0" ]; then
    # ==================================================
    # FLUXO USER 0: GRAVAÇÃO FAKE (ORIGINAL)
    # ==================================================
    echo "👤 User 0 (Admin): Modo Gravação Fake"
    
    # --- Processamento ---
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

    # Duração real
    DURACAO_REAL=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TMP_PROC" 2>/dev/null)
    TEMPO_GRAVACAO=$(printf "%.0f" "$DURACAO_REAL")
    [ -z "$TEMPO_GRAVACAO" ] && TEMPO_GRAVACAO=5

    echo "⏱️ Tempo de Áudio: ${DURACAO_REAL}s"
    echo "🎙️ Tempo de Gravação: ${TEMPO_GRAVACAO}s"

    PASTA_ZAP="/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/.Shared"

    # Abre WhatsApp
    echo "🚀 Abrindo WhatsApp..."
    su -c "am start --user 0 -a android.intent.action.VIEW \
        -d 'https://api.whatsapp.com/send?phone=$LEAD_CLEAN' \
        $PKG_WHATSAPP" >/dev/null 2>&1
    sleep 3

    # Gravação
    echo "🎙️ Gravando..."
    input swipe $COORD_MICROFONE $COORD_CADEADO 2000
    sleep 0.5
    sleep "$TEMPO_GRAVACAO"

    echo "⏸️ Pausando..."
    input tap $COORD_PAUSE
    sleep 1.5

    # Busca arquivo
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

    # Injeção simples
    echo "💉 Injetando..."
    cat "$TMP_PROC" > "$ARQUIVO_DESTINO"
    touch "$ARQUIVO_DESTINO"

    # Enviar
    echo "📨 Enviando..."
    input tap $COORD_ENVIAR
    sleep 2

    rm "$TMP_PROC"
    input keyevent 4

    echo "✅ User 0: Processo finalizado."
    exit 0

else
    # ==================================================
    # FLUXO CLONES: ENVIO VIA INTENT (NOVO)
    # ==================================================
    echo "👥 User Clone ($USER_ID): Modo Intent Protocol"

    # --- Pastas ---
    PASTA_DOWNLOADS_CLONE="/storage/emulated/$USER_ID/Download"
    TMP_DIR="$HOME/tmp_audio_$$"
    
    mkdir -p "$TMP_DIR"

    # --- Copia arquivo original para temp ---
    echo "📋 Copiando arquivo original..."
    NOME_BASE=$(basename "$NOME_ARQUIVO")
    TMP_ORIGINAL="$TMP_DIR/$NOME_BASE"
    cp "$FULL_PATH_SOURCE" "$TMP_ORIGINAL"

    # --- Verifica extensão e converte se necessário ---
    EXTENSAO="${NOME_BASE##*.}"
    NOME_SEM_EXT="${NOME_BASE%.*}"

    if [ "$EXTENSAO" != "opus" ]; then
        echo "🔄 Convertendo $EXTENSAO para opus..."
        TMP_CONVERTIDO="$TMP_DIR/${NOME_SEM_EXT}.opus"
        if ! ffmpeg -y -loglevel error -i "$TMP_ORIGINAL" \
            -c:a libopus -b:a 24000 -ar 48000 "$TMP_CONVERTIDO"; then
            echo "❌ Erro na conversão"
            rm -rf "$TMP_DIR"
            exit 1
        fi
        TMP_ORIGINAL="$TMP_CONVERTIDO"
        NOME_SEM_EXT="${NOME_SEM_EXT}"
    fi

    # --- Processamento Anti-Fingerprint ---
    echo "🧬 Processando anti-fingerprint..."
    SUFIXO_RANDOM=$(shuf -i 100-999 -n1)
    NOME_FINAL="AUD${SUFIXO_RANDOM}s-${NOME_SEM_EXT}.opus"
    TMP_PROC="$TMP_DIR/$NOME_FINAL"
    
    BITRATE=$(shuf -i 24000-26000 -n1)

    if ! ffmpeg -y -loglevel error -i "$TMP_ORIGINAL" \
        -af "aresample=48000" \
        -map_metadata -1 \
        -c:a libopus -b:a ${BITRATE} -ar 48000 \
        -vbr on -application voip "$TMP_PROC"; then
        echo "❌ Erro FFmpeg"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    echo "📝 Arquivo processado: $NOME_FINAL"

    # --- Move para pasta Downloads do Clone ---
    echo "📂 Movendo para Downloads do User $USER_ID..."
    ARQUIVO_FINAL="$PASTA_DOWNLOADS_CLONE/$NOME_FINAL"
    
    # Cria pasta se não existir e copia
    su -c "mkdir -p '$PASTA_DOWNLOADS_CLONE'"
    su -c "cp '$TMP_PROC' '$ARQUIVO_FINAL'"
    su -c "chmod 644 '$ARQUIVO_FINAL'"

    # Limpa temp
    rm -rf "$TMP_DIR"

    # --- Aguarda antes de enviar ---
    echo "⏳ Aguardando 0.7s..."
    sleep 0.7

    # --- Envia via Intent ---
    echo "🚀 Enviando via Intent..."
    su -c "am start --user $USER_ID \
        -a android.intent.action.SEND \
        -t audio/* \
        --eu android.intent.extra.STREAM file://$ARQUIVO_FINAL \
        --es jid '$LEAD_JID' \
        -f 0x10000000 \
        $PKG_WHATSAPP" >/dev/null 2>&1

    # --- Confirma envio ---
    echo "⏳ Aguardando 0.5s..."
    sleep 0.5

    echo "✅ Confirmando envio..."
    input tap $COORD_CONFIRMAR_ENVIO

    # --- Aguarda processamento ---
    echo "⏳ Aguardando 1s..."
    sleep 1

    # --- Apaga arquivo modificado ---
    echo "🗑️ Removendo arquivo temporário..."
    su -c "rm -f '$ARQUIVO_FINAL'"

    # --- Aguarda e volta ---
    echo "⏳ Aguardando 0.5s..."
    sleep 0.5

    echo "🔙 Voltando..."
    input tap $COORD_VOLTAR

    echo "✅ User $USER_ID: Processo finalizado via Intent."
    exit 0
fi
