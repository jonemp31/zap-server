# 🚀 ZAP SERVER v5.4

API de automação para WhatsApp Business rodando em Android (Termux + ROOT).

## ⚡ Instalação Rápida

```bash
bash <(curl -sSL https://raw.githubusercontent.com/jonemp31/zap-server/main/setup.sh)
```

## 📋 Requisitos

- Android com ROOT (Magisk)
- Termux instalado
- WhatsApp Business (`com.whatsapp.w4b`)

## 🏗️ O que o instalador faz

1. ✅ Verifica acesso ROOT
2. ✅ Instala todas as dependências (Node.js, Python, FFmpeg, Tesseract, etc)
3. ✅ Baixa server.js, sentinela.js e todos os scripts
4. ✅ Configura PM2 para rodar em background
5. ✅ Inicia os serviços automaticamente

## 📡 Endpoints da API

| Rota | Método | Descrição |
|------|--------|-----------|
| `/health` | GET | Status do servidor |
| `/state` | GET | Estado atual (busy/fila) |
| `/:userId/texto` | POST | Envia mensagem de texto |
| `/:userId/midia` | POST | Envia foto/vídeo |
| `/:userId/audio` | POST | Envia áudio |
| `/:userId/ligar` | POST | Faz ligação |
| `/:userId/pix` | POST | Envia pedido PIX |
| `/:userId/salvarcontato` | POST | Salva contato |
| `/:userId/rejeitarcall` | POST | Rejeita chamada |

## 🔧 Comandos Úteis

```bash
pm2 status          # Ver status dos serviços
pm2 logs            # Ver logs em tempo real
pm2 restart all     # Reiniciar serviços
pm2 stop all        # Parar serviços
```

## 📁 Estrutura

```
zap-server/
├── setup.sh           # Instalador automático
├── server.js          # API Express (porta 3000)
├── sentinela.js       # Monitor de notificações
└── scripts/
    ├── abrir_conversa.sh
    ├── enviar_midia.sh
    ├── enviar_texto.sh
    ├── fazer_ligacao.sh
    ├── gravar_fake.sh
    ├── pegar_numero.sh
    ├── pix.sh
    ├── rejeitacall.sh
    └── salvar_contato.sh
```

## 🌐 Expor na Internet

Use Cloudflare Tunnel para expor a API:

```bash
cloudflared tunnel --url http://localhost:3000
```

---

Desenvolvido com ❤️
