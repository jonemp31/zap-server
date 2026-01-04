#!/data/data/com.termux/files/usr/bin/bash

# =====================================================================
# pegar_numero.sh — V5.6: AUTO-OPEN (DIRECT COMPONENT) + OCR
# =====================================================================

# 1. ARGUMENTOS (MULTI-USER)
USER_ID="$1"
PKG_WHATSAPP="com.whatsapp.w4b"

# Validação do User ID
[ -z "$USER_ID" ] && { echo "{\"erro\": \"user_id_nao_informado\"}"; exit 1; }

# 2. CONFIGURAÇÕES DE COORDENADAS
COORD_FAB_NOVA_CONVERSA="950 1547"
COORD_VOLTAR="68 82" 

# Configuração de Arquivos Temporários para OCR
IMG_SCREEN="/data/local/tmp/ocr_numero.png"
TXT_RESULT="$HOME/ocr_numero_res"

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
# PASSO 0: ABERTURA FORÇADA (INTENT VIA COMPONENTE)
# =====================================================================
echo "🚀 Abrindo WhatsApp via Component Intent (User $USER_ID)..." >&2

# 🔥 COMANDO ATUALIZADO: Abre direto a Activity Principal
su -c "am start --user $USER_ID -n $PKG_WHATSAPP/com.whatsapp.Main" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "ERRO: Falha crítica ao iniciar Intent." >&2
    echo "{\"erro\": \"falha_abertura_app\"}"
    exit 1
fi

echo "⏳ Aguardando carregamento (2.5s)..." >&2
sleep 2.5

# =====================================================================
# PASSO 1: HOME CHECK SAFETY (VALIDAÇÃO DA TELA)
# =====================================================================
rm -f "$HOME/scan_temp.png" "${TXT_RESULT}.txt" 2>/dev/null
CONTEUDO_HOME=$(ler_tela_ocr)

IS_HOME="0"

# Palavras-chave da tela inicial
if [[ "$CONTEUDO_HOME" == *"conversas"* ]] || \
   [[ "$CONTEUDO_HOME" == *"atualizações"* ]] || \
   [[ "$CONTEUDO_HOME" == *"ferramentas"* ]] || \
   [[ "$CONTEUDO_HOME" == *"pesquisar"* ]]; then
    IS_HOME="1"
fi

# Se NÃO estiver na home, tenta voltar uma vez
if [ "$IS_HOME" = "0" ]; then
    echo "⚠️ Tela inicial não detectada de primeira. Tentando voltar..." >&2
    input tap $COORD_VOLTAR
    sleep 1.5
    
    # Re-check
    CONTEUDO_HOME=$(ler_tela_ocr)
    if [[ "$CONTEUDO_HOME" == *"conversas"* ]] || \
       [[ "$CONTEUDO_HOME" == *"pesquisar"* ]]; then
        IS_HOME="1"
    fi
fi

if [ "$IS_HOME" = "0" ]; then
    echo "❌ ERRO: Não foi possível acessar a tela inicial do WhatsApp." >&2
    echo "{\"erro\": \"tela_inicial_nao_detectada\"}"
    exit 1
fi

# CLIQUE EM CONVERSAS PARA NAO TER ERRO
sleep 1.0
input tap 129 1769
sleep 1.0

# =====================================================================
# PASSO 2: NAVEGAÇÃO (ABRIR LISTA DE CONTATOS)
# =====================================================================
input tap $COORD_FAB_NOVA_CONVERSA
sleep 1.5

# =====================================================================
# PASSO 3: LEITURA DA TELA (OCR NA LISTA)
# =====================================================================
rm -f "$HOME/scan_temp.png" "${TXT_RESULT}.txt" 2>/dev/null
CONTEUDO_LISTA=$(ler_tela_ocr)

# Salvamos o texto cru num arquivo para o Python processar linha a linha
cp "${TXT_RESULT}.txt" "$HOME/lista_raw.txt"

# =====================================================================
# PASSO 4: EXTRAÇÃO INTELIGENTE (PYTHON)
# =====================================================================
NUMERO_DETECTADO=$(python3 - <<EOF
import sys
import re

try:
    with open("$HOME/lista_raw.txt", "r") as f:
        lines = f.readlines()

    found = ""
    for line in lines:
        text = line.lower().strip()
        
        # Procura a linha que tem "(você)" ou "(you)"
        if "(voc" in text or "(you)" in text:
            clean = text.replace("(você)", "").replace("(voce)", "").replace("(you)", "").strip()
            # Limpa tudo que não for número ou +
            clean_number = re.sub(r'[^0-9+ ]', '', clean).strip()
            
            if len(clean_number) > 8: 
                found = clean_number
                break
            
    print(found)

except Exception:
    print("")
EOF
)

# =====================================================================
# PASSO 5: VOLTAR E RETORNAR
# =====================================================================
# Volta para a tela inicial
input tap $COORD_VOLTAR

# Limpeza
rm -f "$HOME/scan_temp.png" "${TXT_RESULT}.txt" "$HOME/lista_raw.txt" 2>/dev/null
su -c "rm -f $IMG_SCREEN" 2>/dev/null

# Retorno JSON
if [ -z "$NUMERO_DETECTADO" ] || [ ${#NUMERO_DETECTADO} -lt 5 ]; then
    echo "{\"erro\": \"numero_nao_encontrado_ocr\"}"
    exit 1
else
    echo "{\"numerowhatsapp\": \"$NUMERO_DETECTADO\"}"
    exit 0
fi