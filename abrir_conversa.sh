#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Script: Abrir Conversa (Multi-User) — V2.0
# ============================================================================
# Abre a conversa do lead para marcar mensagens como lidas
# Argumentos:
#   $1 = USER_ID (ex: 0, 10)
#   $2 = byPhone (ex: 5516999999999 ou "Nome do Contato")
#   $3 = byTag   (ex: xyz123@s.whatsapp.net)
#   $4 = byKey   (ex: 0|com.whatsapp.w4b|...)
# ============================================================================

USER_ID="$1"
PHONE="$2"
TAG="$3"
KEY="$4"
PKG_WHATSAPP="com.whatsapp.w4b"

# Coordenadas para busca (quando contato está salvo)
COORD_LUPA="265 251"
COORD_RESULTADO="316 386"
COORD_VOLTAR="61 85"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Abrindo conversa do lead: $PHONE (User $USER_ID)"

# Valida argumentos
if [ -z "$USER_ID" ]; then
    echo "ERRO: User ID não informado"
    exit 1
fi

if [ -z "$PHONE" ]; then
    echo "ERRO: Telefone não informado"
    exit 1
fi

# ============================================================================
# DETECTA SE É NÚMERO OU NOME DE CONTATO
# ============================================================================

# Verifica se começa com 55 (número de telefone)
if [[ "$PHONE" =~ ^55 ]]; then
    # ========================================================================
    # CASO 1: É UM NÚMERO → ABRE VIA INTENT
    # ========================================================================
    echo "📱 Detectado número de telefone"
    
    # Limpeza do número (remove +, -, espaços)
    # Lógica inteligente para números brasileiros
    PHONE_TEMP=$(echo "$PHONE" | tr -d ' -')  # Remove espaços e hífens, mas mantém o +
    if [[ "$PHONE_TEMP" =~ ^\+55 ]]; then
        # Se começar com +55, remove apenas o +
        PHONE_CLEAN=$(echo "$PHONE_TEMP" | sed 's/^\+//')
    elif [[ "$PHONE_TEMP" =~ ^55 ]]; then
        # Se já começar com 55, mantém como está
        PHONE_CLEAN="$PHONE_TEMP"
    else
        # Se não tiver 55, adiciona
        PHONE_CLEAN="55$PHONE_TEMP"
    fi
    
    echo "🚀 Abrindo via Root Intent (User $USER_ID): $PHONE_CLEAN"
    
    # Usa intent com --user para garantir abertura no perfil correto
    su -c "am start --user $USER_ID -a android.intent.action.VIEW -d 'https://wa.me/$PHONE_CLEAN' $PKG_WHATSAPP" >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "ERRO: Falha ao abrir WhatsApp Business"
        exit 1
    fi
    
else
    # ========================================================================
    # CASO 2: É UM NOME → BUSCA E ABRE VIA LUPA
    # ========================================================================
    echo "👤 Detectado nome de contato salvo"
    
    # IMPORTANTE: Antes de clicar na lupa, precisamos trazer o WhatsApp 
    # desse usuário específico para frente.
    echo "🚀 Trazendo WhatsApp do User $USER_ID para frente..."
    su -c "am start --user $USER_ID -a android.intent.action.MAIN -c android.intent.category.LAUNCHER $PKG_WHATSAPP" >/dev/null 2>&1
    sleep 2.5
    
    echo "🔍 Indo para lupa..."
    input tap $COORD_LUPA
    sleep 1
    
    echo "⌨️ Digitando nome para busca: $PHONE"
    input text "$PHONE"
    sleep 3
    
    echo "👉 Clicando no primeiro resultado..."
    input tap $COORD_RESULTADO
    sleep 0.6
fi

echo "WhatsApp aberto. Aguardando marcar como lida..."

# Aguarda 3 segundos para garantir que a conversa carregou e marcou como lida
sleep 3

# ============================================================================
# SCROLL NO CHAT (PARA GARANTIR LEITURA)
# ============================================================================
echo "Scrolling no chat para garantir visualização..."

# Variação gaussiana de até 15 pixels (usando random simplificado)
RAND1=$((RANDOM % 31 - 15))  # -15 a +15
RAND2=$((RANDOM % 31 - 15))
RAND3=$((RANDOM % 31 - 15))
RAND4=$((RANDOM % 31 - 15))

# Primeiro scroll: 506,306 -> 633,1515 (com variação)
X1=$((506 + RAND1))
Y1=$((306 + RAND2))
X2=$((633 + RAND3))
Y2=$((1515 + RAND4))

input swipe $X1 $Y1 $X2 $Y2 300

sleep 1

# Variação para segundo scroll
RAND5=$((RANDOM % 31 - 15))
RAND6=$((RANDOM % 31 - 15))
RAND7=$((RANDOM % 31 - 15))
RAND8=$((RANDOM % 31 - 15))

# Segundo scroll: 549,1593 -> 508,272 (com variação)
X3=$((549 + RAND5))
Y3=$((1593 + RAND6))
X4=$((508 + RAND7))
Y4=$((272 + RAND8))

input swipe $X3 $Y3 $X4 $Y4 300

sleep 1

# ============================================================================
# VOLTA PARA LISTA DE CONVERSAS
# ============================================================================
echo "Voltando para lista de conversas..."
input tap $COORD_VOLTAR

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Conversa aberta com sucesso: $PHONE"
exit 0