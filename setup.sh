#!/data/data/com.termux/files/usr/bin/bash

# ============================================================================
# 🚀 ZAP SERVER - INSTALADOR AUTOMÁTICO v2.0
# ============================================================================
# Uso: bash <(curl -sSL https://raw.githubusercontent.com/jonemp31/zap-server/main/setup.sh)
# ============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     ███████╗ █████╗ ██████╗     ███████╗███████╗██████╗       ║"
echo "║     ╚══███╔╝██╔══██╗██╔══██╗    ██╔════╝██╔════╝██╔══██╗      ║"
echo "║       ███╔╝ ███████║██████╔╝    ███████╗█████╗  ██████╔╝      ║"
echo "║      ███╔╝  ██╔══██║██╔═══╝     ╚════██║██╔══╝  ██╔══██╗      ║"
echo "║     ███████╗██║  ██║██║         ███████║███████╗██║  ██║      ║"
echo "║     ╚══════╝╚═╝  ╚═╝╚═╝         ╚══════╝╚══════╝╚═╝  ╚═╝      ║"
echo "║                                                               ║"
echo "║              🤖 INSTALADOR AUTOMÁTICO v2.0                    ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Variáveis
REPO_URL="https://raw.githubusercontent.com/jonemp31/zap-server/main"
HOME_DIR="/data/data/com.termux/files/home"
INSTALL_DIR="$HOME_DIR/zap-server"

# Webhooks padrão
DEFAULT_WEBHOOK_DATA="https://webhook-dev.zapsafe.work/webhook/whatsapp4mumu"
DEFAULT_WEBHOOK_CLEAN="https://webhook-dev.zapsafe.work/webhook/limparnotificacaozapmu"
DEFAULT_DOMAIN="painelopen.win"

# Funções de log
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# ============================================================================
# 📝 CONFIGURAÇÃO INTERATIVA
# ============================================================================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  📝 CONFIGURAÇÃO INICIAL                      ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# --- PERGUNTA 1: Nome do Device ---
echo -e "${YELLOW}1. Qual o nome deste device?${NC}"
echo -e "   ${BLUE}Exemplo: mumu1, mumu2, mumu3${NC}"
echo -e "   ${BLUE}(Será usado como: server_NOME)${NC}"
read -p "   ➤ Nome: " DEVICE_NAME

if [ -z "$DEVICE_NAME" ]; then
    DEVICE_NAME="mumu1"
    log_warn "Nome não informado. Usando padrão: $DEVICE_NAME"
fi

TUNNEL_NAME="server_${DEVICE_NAME}"
SUBDOMAIN="${DEVICE_NAME}"

echo ""
log_success "Device: $DEVICE_NAME"
log_success "Tunnel: $TUNNEL_NAME"

# --- PERGUNTA 2: Domínio ---
echo ""
echo -e "${YELLOW}2. Deseja manter o domínio padrão? (${DEFAULT_DOMAIN})${NC}"
read -p "   ➤ [Y/n]: " USE_DEFAULT_DOMAIN

if [[ "$USE_DEFAULT_DOMAIN" =~ ^[Nn]$ ]]; then
    echo -e "   ${BLUE}Digite o novo domínio (ex: meudominio.com):${NC}"
    read -p "   ➤ Domínio: " CUSTOM_DOMAIN
    if [ -z "$CUSTOM_DOMAIN" ]; then
        DOMAIN="$DEFAULT_DOMAIN"
        log_warn "Domínio não informado. Usando padrão: $DOMAIN"
    else
        DOMAIN="$CUSTOM_DOMAIN"
    fi
else
    DOMAIN="$DEFAULT_DOMAIN"
fi

FULL_HOSTNAME="${SUBDOMAIN}.${DOMAIN}"

echo ""
log_success "Domínio: $DOMAIN"
log_success "URL Final: https://${FULL_HOSTNAME}"

# --- PERGUNTA 3: Webhooks ---
echo ""
echo -e "${YELLOW}3. Deseja manter as webhooks padrão?${NC}"
echo -e "   ${BLUE}Data:  $DEFAULT_WEBHOOK_DATA${NC}"
echo -e "   ${BLUE}Clean: $DEFAULT_WEBHOOK_CLEAN${NC}"
read -p "   ➤ [Y/n]: " USE_DEFAULT_WEBHOOKS

