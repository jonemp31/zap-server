#!/data/data/com.termux/files/usr/bin/bash

# =====================================================================
# salvar_contato.sh — V5.8: OCR + SCROLL + NOVAS COORDENADAS
# =====================================================================

# 1. ENTRADAS (MULTI-USER)
USER_ID="$1"
LEAD="$2"        # Número do telefone
SALVARCOMO="$3"  # Nome do contato

# Gera data atual
DATA_ATUAL=$(date +%d/%m/%Y)

# 2. COORDENADAS (ATUALIZADAS)
COORD_BTN_NOVO="950 1540"

# Campos de Nome
COORD_CAMPO_1="475 494"
COORD_CAMPO_NOME_FINAL="392 314"

# Campo Data
COORD_CAMPO_DATA="360 557"

# País e Telefone
COORD_PAIS_CHECK="471 821"      # Seletor de país
COORD_BUSCA_PAIS="995 75"       # Lupa país
COORD_RESULTADO_PAIS="321 240"  # Clique no resultado da busca
COORD_CAMPO_PRE_TEL="684 836"   # Clique antes do telefone
COORD_CAMPO_TEL="791 834"       # Campo onde digita o número

# Botões Finais
COORD_BTN_SALVAR="557 1803"
COORD_BTN_VOLTAR="68 89"

# --------------------------
# VALIDAÇÕES
# --------------------------
[ -z "$USER_ID" ] && { echo '{"erro":"user_id_nao_informado"}'; exit 1; }
[ -z "$LEAD" ] && { echo '{"erro":"lead_nao_informado"}'; exit 1; }
[ -z "$SALVARCOMO" ] && { echo '{"erro":"nome_nao_informado"}'; exit 1; }

LEAD_SEM_DDI=$(echo "$LEAD" | tr -d ' +-' | sed 's/^55//')

# Configuração de Arquivos Temporários para OCR
IMG_SCREEN="/data/local/tmp/ocr_contato.png"
TXT_RESULT="$HOME/ocr_contato_res"

# =====================================================================
# FUNÇÃO: DIGITAÇÃO LIMPA
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
if not texto: sys.exit(0)
comandos = []
for char in texto:
    if char == ' ': comandos.append('input keyevent 62'); continue
    if char in ['\\', '"', '`', '$']: comandos.append(f'input text "\\{char}"')
    else: comandos.append(f'input text "{char}"')
    comandos.append('sleep 0.05')
print(';'.join(comandos))
EOF
}

