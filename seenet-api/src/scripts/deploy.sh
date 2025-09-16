#!/bin/bash

echo "🚀 Iniciando deploy do SeeNet API..."

# Verificar se está na branch correta
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "production" ]; then
    echo "⚠️ Você não está na branch main/production. Continuar? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Executar testes
echo "🧪 Executando testes..."
npm test
if [ $? -ne 0 ]; then
    echo "❌ Testes falharam. Deploy cancelado."
    exit 1
fi

# Build da aplicação
echo "🔨 Fazendo build..."
npm run build 2>/dev/null || echo "ℹ️ Sem script de build configurado"

# Backup do banco (se existir)
if [ -f "database/seenet.sqlite" ]; then
    echo "💾 Fazendo backup do banco..."
    cp database/seenet.sqlite "database/backup-$(date +%Y%m%d-%H%M%S).sqlite"
fi

# Executar migrações
echo "🗄️ Executando migrações..."
npm run migrate

# Reiniciar serviços com PM2
if command -v pm2 &> /dev/null; then
    echo "🔄 Reiniciando com PM2..."
    pm2 restart seenet-api || pm2 start src/server.js --name seenet-api
else
    echo "⚠️ PM2 não encontrado. Inicie manualmente com: npm start"
fi

echo "✅ Deploy concluído!"