if [[ "$USE_DEFAULT_WEBHOOKS" =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "   ${BLUE}Digite a webhook de DATA (notificações):${NC}"
    read -p "   ➤ Webhook Data: " CUSTOM_WEBHOOK_DATA
    
    echo -e "   ${BLUE}Digite a webhook de CLEAN (limpar notificações):${NC}"
    read -p "   ➤ Webhook Clean: " CUSTOM_WEBHOOK_CLEAN
    
    WEBHOOK_DATA="${CUSTOM_WEBHOOK_DATA:-$DEFAULT_WEBHOOK_DATA}"
    WEBHOOK_CLEAN="${CUSTOM_WEBHOOK_CLEAN:-$DEFAULT_WEBHOOK_CLEAN}"
else
    WEBHOOK_DATA="$DEFAULT_WEBHOOK_DATA"
    WEBHOOK_CLEAN="$DEFAULT_WEBHOOK_CLEAN"
fi

echo ""
log_success "Webhook Data: $WEBHOOK_DATA"
log_success "Webhook Clean: $WEBHOOK_CLEAN"

# --- CONFIRMAÇÃO ---
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  📋 RESUMO DA CONFIGURAÇÃO                    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   ${PURPLE}Device:${NC}        $DEVICE_NAME"
echo -e "   ${PURPLE}Tunnel:${NC}        $TUNNEL_NAME"
echo -e "   ${PURPLE}URL:${NC}           https://${FULL_HOSTNAME}"
echo -e "   ${PURPLE}Webhook Data:${NC}  $WEBHOOK_DATA"
echo -e "   ${PURPLE}Webhook Clean:${NC} $WEBHOOK_CLEAN"
echo ""
read -p "   ➤ Confirmar e iniciar instalação? [Y/n]: " CONFIRM

if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    log_warn "Instalação cancelada pelo usuário."
    exit 0
fi

echo ""
echo -e "${GREEN}🚀 Iniciando instalação...${NC}"
echo ""

# ============================================================================
# PASSO 1: Verificar ROOT
# ============================================================================
log_info "Verificando acesso ROOT..."

if ! command -v su &> /dev/null; then
    log_error "ROOT não detectado! Este script requer um dispositivo com ROOT."
    exit 1
fi

if su -c "echo 'root_test'" &> /dev/null; then
    log_success "ROOT funcionando!"
else
    log_error "ROOT instalado mas sem permissão. Autorize o Termux no Magisk."
    exit 1
fi

# ============================================================================
# PASSO 2: Atualizar Termux
# ============================================================================
echo ""
log_info "Atualizando repositórios do Termux..."
pkg update -y && pkg upgrade -y
log_success "Repositórios atualizados!"

# Escolher mirror mais rápido
echo ""
log_info "Configurando mirror do Termux (escolha o mais próximo)..."
termux-change-repo || log_warn "termux-change-repo não disponível, continuando..."

# ============================================================================
# PASSO 3: Configurar Armazenamento
# ============================================================================
echo ""
log_info "Configurando acesso ao armazenamento..."

if [ ! -d "$HOME_DIR/storage" ]; then
    termux-setup-storage
    sleep 3
    log_success "Armazenamento configurado!"
else
    log_success "Armazenamento já configurado!"
fi

# ============================================================================
# PASSO 4: Instalar Dependências do Sistema
# ============================================================================
echo ""
log_info "Instalando dependências do sistema..."

# --- 4.1: Core do Sistema e Root ---
CORE_PACKAGES=(
    "bash"
    "coreutils"
    "util-linux"
    "procps"
    "psmisc"
    "which"
    "tsu"
    "android-tools"
    "termux-api"
    "termux-tools"
)

# --- 4.2: Utilitários ---
UTIL_PACKAGES=(
    "curl"
    "wget"
    "jq"
    "tmux"
    "findutils"
    "grep"
    "sed"
    "gawk"
    "zip"
    "unzip"
    "nano"
    "git"
)

# --- 4.3: Linguagens ---
LANG_PACKAGES=(
    "nodejs-lts"
    "python"
    "python-pip"
)

# --- 4.4: Mídia e OCR ---
MEDIA_PACKAGES=(
    "ffmpeg"
    "tesseract"
    "leptonica"
)

# --- 4.5: Cloudflare ---
CLOUD_PACKAGES=(
    "cloudflared"
)

# Junta todos os pacotes
ALL_PACKAGES=("${CORE_PACKAGES[@]}" "${UTIL_PACKAGES[@]}" "${LANG_PACKAGES[@]}" "${MEDIA_PACKAGES[@]}" "${CLOUD_PACKAGES[@]}")

for pkg in "${ALL_PACKAGES[@]}"; do
    if dpkg -s "$pkg" &> /dev/null; then
        log_success "$pkg já instalado"
    else
        log_info "Instalando $pkg..."
        pkg install -y "$pkg" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_success "$pkg instalado!"
        else
            log_warn "$pkg não encontrado no repositório (opcional)"
        fi
    fi
done

# --- 4.6: PM2 (via npm) ---
echo ""
log_info "Instalando PM2 (Process Manager via npm)..."
if command -v pm2 &> /dev/null; then
    log_success "PM2 já instalado!"
else
    npm install -g pm2
    log_success "PM2 instalado!"
fi

# --- 4.7: Tesseract PT-BR (tessdata_fast - compatível com x86_64) ---
log_info "Instalando dados do Tesseract (Português - versão fast)..."

# Remove versão antiga se existir (pode ser a versão pesada que causa crash)
rm -f "$PREFIX/share/tessdata/por.traineddata" 2>/dev/null

curl -L -o "$PREFIX/share/tessdata/por.traineddata" \
    https://github.com/tesseract-ocr/tessdata_fast/raw/main/por.traineddata 2>/dev/null

if [ -f "$PREFIX/share/tessdata/por.traineddata" ]; then
    log_success "Tesseract PT-BR (fast) baixado com sucesso!"
else
    log_warn "Falha ao baixar tessdata português. OCR pode não funcionar."
fi

# ============================================================================
# PASSO 5: Criar Diretório do Projeto
# ============================================================================
echo ""
log_info "Criando diretório do projeto..."

if [ -d "$INSTALL_DIR" ]; then
    log_warn "Diretório já existe. Fazendo backup..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
log_success "Diretório criado: $INSTALL_DIR"

# ============================================================================
# PASSO 6: Baixar Arquivos do Repositório
# ============================================================================
echo ""
log_info "Baixando arquivos do servidor..."

FILES=("server.js" "sentinela.js" "list_users.sh")

for file in "${FILES[@]}"; do
    log_info "Baixando $file..."
    curl -sSL "$REPO_URL/$file" -o "$INSTALL_DIR/$file"
    log_success "$file baixado!"
done

# Scripts Shell
SCRIPTS=(
    "abrir_conversa.sh"
    "enviar_midia.sh"
    "enviar_texto.sh"
    "fazer_ligacao.sh"
    "gravar_fake.sh"
    "pegar_numero.sh"
    "pix.sh"
    "rejeitacall.sh"
    "salvar_contato.sh"
)

log_info "Baixando scripts shell..."
for script in "${SCRIPTS[@]}"; do
    if curl -sSL "$REPO_URL/scripts/$script" -o "$INSTALL_DIR/$script" 2>/dev/null; then
        chmod +x "$INSTALL_DIR/$script"
        log_success "$script baixado!"
    else
        log_warn "$script não encontrado (opcional)"
    fi
done

# ============================================================================
# PASSO 7: Inicializar NPM
# ============================================================================
echo ""
log_info "Inicializando projeto Node.js..."

cd "$INSTALL_DIR"
npm init -y > /dev/null 2>&1
log_success "package.json criado!"

log_info "Instalando Express e Axios..."
npm install express axios --save
log_success "Dependências Node.js instaladas!"

# ============================================================================
# PASSO 8: Instalar PM2
# ============================================================================
echo ""
log_info "Instalando PM2 (Process Manager)..."

if command -v pm2 &> /dev/null; then
    log_success "PM2 já instalado!"
else
    npm install -g pm2
    log_success "PM2 instalado!"
fi

# Ativar wake-lock para manter Termux ativo
echo ""
log_info "Ativando wake-lock (mantém Termux ativo em background)..."
termux-wake-lock 2>/dev/null && log_success "Wake-lock ativado!" || log_warn "Wake-lock não disponível"

# ============================================================================
# PASSO 9: Criar arquivo de configuração
# ============================================================================
echo ""
log_info "Criando arquivo de configuração..."

cat > "$INSTALL_DIR/config.json" << EOF
{
    "webhooks": {
        "data": "$WEBHOOK_DATA",
        "clean": "$WEBHOOK_CLEAN"
    },
    "device": {
        "name": "$DEVICE_NAME",
        "whatsapp_pkg": "com.whatsapp.w4b"
    },
    "tunnel": {
        "name": "$TUNNEL_NAME",
        "hostname": "$FULL_HOSTNAME",
        "domain": "$DOMAIN"
    },
    "settings": {
        "port": 3000,
        "job_timeout": 180000,
        "max_retries": 2
    }
}
EOF

log_success "config.json criado!"

# ============================================================================
# PASSO 10: Configurar Cloudflare Tunnel
# ============================================================================

# IMPORTANTE: Desativa set -e nesta seção porque cloudflared pode crashar
# com "stack corruption" no Termux ARM, mas ainda assim funcionar
set +e

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              ☁️  CONFIGURAÇÃO DO CLOUDFLARE TUNNEL            ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar versão do cloudflared
CLOUDFLARED_VERSION=$(cloudflared version 2>/dev/null | head -1)
log_success "Cloudflared instalado: $CLOUDFLARED_VERSION"

# ========================================
# PASSO 10.1: LOGIN
# ========================================
if [ -f "$HOME_DIR/.cloudflared/cert.pem" ]; then
    log_success "Cloudflare já autenticado!"
else
    echo ""
    log_warn "Você precisa autenticar no Cloudflare."
    log_info "Um link será gerado. Abra no navegador e autorize."
    echo ""
    read -p "   ➤ Pressione ENTER para gerar o link de autenticação..."
    
    # Executa em subshell para não abortar se crashar
    (cloudflared tunnel login) || true
    sleep 2
    
    if [ -f "$HOME_DIR/.cloudflared/cert.pem" ]; then
        log_success "Autenticação concluída!"
    else
        log_error "Falha na autenticação. Execute manualmente: cloudflared tunnel login"
        log_error "Depois rode o setup novamente."
        exit 1
    fi
fi

# ========================================
# PASSO 10.2: CREATE TUNNEL (PARA AQUI)
# ========================================
echo ""
log_info "Criando tunnel: $TUNNEL_NAME..."

# Verificar se tunnel já existe
EXISTING_TUNNEL=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" || true)

if [ -n "$EXISTING_TUNNEL" ]; then
    log_warn "Tunnel '$TUNNEL_NAME' já existe!"
    TUNNEL_ID=$(echo "$EXISTING_TUNNEL" | awk '{print $1}')
    log_success "ID do Tunnel: $TUNNEL_ID"
else
    log_info "Executando: cloudflared tunnel create $TUNNEL_NAME"
    cloudflared tunnel create "$TUNNEL_NAME"
fi

# ============================================================================
# 🛑 PARADA AUTOMÁTICA - CONTINUAR MANUALMENTE
# ============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ INSTALAÇÃO AUTOMÁTICA CONCLUÍDA!                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📁 Diretório:${NC}       $INSTALL_DIR"
echo -e "${CYAN}📱 Device:${NC}          $DEVICE_NAME"
echo -e "${CYAN}☁️  Tunnel:${NC}          $TUNNEL_NAME"
echo -e "${CYAN}🌍 Hostname:${NC}        $FULL_HOSTNAME"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}   ⚠️  CONTINUE MANUALMENTE OS PASSOS ABAIXO:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${PURPLE}1. Anote o ID do tunnel que apareceu acima${NC}"
echo ""
echo -e "${PURPLE}2. Crie o config.yml (substitua TUNNEL_ID pelo ID real):${NC}"
echo ""
echo "   cat > ~/.cloudflared/config.yml << 'EOF'"
echo "   tunnel: TUNNEL_ID"
echo "   credentials-file: /data/data/com.termux/files/home/.cloudflared/TUNNEL_ID.json"
echo ""
echo "   ingress:"
echo "     - hostname: $FULL_HOSTNAME"
echo "       service: http://localhost:3000"
echo "     - service: http_status:404"
echo "   EOF"
echo ""
echo -e "${PURPLE}3. Configure o DNS:${NC}"
echo "   cloudflared tunnel route dns $TUNNEL_NAME $FULL_HOSTNAME"
echo ""
echo -e "${PURPLE}4. Teste o tunnel:${NC}"
echo "   cloudflared tunnel run $TUNNEL_NAME"
echo ""
echo -e "${PURPLE}5. Inicie os serviços com PM2:${NC}"
echo "   cd ~/zap-server"
echo "   pm2 start server.js --name server"
echo "   pm2 start sentinela.js --name sentinela"
echo "   pm2 start cloudflared --name tunnel -- tunnel run $TUNNEL_NAME"
echo "   pm2 save"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   ZAP SERVER v5.5 | Instalação parcial concluída${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