# =====================================================================
# FUNÇÃO AUXILIAR: RODAR OCR NA TELA ATUAL
# =====================================================================
ler_tela_ocr() {
    # 1. Tira print via Root (Global)
    su -c "screencap -p $IMG_SCREEN"
    
    # 2. Traz para o Termux
    cp "$IMG_SCREEN" "$HOME/scan_temp.png" 2>/dev/null || su -c "cat $IMG_SCREEN" > "$HOME/scan_temp.png"
    
    # 3. Roda Tesseract
    tesseract "$HOME/scan_temp.png" "$TXT_RESULT" -l por >/dev/null 2>&1
    
    # 4. Retorna conteúdo minúsculo
    cat "${TXT_RESULT}.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

# =====================================================================
# PASSO 0: HOME CHECK SAFETY
# =====================================================================
echo "🔍 Verificando se estamos na tela inicial do WhatsApp..."

rm -f "$HOME/scan_temp.png" "${TXT_RESULT}.txt" 2>/dev/null

CONTEUDO_HOME=$(ler_tela_ocr)

IS_HOME="0"

if [[ "$CONTEUDO_HOME" == *"conversas"* ]] || \
   [[ "$CONTEUDO_HOME" == *"atualizações"* ]] || \
   [[ "$CONTEUDO_HOME" == *"ferramentas"* ]] || \
   [[ "$CONTEUDO_HOME" == *"pesquisar"* ]]; then
    IS_HOME="1"
fi

if [ "$IS_HOME" = "1" ]; then
    echo "✅ Tela inicial detectada!"
else
    echo "❌ ERRO CRÍTICO: Não estamos na tela inicial do WhatsApp."
    echo "📄 OCR Leu: $(echo "$CONTEUDO_HOME" | head -n 3)..."
    echo '{"erro":"tela_inicial_nao_detectada"}'
    exit 1
fi

# =====================================================================
# 1. INICIAR E DIGITAR NOME (COM SCROLL)
# =====================================================================
echo "➕ Clicando em Novo Contato..."
input tap $COORD_BTN_NOVO
sleep 1.5

# --- NOVA AÇÃO: SCROLL ---
echo "📜 Rolando tela..."
input swipe 523 653 485 1622 300
sleep 0.5
# -------------------------

input tap $COORD_CAMPO_1
sleep 1

input tap $COORD_CAMPO_NOME_FINAL
sleep 0.5

echo "📝 Digitando Nome: $SALVARCOMO"
CMD_NOME=$(gerar_digitacao_limpa "$SALVARCOMO")
eval "$CMD_NOME"
sleep 1

# =====================================================================
# 2. DATA
# =====================================================================
echo "📅 Digitando Data: $DATA_ATUAL"
input tap $COORD_CAMPO_DATA
sleep 1
input text "$DATA_ATUAL"
sleep 1

# =====================================================================
# 3. VERIFICAR E AJUSTAR PAÍS (OCR)
# =====================================================================
echo "🌍 Verificando País via OCR..."
sleep 0.5

CONTEUDO_PAIS=$(ler_tela_ocr)

if [[ "$CONTEUDO_PAIS" == *"+55"* ]]; then
    echo "✅ País Brasil (+55) detectado."
else
    echo "⚠️ Selecionando Brasil..."
    input tap $COORD_PAIS_CHECK
    sleep 0.5
    
    input tap $COORD_BUSCA_PAIS
    sleep 0.5
    
    input text "Brasil"
    sleep 1
    
    # Clica no resultado (Coordenada nova)
    input tap $COORD_RESULTADO_PAIS 
    sleep 1
fi

# =====================================================================
# 4. DIGITAR TELEFONE
# =====================================================================
echo "📞 Inserindo telefone..."
input tap $COORD_CAMPO_PRE_TEL
sleep 0.5

input tap $COORD_CAMPO_TEL
sleep 0.5

echo "⌨️ Digitando Número: $LEAD_SEM_DDI"
input text "$LEAD_SEM_DDI"
sleep 2 # Tempo para o app validar o zap

# =====================================================================
# 5. VALIDAÇÃO WHATSAPP (OCR CRÍTICO)
# =====================================================================
echo "🛡️ Validando WhatsApp via OCR..."
sleep 1 

CONTEUDO_VALIDACAO=$(ler_tela_ocr)

IS_VALID="0"

if [[ "$CONTEUDO_VALIDACAO" == *"telefone já está no whatsapp"* ]] || \
   [[ "$CONTEUDO_VALIDACAO" == *"esse número de telefone já está"* ]] || \
   [[ "$CONTEUDO_VALIDACAO" == *"essa pessoa já está na sua lista"* ]] || \
   [[ "$CONTEUDO_VALIDACAO" == *"já está no whatsapp"* ]]; then
    IS_VALID="1"
fi

if [ "$IS_VALID" = "1" ]; then
    echo "✅ Número validado (WhatsApp/Lista)!"
else
    echo "❌ ERRO: Número não tem WhatsApp ou validação falhou."
    
    input tap $COORD_BTN_VOLTAR
    sleep 1
    
    rm -f "$HOME/scan_temp.png" "${TXT_RESULT}.txt" 2>/dev/null
    su -c "rm -f $IMG_SCREEN" 2>/dev/null

    echo "{\"status\":\"erro_validacao_whatsapp\",\"lead\":\"$LEAD\"}"
    exit 1
fi

sleep 0.5

# =====================================================================
# 6. SALVAR E FINALIZAR
# =====================================================================
echo "💾 Salvando..."
input tap $COORD_BTN_SALVAR
sleep 0.5

echo "🔙 Voltando..."
input tap $COORD_BTN_VOLTAR

# Limpeza Final
rm -f "$HOME/scan_temp.png" "${TXT_RESULT}.txt" 2>/dev/null
su -c "rm -f $IMG_SCREEN" 2>/dev/null

echo "{\"status\":\"contato_salvo\",\"nome\":\"$SALVARCOMO\",\"lead\":\"$LEAD\"}"
exit 0