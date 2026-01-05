#!/data/data/com.termux/files/usr/bin/bash

# =====================================================================
# fazer_ligacao.sh — V5.2: MULTI-USER + COORDENADAS CORRIGIDAS
# =====================================================================

# 1. ARGUMENTOS (MULTI-USER)
USER_ID="$1"
LEAD="$2"
CALL="$3"   # voz ou video

# Validação do User ID
[ -z "$USER_ID" ] && { echo '{"erro":"user_id_nao_informado"}'; exit 1; }

# Arquivo temporário único por usuário
ANDROID_XML="/sdcard/ligacao_dump_${USER_ID}.xml"
PKG_WHATSAPP="com.whatsapp.w4b"

# 2. COORDENADAS DE NAVEGAÇÃO
COORD_PERFIL_TOPO="667 76"
COORD_VOLTAR="71 89"

# --- COORDENADAS BUSINESS ---
COORD_BUS_MENU="853 80"
COORD_BUS_VOZ="715 270"
COORD_BUS_VIDEO="688 439"

# --- COORDENADAS NORMAL ---
COORD_NORM_VOZ="885 78"
COORD_NORM_VIDEO="739 85"

# --- COORDENADAS COMUNS ---
COORD_INICIAR_LIGACAO="800 1031" # Popup "Deseja iniciar..."
COORD_DESLIGAR="929 1750"        # Botão vermelho

# ---------------------------------------------------------------------
# VALIDAÇÃO INICIAL
# ---------------------------------------------------------------------
[ -z "$LEAD" ] && { echo '{"erro":"lead_nao_informado"}'; exit 1; }
[ -z "$CALL" ] && { echo '{"erro":"call_nao_informado"}'; exit 1; }

CALL=$(echo "$CALL" | tr '[:upper:]' '[:lower:]')
if [ "$CALL" != "voz" ] && [ "$CALL" != "video" ]; then
    echo '{"erro":"call_invalido"}'
    exit 1
fi

# Tratamento do número para Intent
LEAD_CLEAN=$(echo "$LEAD" | tr -d ' +-' | sed 's/^55//')

# =====================================================================
# 1. ABRIR CONVERSA (INTENT ROOT MULTI-USER)
# =====================================================================
su -c "am start --user $USER_ID -a android.intent.action.VIEW -d 'https://wa.me/$LEAD_CLEAN' $PKG_WHATSAPP" >/dev/null 2>&1
sleep 3

# =====================================================================
# 2. DETECTAR TIPO DE CONTA (BUSINESS OU NORMAL)
# =====================================================================
# Clica no topo (Nome do perfil)
input tap $COORD_PERFIL_TOPO
sleep 1.5

# SCROLL PARA BAIXO (Para revelar "Conta comercial")
input swipe 515 1631 502 627 300
sleep 1

# Dump da tela (Via Root direto, mais seguro que ADB no Termux)
su -c "uiautomator dump $ANDROID_XML" >/dev/null 2>&1
sleep 0.5

# Análise Python
IS_BUSINESS=$(python3 - <<EOF
import xml.etree.ElementTree as ET
import os

xml_file = "$ANDROID_XML"

try:
    if not os.path.exists(xml_file):
        print("0")
        exit()

    tree = ET.parse(xml_file)
    root = tree.getroot()
    found = "0"
    for n in root.iter():
        text = (n.get("text") or "").strip()
        if "Conta comercial" in text:
            found = "1"
            break
    print(found)
except:
    print("0")
EOF
)

# Voltar para a tela de chat
input tap $COORD_VOLTAR
sleep 1

# =====================================================================
# 3. EXECUTAR LIGAÇÃO
# =====================================================================

if [ "$IS_BUSINESS" = "1" ]; then
    # --------------------------------------------------------
    # CONTATO BUSINESS (Menu Dropdown)
    # --------------------------------------------------------
    echo "📞 Modo Business Detectado"
    
    # 1. Abrir menu (três pontinhos/telefone com +)
    input tap $COORD_BUS_MENU
    sleep 1

    # 2. Selecionar Voz ou Vídeo
    if [ "$CALL" = "voz" ]; then
        input tap $COORD_BUS_VOZ
    else
        input tap $COORD_BUS_VIDEO
    fi

else
    # --------------------------------------------------------
    # CONTATO NORMAL (Botões diretos)
    # --------------------------------------------------------
    echo "📞 Modo Normal Detectado"

    # 1. Clicar direto no ícone
    if [ "$CALL" = "video" ]; then
        input tap $COORD_NORM_VIDEO
    else
        input tap $COORD_NORM_VOZ
    fi

fi

# =====================================================================
# 4. CONFIRMAÇÃO E DURAÇÃO (COMUM A AMBOS)
# =====================================================================

sleep 1

# 3. Confirmar Popup "Deseja iniciar chamada?"
input tap $COORD_INICIAR_LIGACAO

# Duração da chamada (Finge que fala por 5 segundos)
sleep 5

# 4. Encerrar ligação
input tap $COORD_DESLIGAR

# Voltar final (para lista de conversas)
sleep 1.5
input tap $COORD_VOLTAR

# =====================================================================
# RETORNO JSON
# =====================================================================
# Limpa arquivo temporário
rm -f "$ANDROID_XML" 2>/dev/null

echo "{\"status\":\"ligacao_realizada\",\"lead\":\"$LEAD\",\"tipo\":\"$CALL\",\"business\":\"$IS_BUSINESS\"}"
exit 0