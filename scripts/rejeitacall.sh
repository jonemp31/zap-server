#!/data/data/com.termux/files/usr/bin/bash

# =====================================================================
# rejeitacall.sh — V1.3: CORREÇÃO DE FOCO MULTI-USER
# =====================================================================

# 1. ARGUMENTOS E CONFIGS
USER_ID="$1"
LEAD="$2"
PKG_WHATSAPP="com.whatsapp.w4b"

# Validação básica
[ -z "$USER_ID" ] && { echo "❌ User ID não informado"; exit 1; }

# Limpa o número do lead para comparação no OCR
LEAD_NUM=$(echo "$LEAD" | tr -d ' +-' | sed 's/^55//')
LEAD_FULL=$(echo "$LEAD" | tr -d ' +-')

# --- COORDENADAS ---
COORD_NOTIFICACAO="483 93"          # Clica na barra verde superior

# 🔴 SWIPE AJUSTADO
COORD_REJEITAR_INI="182 1681"
COORD_REJEITAR_FIM="182 1184"

COORD_POPUP_FECHAR="244 1281"       # Botão para fechar o Popup de Denúncia

# Caminhos Temp
IMG_SCREEN="/data/local/tmp/call_scan_$USER_ID.png"
IMG_LOCAL="$HOME/call_scan_$USER_ID.png"
TXT_RESULT="$HOME/ocr_call_$USER_ID"

# =====================================================================
# FUNÇÃO: OCR SNAPSHOT
# =====================================================================
fazer_ocr() {
    echo "📸 Analisando tela..."
    su -c "screencap -p $IMG_SCREEN"
    cp "$IMG_SCREEN" "$IMG_LOCAL" 2>/dev/null || su -c "cat $IMG_SCREEN" > "$IMG_LOCAL"
    tesseract "$IMG_LOCAL" "$TXT_RESULT" -l por >/dev/null 2>&1
    cat "${TXT_RESULT}.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

# =====================================================================
# PASSO 1: FOCAR NO WHATSAPP CORRETO (CORRIGIDO)
# =====================================================================
echo "🚀 Focando WhatsApp (User $USER_ID)..."

# 🔴 FIX: Trocamos 'monkey' por 'am start --user'
# Isso garante que ele traga para frente APENAS o app do usuário correto
su -c "am start --user $USER_ID -a android.intent.action.MAIN -c android.intent.category.LAUNCHER $PKG_WHATSAPP" >/dev/null 2>&1

sleep 1.5

# =====================================================================
# VERIFICAÇÃO OCR
# =====================================================================
CONTEUDO_TELA=$(fazer_ocr)

KEYWORDS=("acao recebida" "ação recebida" "chamando" "ligacao de voz" "video perdida" "recebida")
DETECTOU_CHAMADA=false

# 1. Verifica palavras genéricas
for word in "${KEYWORDS[@]}"; do
    if [[ "$CONTEUDO_TELA" == *"$word"* ]]; then
        DETECTOU_CHAMADA=true
        echo "✅ Chamada detectada por texto: '$word'"
        break
    fi
done

# 2. Verifica se o número do lead aparece
if [ "$DETECTOU_CHAMADA" = "false" ] && [ ! -z "$LEAD_NUM" ]; then
    if [[ "$CONTEUDO_TELA" == *"$LEAD_NUM"* ]] || [[ "$CONTEUDO_TELA" == *"$LEAD_FULL"* ]]; then
        DETECTOU_CHAMADA=true
        echo "✅ Chamada detectada pelo número: $LEAD_NUM"
    fi
fi

if [ "$DETECTOU_CHAMADA" = "true" ]; then
    # =================================================================
    # PASSO 2: CLICAR NA NOTIFICAÇÃO
    # =================================================================
    echo "point: Notificação encontrada. Expandindo..."
    input tap $COORD_NOTIFICACAO
    sleep 1.0

    # =================================================================
    # PASSO 3: EXECUTAR O SWIPE DE REJEIÇÃO
    # =================================================================
    echo "📞 Rejeitando chamada..."

    # OBS: Mantive o swipe rápido (300ms) do seu código original (V1.2).
    # Se quiser o swipe lento (2000ms) do gravar_fake, mude o 300 para 2000 aqui.
    input swipe $COORD_REJEITAR_INI $COORD_REJEITAR_FIM 300

    echo "⏳ Aguardando reação do app..."
    sleep 2.0

    # =================================================================
    # PASSO 4: VERIFICAR POPUP "DENUNCIAR"
    # =================================================================
    echo "🛡️ Verificando Popup de Denúncia..."

    CONTEUDO_POPUP=$(fazer_ocr)

    if [[ "$CONTEUDO_POPUP" == *"denunciar"* ]] || \
       [[ "$CONTEUDO_POPUP" == *"bloquear"* ]] || \
       [[ "$CONTEUDO_POPUP" == *"lista de contatos"* ]] || \
       [[ "$CONTEUDO_POPUP" == *"spam"* ]]; then

        echo "⚠️ Popup detectado! Fechando..."
        input tap $COORD_POPUP_FECHAR
        sleep 0.5
    else
        echo "✅ Nenhum popup detectado."
    fi

else
    echo "⚠️ Nenhuma chamada ativa detectada na tela."
fi

# =====================================================================
# LIMPEZA
# =====================================================================
rm -f "$IMG_LOCAL" "${TXT_RESULT}.txt" 2>/dev/null
su -c "rm -f $IMG_SCREEN" 2>/dev/null

echo "🏁 Fim do script de rejeição."
exit 0