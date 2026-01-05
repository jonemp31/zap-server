#!/data/data/com.termux/files/usr/bin/bash

# =====================================================================
# enviar_texto.sh — V7.0: MULTI-USER INTENT (SEM VALIDAÇÃO VISUAL)
# =====================================================================

# 1. CONFIGURAÇÕES
COORD_CAMPO_TEXTO="360 1841"
COORD_ENVIAR="994 1841"
PKG_WHATSAPP="com.whatsapp.w4b"
COORD_BTN_VOLTAR="70 80"

# 2. ENTRADAS (ATUALIZADO PARA MULTI-USER)
USER_ID="$1"
MSG="$2"
LEAD="$3"

# Validações básicas de entrada
[ -z "$USER_ID" ] && { echo "❌ User ID não informado"; exit 1; }
[ -z "$MSG" ] && { echo "❌ Mensagem vazia"; exit 1; }
[ -z "$LEAD" ] && { echo "❌ Lead não informado"; exit 1; }

# Limpeza do número para garantir que o link funcione (remove + - e espaços)
LEAD_CLEAN=$(echo "$LEAD" | tr -d ' +-')

# ============================================================
# FUNÇÃO: GERADOR DE DIGITAÇÃO (LÓGICA SENIOR)
# ============================================================
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

# Define velocidade baseada no horário
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

    # 5% de erro humano
    if random.random() < 0.05: 
        comandos.append('input text x')
        comandos.append('sleep 0.12')
        comandos.append('input keyevent 67')
        comandos.append('sleep 0.15')

    # === LÓGICA DE ESCAPE ===
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

# ============================================================
# EXECUÇÃO DIRETA (INTENT) - MULTI USER
# ============================================================
echo "🚀 Abrindo via Root Intent (User $USER_ID): $LEAD_CLEAN"

# Abre o link direto no perfil do usuário especificado
su -c "am start --user $USER_ID -a android.intent.action.VIEW -d 'https://wa.me/$LEAD_CLEAN' $PKG_WHATSAPP" >/dev/null 2>&1

# Aguarda carregamento da conversa (ajuste se seu celular for lento)
sleep 3

# --- VALIDAÇÃO REMOVIDA AQUI ---
# O script assume que a conversa abriu corretamente.

echo "🎯 Focando campo..."
input tap $COORD_CAMPO_TEXTO
sleep 0.5

echo "⌨️ Digitando..."
CMD_DIGITACAO=$(gerar_comandos_humanos "$MSG")
eval "$CMD_DIGITACAO"

sleep 0.5
echo "📨 Enviando..."
input tap $COORD_ENVIAR

# ============================================================
# FINALIZAÇÃO: VOLTAR PARA LISTA DE CONVERSAS
# ============================================================
echo "🔙 Calculando delay para voltar..."

# Gera um delay aleatório entre 0.5 e 1.5
DELAY_VOLTAR=$(python3 -c "import random; print(round(random.uniform(0.5, 1.5), 2))")

echo "⏳ Aguardando ${DELAY_VOLTAR}s..."
sleep $DELAY_VOLTAR

echo "🔙 Pressionando Voltar..."
input tap $COORD_BTN_VOLTAR

echo "✅ Concluído."
exit 0