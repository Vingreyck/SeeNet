#!/bin/bash

echo "🚀 Configurando SeeNet API..."

# Verificar se Node.js está instalado
if ! command -v node &> /dev/null; then
    echo "❌ Node.js não encontrado. Instale Node.js 18+ primeiro."
    exit 1
fi

# Verificar versão do Node
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js 18+ é necessário. Versão atual: $(node -v)"
    exit 1
fi

# Criar diretórios necessários
echo "📁 Criando diretórios..."
mkdir -p database logs ssl

# Instalar dependências
echo "📦 Instalando dependências..."
npm install

# Copiar arquivo de configuração
if [ ! -f .env ]; then
    echo "⚙️ Criando arquivo .env..."
    cp .env.example .env
    echo "📝 Configure suas chaves em .env antes de continuar"
fi

# Executar migrações
echo "🗄️ Executando migrações do banco..."
npm run migrate

# Executar seeds (apenas em desenvolvimento)
if [ "$NODE_ENV" != "production" ]; then
    echo "🌱 Executando seeds..."
    npm run seed
fi

echo "✅ Configuração concluída!"
echo ""
echo "📋 Próximos passos:"
echo "1. Configure suas chaves em .env"
echo "2. Execute: npm run dev"
echo "3. Acesse: http://localhost:3000/health"
echo ""
echo "🔑 Códigos de empresa para teste:"
echo "• DEMO2024 (Plano Profissional)"
echo "• TECH2024 (Plano Empresarial)"
echo ""
echo "👤 Usuários de teste:"
echo "• admin@demo.seenet.com / admin123"
echo "• tecnico@demo.seenet.com / 123456"