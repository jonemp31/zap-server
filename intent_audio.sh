#!/data/data/com.termux/files/usr/bin/bash
# ==========================================================
# intent_audio.sh - V2.0 ANTI-FINGERPRINT
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

# ==========================================================
# 🧬 PASSO 1: PROCESSAMENTO ANTI-FINGERPRINT
# ==========================================================
BASE_PATH="/storage/emulated/0/Download"
ARQUIVO_ORIGINAL="$BASE_PATH/$NOME_ARQUIVO"

# Valida se o arquivo existe
if [ ! -f "$ARQUIVO_ORIGINAL" ]; then
    echo "❌ Erro: Arquivo não encontrado: $ARQUIVO_ORIGINAL"
    exit 1
fi

echo "🧬 Processando áudio com fingerprint..."

# Gera nome único
RAND_NUM=$(shuf -i 100-999 -n1)
NOME_SEM_EXT="${NOME_ARQUIVO%.*}"
NOME_MODIFICADO="AUD${RAND_NUM}s-${NOME_SEM_EXT}.opus"
ARQUIVO_MODIFICADO="$BASE_PATH/$NOME_MODIFICADO"

echo "📝 Arquivo modificado: $NOME_MODIFICADO"

# Bitrate aleatório
BITRATE=$(shuf -i 24000-26000 -n1)

# Processa com FFmpeg (mesma lógica do gravar_fake.sh)
if ! ffmpeg -y -loglevel error -i "$ARQUIVO_ORIGINAL" \
    -af "aresample=48000" \
    -map_metadata -1 \
    -c:a libopus -b:a ${BITRATE} -ar 48000 \
    -vbr on -application voip "$ARQUIVO_MODIFICADO"; then
    echo "❌ Erro: Falha ao processar áudio"
    exit 1
fi

# Garante permissão de leitura para todos os usuários
chmod 644 "$ARQUIVO_MODIFICADO"

echo "✅ Fingerprint aplicada (Bitrate: ${BITRATE})"

# ==========================================================
# 🔧 PASSO 2: PREPARAÇÃO PARA ENVIO (SEM ALTERAÇÕES)
# ==========================================================

# ✅ CORREÇÃO: Escape o '-' ou coloque no final
# Remove apenas: espaços, +, -, @ (SEM afetar números)
LEAD_CLEAN=$(echo "$LEAD" | tr -d ' +@-')

echo "📱 LEAD original: [$LEAD]"
echo "📱 LEAD limpo: [$LEAD_CLEAN]"

# Valida se o lead ficou vazio após limpeza
if [ -z "$LEAD_CLEAN" ]; then
    echo "❌ Erro: LEAD vazio após limpeza"
    rm -f "$ARQUIVO_MODIFICADO"  # Limpa arquivo antes de sair
    exit 1
fi

# Monta os caminhos (AGORA USA O ARQUIVO MODIFICADO)
CAMINHO_ARQUIVO="file:///storage/emulated/$USER_ID/Download/$NOME_MODIFICADO"
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

# ==========================================================
# 📤 PASSO 3: EXECUÇÃO DO INTENT (100% INTOCADO)
# ==========================================================

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
    rm -f "$ARQUIVO_MODIFICADO"  # Limpa arquivo antes de sair
    exit 1
fi

# Verifica se o WhatsApp abriu
sleep 1

echo "👆 Clicando em Enviar (811 1031)..."
input tap 811 1031

sleep 0.5

echo "🔙 Clicando em Voltar (63 103)..."
input tap 63 103

# ==========================================================
# 🗑️ PASSO 4: LIMPEZA
# ==========================================================
echo ""
echo "⏳ Aguardando 1s antes de limpar..."
sleep 1

echo "🗑️ Removendo arquivo modificado..."
rm -f "$ARQUIVO_MODIFICADO"

if [ ! -f "$ARQUIVO_MODIFICADO" ]; then
    echo "✅ Arquivo limpo com sucesso"
else
    echo "⚠️ Arquivo ainda existe (talvez em uso)"
fi

echo ""
echo "✅ PROCESSO FINALIZADO COM SUCESSO"
exit 0
