#!/data/data/com.termux/files/usr/bin/bash

# =====================================================================
# pix.sh — V5.9: OCR + LAYOUT SWITCHER (COORDENADAS CORRIGIDAS)
# =====================================================================

# 1. ARGUMENTOS E CONFIGS
USER_ID="$1"
LEAD="$2"
PKG_WHATSAPP="com.whatsapp.w4b"

# Validações Básicas
[ -z "$USER_ID" ] && { echo "❌ User ID não informado"; exit 1; }
[ -z "$LEAD" ] && { echo "❌ Lead não informado"; exit 1; }

# Lógica inteligente para números brasileiros
LEAD_TEMP=$(echo "$LEAD" | tr -d ' -')  # Remove espaços e hífens, mas mantém o +
if [[ "$LEAD_TEMP" =~ ^\+55 ]]; then
    # Se começar com +55, remove apenas o +
    LEAD_CLEAN=$(echo "$LEAD_TEMP" | sed 's/^\+//')
elif [[ "$LEAD_TEMP" =~ ^55 ]]; then
    # Se já começar com 55, mantém como está
    LEAD_CLEAN="$LEAD_TEMP"
else
    # Se não tiver 55, adiciona
    LEAD_CLEAN="55$LEAD_TEMP"
fi

# Dados da Chave
CHAVE_PIX="16991500219"
NOME_BANCO="Banco Inter Chave Pix"

# 2. COORDENADAS PADRÃO (LAYOUT 1 - ANTIGO)
COORD_CLIPE="696 1832"
COORD_ICON_PAGAMENTO="409 1240"
COORD_BTN_ENVIAR_PEDIDO="563 1820"
COORD_VOLTAR_APP="71 89"

# =====================================================================
# FUNÇÃO DIGITAÇÃO LIMPA
# =====================================================================
gerar_digitacao_limpa() {
    local TEXTO_INPUT="$1"
    python3 - "$TEXTO_INPUT" << 'EOF'
import sys, random, unicodedata
texto = sys.argv[1] if len(sys.argv) > 1 else ""
def remove_acentos(s):
    nfkd = unicodedata.normalize("NFD", s)
    return "".join(c for c in nfkd if not unicodedata.combining(c))
texto = remove_acentos(texto).strip()
if not texto: print("sleep 0.1"); sys.exit(0)
comandos = []
for char in texto:
    delay = round(random.uniform(0.05, 0.15), 3)
    if char == ' ': comandos.append(f'input keyevent 62; sleep {round(random.uniform(0.1, 0.2), 3)}'); continue
    if char == '\\': comandos.append('input text "\\\\"'); continue
    if char == '"': comandos.append('input text "\\""'); continue
    comandos.append(f'input text "{char}"')
    comandos.append(f'sleep {delay}')
print(';'.join(comandos))
EOF
}

# =====================================================================
# 1. ABRIR CONVERSA
# =====================================================================
echo "🚀 Abrindo conversa (User $USER_ID)..."
su -c "am start --user $USER_ID -a android.intent.action.VIEW -d 'https://wa.me/$LEAD_CLEAN' $PKG_WHATSAPP" >/dev/null 2>&1
sleep 3

# =====================================================================
# 2. ACESSAR MENU
# =====================================================================
echo "📎 Clicando no Clipe..."
input tap $COORD_CLIPE
sleep 1

echo "💰 Clicando em Pagamento..."
input tap $COORD_ICON_PAGAMENTO
sleep 3.5  # Tempo para a tela carregar

# =====================================================================
# 3. VERIFICAÇÃO DE TELA COM OCR (TESSERACT)
# =====================================================================
echo "👁️  Lendo a tela com Tesseract..."

IMG_SCREEN="/data/local/tmp/ocr_scan.png"
TXT_FINAL="$HOME/ocr_result.txt"

# 1. Tira Print
su -c "screencap -p $IMG_SCREEN"

# 2. Processa Imagem -> Texto
cp "$IMG_SCREEN" "$HOME/scan_temp.png" 2>/dev/null || su -c "cat $IMG_SCREEN" > "$HOME/scan_temp.png"
tesseract "$HOME/scan_temp.png" "$HOME/ocr_result" -l por >/dev/null 2>&1

