#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# UPDATE.SH — Atualiza scripts do GitHub
# ============================================================================

REPO_URL="https://raw.githubusercontent.com/jonemp31/zap-server/main"
INSTALL_DIR="$HOME/zap-server"

cd "$INSTALL_DIR" || { echo "❌ Diretório não encontrado: $INSTALL_DIR"; exit 1; }

echo "📥 Baixando atualizações do GitHub..."

# Arquivos principais
curl -sSL "$REPO_URL/server.js" -o server.js && echo "✅ server.js"
curl -sSL "$REPO_URL/sentinela.js" -o sentinela.js && echo "✅ sentinela.js"
curl -sSL "$REPO_URL/list_users.sh" -o list_users.sh && chmod +x list_users.sh && echo "✅ list_users.sh"

# Scripts de ação
SCRIPTS=(
    "abrir_conversa.sh"
    "enviar_midia.sh"
    "enviar_texto.sh"
    "fazer_ligacao.sh"
    "gravar_fake.sh"
    "intent_audio.sh"
    "pegar_numero.sh"
    "pix.sh"
    "rejeitacall.sh"
    "salvar_contato.sh"
)

for script in "${SCRIPTS[@]}"; do
    if curl -sSL "$REPO_URL/scripts/$script" -o "$script" 2>/dev/null; then
        chmod +x "$script"
        echo "✅ $script"
    else
        echo "⚠️ $script não encontrado"
    fi
done

echo ""
echo "🔄 Reiniciando serviços..."
pm2 restart server sentinela 2>/dev/null || pm2 restart all

echo ""
echo "✅ Atualização concluída!"
pm2 list
