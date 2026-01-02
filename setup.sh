#!/data/data/com.termux/files/usr/bin/bash

# ============================================================================
# 🚀 ZAP SERVER - INSTALADOR AUTOMÁTICO
# ============================================================================
# Uso: bash <(curl -sSL https://raw.githubusercontent.com/SEU_USUARIO/zap-server/main/setup.sh)
# ============================================================================

set -e  # Para em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
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
echo "║              🤖 INSTALADOR AUTOMÁTICO v1.0                    ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Variáveis
REPO_URL="https://raw.githubusercontent.com/jonemp31/zap-server/main"
HOME_DIR="/data/data/com.termux/files/home"
INSTALL_DIR="$HOME_DIR/zap-server"

# Funções
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ============================================================================
# PASSO 1: Verificar ROOT
# ============================================================================
echo ""
log_info "Verificando acesso ROOT..."

if ! command -v su &> /dev/null; then
    log_error "ROOT não detectado! Este script requer um dispositivo com ROOT."
    log_warn "Instale Magisk ou outro gerenciador de ROOT e tente novamente."
    exit 1
fi

# Testa se ROOT funciona
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

PACKAGES=(
    "tsu"
    "coreutils"
    "findutils"
    "grep"
    "sed"
    "gawk"
    "curl"
    "jq"
    "android-tools"
    "termux-api"
    "nodejs-lts"
    "python"
    "ffmpeg"
    "tesseract"
)

for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" &> /dev/null; then
        log_success "$pkg já instalado"
    else
        log_info "Instalando $pkg..."
        pkg install -y "$pkg"
        log_success "$pkg instalado!"
    fi
done

# Tesseract PT-BR (pacote separado)
log_info "Instalando dados do Tesseract (Português)..."
pkg install -y tesseract-data-por 2>/dev/null || log_warn "tesseract-data-por pode já estar instalado"
log_success "Tesseract PT-BR OK!"

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

# Arquivos principais
FILES=(
    "server.js"
    "sentinela.js"
)

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
    "enviar_texto2.sh"
    "enviar_texto3.sh"
    "fazer_ligacao.sh"
    "gravar_fake.sh"
    "pegar_numero.sh"
    "pix.sh"
    "rejeitacall.sh"
    "salvar_contato.sh"
    "voltar.sh"
    "buscar_lead.sh"
    "calibrar.sh"
    "autoclique.sh"
    "chat.sh"
)

log_info "Baixando scripts shell..."
for script in "${SCRIPTS[@]}"; do
    if curl -sSL "$REPO_URL/scripts/$script" -o "$INSTALL_DIR/$script" 2>/dev/null; then
        chmod +x "$INSTALL_DIR/$script"
        log_success "$script baixado!"
    else
        log_warn "$script não encontrado no repositório (opcional)"
    fi
done

# ============================================================================
# PASSO 7: Inicializar NPM e Instalar Dependências Node
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
# PASSO 8: Instalar PM2 Globalmente
# ============================================================================
echo ""
log_info "Instalando PM2 (Process Manager)..."

if command -v pm2 &> /dev/null; then
    log_success "PM2 já instalado!"
else
    npm install -g pm2
    log_success "PM2 instalado!"
fi

# ============================================================================
# PASSO 9: Configurar PM2 para Iniciar com Termux
# ============================================================================
echo ""
log_info "Configurando PM2 startup..."

# Criar script de inicialização do Termux
BOOT_SCRIPT="$HOME_DIR/.termux/boot/start-zap-server.sh"
mkdir -p "$HOME_DIR/.termux/boot"

cat > "$BOOT_SCRIPT" << 'BOOTEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Auto-start ZAP Server on Termux boot
sleep 10  # Aguarda sistema estabilizar
cd /data/data/com.termux/files/home/zap-server
pm2 resurrect
BOOTEOF

chmod +x "$BOOT_SCRIPT"
log_success "Script de boot criado!"

# ============================================================================
# PASSO 10: Criar arquivo de configuração
# ============================================================================
echo ""
log_info "Criando arquivo de configuração..."

cat > "$INSTALL_DIR/config.json" << 'CONFIGEOF'
{
    "webhooks": {
        "data": "https://webhook-dev.zapsafe.work/webhook/whatsapp4mumu",
        "clean": "https://webhook-dev.zapsafe.work/webhook/limparnotificacaozapmu"
    },
    "device": {
        "name": "meu-dispositivo",
        "whatsapp_pkg": "com.whatsapp.w4b"
    },
    "settings": {
        "port": 3000,
        "job_timeout": 180000,
        "max_retries": 2
    }
}
CONFIGEOF

log_success "config.json criado!"

# ============================================================================
# PASSO 11: Iniciar Serviços com PM2
# ============================================================================
echo ""
log_info "Iniciando serviços com PM2..."

cd "$INSTALL_DIR"

# Para processos anteriores se existirem
pm2 delete all 2>/dev/null || true

# Inicia server.js
pm2 start server.js --name "zap-server" --time

# Inicia sentinela.js
pm2 start sentinela.js --name "sentinela" --time

# Salva configuração para resurrect
pm2 save

log_success "Serviços iniciados!"

# ============================================================================
# PASSO 12: Verificação Final
# ============================================================================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    🔍 VERIFICAÇÃO FINAL                       ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar dependências
echo -e "${YELLOW}Dependências:${NC}"
node -v && echo -e "  ${GREEN}✓${NC} Node.js OK"
python3 --version 2>/dev/null && echo -e "  ${GREEN}✓${NC} Python OK"
ffmpeg -version 2>/dev/null | head -1 && echo -e "  ${GREEN}✓${NC} FFmpeg OK"
tesseract --version 2>&1 | head -1 && echo -e "  ${GREEN}✓${NC} Tesseract OK"

echo ""
echo -e "${YELLOW}Serviços PM2:${NC}"
pm2 list

echo ""
echo -e "${YELLOW}Teste de conexão:${NC}"
sleep 2
if curl -s http://localhost:3000/health | jq . 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} API respondendo!"
else
    echo -e "  ${YELLOW}!${NC} API ainda inicializando... aguarde alguns segundos"
fi

# ============================================================================
# INSTRUÇÕES FINAIS
# ============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📁 Diretório de instalação:${NC} $INSTALL_DIR"
echo -e "${CYAN}🌐 API disponível em:${NC} http://localhost:3000"
echo ""
echo -e "${YELLOW}📝 PRÓXIMOS PASSOS:${NC}"
echo ""
echo "   1. Edite o arquivo de configuração:"
echo -e "      ${PURPLE}nano $INSTALL_DIR/config.json${NC}"
echo ""
echo "   2. Edite os webhooks no sentinela.js:"
echo -e "      ${PURPLE}nano $INSTALL_DIR/sentinela.js${NC}"
echo ""
echo "   3. Exponha a API via Cloudflare Tunnel:"
echo -e "      ${PURPLE}cloudflared tunnel --url http://localhost:3000${NC}"
echo ""
echo -e "${YELLOW}🔧 COMANDOS ÚTEIS:${NC}"
echo ""
echo "   pm2 status          # Ver status dos serviços"
echo "   pm2 logs            # Ver logs em tempo real"
echo "   pm2 restart all     # Reiniciar serviços"
echo "   pm2 stop all        # Parar serviços"
echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   Desenvolvido com ❤️  | ZAP SERVER v5.4${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
