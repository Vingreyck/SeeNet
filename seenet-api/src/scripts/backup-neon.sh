#!/bin/bash

# Carregar variáveis
source .env

# Nome do arquivo com timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backups/neon_backup_${TIMESTAMP}.sql"

# Criar diretório se não existir
mkdir -p backups

# Fazer backup
echo "Criando backup do Neon..."
pg_dump "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require" > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "✅ Backup criado: $BACKUP_FILE"
    ls -lh $BACKUP_FILE
else
    echo "❌ Falha no backup"
    exit 1
fi