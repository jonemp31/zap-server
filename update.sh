#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# UPDATE.SH — Atualiza scripts do GitHub
# ============================================================================

REPO_URL="https://raw.githubusercontent.com/jonemp31/zap-server/main"
INSTALL_DIR="$HOME/zap-server"

cd "$INSTALL_DIR" || { echo "❌ Diretório não encontrado: $INSTALL_DIR"; exit 1; }

# ============================================================================
# AUTO-ATUALIZAÇÃO DO PRÓPRIO UPDATE.SH
# ============================================================================
echo "🔍 Verificando atualizações do update.sh..."

# Baixa versão remota para comparar
TEMP_UPDATE="/tmp/update_check_$$.sh"
if curl -fsSL "$REPO_URL/update.sh" -o "$TEMP_UPDATE" 2>/dev/null; then
    # Compara com a versão atual
    if ! cmp -s "update.sh" "$TEMP_UPDATE" 2>/dev/null; then
        echo ""
        echo "⚠️  Nova versão do update.sh disponível!"
        echo ""
        read -p "📦 Deseja atualizar o update.sh agora? [Y/n]: " CONFIRM_UPDATE
        
        if [[ ! "$CONFIRM_UPDATE" =~ ^[Nn]$ ]]; then
            echo "📥 Atualizando update.sh..."
            cp "$TEMP_UPDATE" "update.sh"
            chmod +x "update.sh"
            rm -f "$TEMP_UPDATE"
            echo "✅ update.sh atualizado com sucesso!"
            echo ""
            echo "🔄 Reiniciando com a nova versão..."
            echo ""
            sleep 1
            exec bash "update.sh" "$@"
            exit 0
        else
            echo "⏭️  Pulando atualização do update.sh"
        fi
    else
        echo "✅ update.sh já está atualizado"
    fi
    rm -f "$TEMP_UPDATE"
else
    echo "⚠️ Não foi possível verificar atualizações do update.sh"
fi

echo ""
echo "📥 Baixando atualizações dos outros arquivos..."

# Arquivos principais
curl -fsSL "$REPO_URL/server.js" -o server.js && echo "✅ server.js" || echo "❌ server.js FALHOU"
curl -fsSL "$REPO_URL/sentinela.js" -o sentinela.js && echo "✅ sentinela.js" || echo "❌ sentinela.js FALHOU"
curl -fsSL "$REPO_URL/statuszaps.js" -o statuszaps.js && echo "✅ statuszaps.js" || echo "❌ statuszaps.js FALHOU"
curl -fsSL "$REPO_URL/list_users.sh" -o list_users.sh && chmod +x list_users.sh && echo "✅ list_users.sh" || echo "❌ list_users.sh FALHOU"

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
    if curl -fsSL "$REPO_URL/$script" -o "$script"; then
        chmod +x "$script"
        echo "✅ $script"
    else
        echo "❌ $script FALHOU (404 ou erro de conexão)"
    fi
done

echo ""
echo "🔄 Reiniciando serviços..."
pm2 restart server sentinela statuszaps 2>/dev/null || pm2 restart all

echo ""
echo "✅ Atualização concluída!"
pm2 list
