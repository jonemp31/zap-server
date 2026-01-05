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
TEMP_UPDATE="$HOME/.update_check_$$.sh"
if curl -fsSL "$REPO_URL/update.sh" -o "$TEMP_UPDATE"; then
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
    rm -f "$TEMP_UPDATE" 2>/dev/null
else
    echo "⚠️ Não foi possível verificar atualizações do update.sh (verifique sua conexão)"
    rm -f "$TEMP_UPDATE" 2>/dev/null
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
echo "🔄 Verificando e iniciando serviços..."

# Verifica e inicia cada serviço se não estiver rodando
pm2 describe server > /dev/null 2>&1 || pm2 start server.js --name server
pm2 describe sentinela > /dev/null 2>&1 || pm2 start sentinela.js --name sentinela
pm2 describe statuszaps > /dev/null 2>&1 || pm2 start statuszaps.js --name statuszaps

# Depois reinicia todos para aplicar atualizações
echo "🔄 Reiniciando serviços..."
pm2 restart server sentinela statuszaps 2>/dev/null || pm2 restart all

echo ""
echo "🧹 Limpando logs antigos (mantendo últimos 100KB)..."
# Limpa logs grandes mas mantém as últimas linhas
for log in ~/.pm2/logs/*.log; do
    if [ -f "$log" ] && [ $(stat -c%s "$log" 2>/dev/null || stat -f%z "$log" 2>/dev/null) -gt 100000 ]; then
        tail -n 1000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
        echo "   ✅ Limpo: $(basename $log)"
    fi
done

echo ""
echo "✅ Atualização concluída!"
pm2 list
