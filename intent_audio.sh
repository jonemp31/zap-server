#!/data/data/com.termux/files/usr/bin/bash
# ==========================================================
# gravar_fake.sh - CORRIGIDO (tr -d FIXED)
# ==========================================================

USER_ID="$1"
NOME_ARQUIVO="$2"
TEMPO="$3"
LEAD="$4"

echo "🔍 DEBUG ARGUMENTOS RECEBIDOS:"
echo "  \$1 USER_ID: [$USER_ID]"
echo "  \$2 NOME_ARQUIVO: [$NOME_ARQUIVO]"
echo "  \$3 TEMPO: [$TEMPO]"
echo "  \$4 LEAD: [$LEAD]"
echo ""

# Validação
if [ -z "$USER_ID" ] || [ -z "$NOME_ARQUIVO" ] || [ -z "$LEAD" ]; then
    echo "❌ Erro: Argumentos obrigatórios faltando"
    echo "Uso: $0 USER_ID NOME_ARQUIVO TEMPO LEAD"
    exit 1
fi

# ✅ CORREÇÃO: Escape o '-' ou coloque no final
# Remove apenas: espaços, +, -, @ (SEM afetar números)
LEAD_CLEAN=$(echo "$LEAD" | tr -d ' +@-')

echo "📱 LEAD original: [$LEAD]"
echo "📱 LEAD limpo: [$LEAD_CLEAN]"

# Valida se o lead ficou vazio após limpeza
if [ -z "$LEAD_CLEAN" ]; then
    echo "❌ Erro: LEAD vazio após limpeza"
    exit 1
fi

# Monta os caminhos
CAMINHO_ARQUIVO="file:///storage/emulated/$USER_ID/Download/$NOME_ARQUIVO"
PKG_WHATSAPP="com.whatsapp.w4b"
JID="${LEAD_CLEAN}@s.whatsapp.net"

echo ""
echo "🚀 CONFIGURAÇÃO FINAL:"
echo "  📂 Arquivo: $CAMINHO_ARQUIVO"
echo "  📧 JID: $JID"
echo "  📦 Package: $PKG_WHATSAPP"
echo ""

# Monta o comando
CMD="am start --user $USER_ID -a android.intent.action.SEND -t 'audio/*' --eu android.intent.extra.STREAM '$CAMINHO_ARQUIVO' --es jid '$JID' -f 0x10000000 $PKG_WHATSAPP"

echo "⚙️ COMANDO A EXECUTAR:"
echo "$CMD"
echo ""

# Executa o comando e captura a saída
echo "🔧 Executando intent..."
RESULTADO=$(su -c "$CMD" 2>&1)
EXIT_CODE=$?

echo "📤 RESULTADO DO INTENT:"
echo "$RESULTADO"
echo "🔢 Exit Code: $EXIT_CODE"
echo ""

# Verifica se houve erro
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ ERRO: Intent falhou com exit code $EXIT_CODE"
    exit 1
fi

# Verifica se o WhatsApp abriu
sleep 1

echo "👆 Clicando em Enviar (811 1031)..."
input tap 811 1031

sleep 0.5

echo "🔙 Clicando em Voltar (63 103)..."
input tap 63 103

echo ""
echo "✅ PROCESSO FINALIZADO COM SUCESSO"
exit 0