# 3. Lê o resultado
CONTEUDO=$(cat "$HOME/ocr_result.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]')

# --- LÓGICA DE DETECÇÃO DE LAYOUT ---
LAYOUT_DETECTADO="0" # 0=Nada, 1=Antigo, 2=Novo

# LAYOUT 1 (Padrão/Antigo)
if [[ "$CONTEUDO" == *"adicionar chave"* ]] || \
   [[ "$CONTEUDO" == *"adicionando sua chave"* ]] || \
   [[ "$CONTEUDO" == *"pix"* && "$CONTEUDO" == *"começar"* ]]; then
    LAYOUT_DETECTADO="1"
fi

# LAYOUT 2 (Novo - Variação solicitada)
if [[ "$CONTEUDO" == *"adicionar dados do pix"* ]] || \
   [[ "$CONTEUDO" == *"seu nome e sua chave pix"* ]]; then
    LAYOUT_DETECTADO="2"
fi

# Limpeza
rm -f "$HOME/scan_temp.png" "$HOME/ocr_result.txt" 2>/dev/null
su -c "rm -f $IMG_SCREEN" 2>/dev/null

echo "📊 Diagnóstico OCR: Layout Detectado -> Tipo $LAYOUT_DETECTADO"

# =====================================================================
# 4. AÇÃO (COM SWITCH DE COORDENADAS)
# =====================================================================

if [ "$LAYOUT_DETECTADO" != "0" ]; then
    echo "⚙️ Configuração necessária (Layout $LAYOUT_DETECTADO). Iniciando..."
    
    # Scroll Comum (Mantém igual para ambos)
    echo "📜 Rolando tela..."
    input swipe 523 709 521 257 300
    sleep 1
    
    # --- IF/ELSE PARA DEFINIR CLIQUES ---
    if [ "$LAYOUT_DETECTADO" == "2" ]; then
        # >>> LAYOUT NOVO (COORDENADAS CORRIGIDAS) <<<
        echo "📍 Usando coordenadas do NOVO Layout..."
        
        # Seleciona Tipo de Chave (Atualizado)
        input tap 943 880
        sleep 0.8
        
        # Clica no campo 1 (Atualizado)
        input tap 260 884
        sleep 0.5
        
        # Clica no campo 2 - Foco (Atualizado)
        input tap 319 1061
        
        # Vars para Nome/Salvar (Atualizadas)
        COORD_NOME_Y="242 1265"
        COORD_SALVAR_Y="503 1558"
        
    else
        # >>> LAYOUT ANTIGO (PADRÃO) <<<
        echo "📍 Usando coordenadas do Layout PADRÃO..."
        
        # Seleciona Tipo de Chave
        input tap 906 822
        sleep 0.8
        
        # Clica no campo 1
        input tap 251 997
        sleep 0.5
        
        # Clica no campo 2 (foco)
        input tap 293 1067
        
        # Coords antigas
        COORD_NOME_Y="242 1304"
        COORD_SALVAR_Y="546 1834"
    fi
    
    # --- DIGITAÇÃO (COMUM) ---
    echo "⌨️ Digitando Chave..."
    eval "$(gerar_digitacao_limpa "$CHAVE_PIX")"
    sleep 0.8
    
    # --- CLIQUE NOME (DINÂMICO) ---
    input tap $COORD_NOME_Y
    
    echo "📝 Digitando Nome..."
    eval "$(gerar_digitacao_limpa "$NOME_BANCO")"
    sleep 0.8
    
    # --- SALVAR (DINÂMICO) ---
    echo "💾 Salvando..."
    input tap $COORD_SALVAR_Y
    
    echo "⏳ Aguardando validação bancária (5.5s)..."
    sleep 5.5
    
    echo "✅ Cadastro finalizado."
else
    echo "✅ Chave já configurada (ou tela não reconhecida)."
fi

# =====================================================================
# 5. ENVIAR PEDIDO
# =====================================================================
echo "💸 Enviando pedido..."
sleep 0.5
input tap $COORD_BTN_ENVIAR_PEDIDO

# =====================================================================
# FIM
# =====================================================================
DELAY=$(python3 -c "import random; print(round(random.uniform(0.5, 1.5), 2))")
sleep $DELAY
echo "🔙 Voltando..."
input tap $COORD_VOLTAR_APP

exit 0