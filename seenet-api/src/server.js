const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

console.log('🚀 Iniciando servidor SeeNet API...');

// ========== MIDDLEWARES GLOBAIS ==========
app.use(helmet());
app.use(compression());
app.use(morgan('combined'));

app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || [
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'http://10.0.2.2:3000',
    'http://10.50.160.140:3000', // ← SEU IP ATUAL
    'http://172.20.10.2:3000'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Tenant-Code']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ========== IMPORTAR E USAR ROTAS ==========
console.log('📁 Carregando rotas...');

// Rotas de Tenant
try {
  const tenantRoutes = require('./routes/tenant');
  app.use('/api/tenant', tenantRoutes);
  console.log('✅ Rotas tenant carregadas em /api/tenant');
} catch (error) {
  console.error('❌ Erro ao carregar rotas tenant:', error.message);
}

// Rotas de Autenticação ← ADICIONAR ESTAS LINHAS
try {
  const authRoutes = require('./routes/auth');
  app.use('/api/auth', authRoutes);
  console.log('✅ Rotas auth carregadas em /api/auth');
} catch (error) {
  console.error('❌ Erro ao carregar rotas auth:', error.message);
  console.error('📁 Verifique se existe: src/routes/auth.js');
}

// ========== ROTAS BÁSICAS ==========

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    message: 'SeeNet API está funcionando!'
  });
});

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    database: 'SQLite conectado',
    gemini: process.env.GEMINI_API_KEY ? 'Configurado' : 'Não configurado'
  });
});

// Rota de teste
app.get('/api/test', (req, res) => {
  res.json({
    message: 'API funcionando!',
    timestamp: new Date().toISOString(),
    ip: req.ip,
    headers: {
      'user-agent': req.get('User-Agent'),
      'origin': req.get('Origin')
    }
  });
});

// ========== ROTA DE DEBUG PARA BANCO ==========
app.get('/api/debug/database', async (req, res) => {
  try {
    const { db } = require('./config/database');
    
    // Verificar se tabela existe
    const hasTable = await db.schema.hasTable('tenants');
    
    if (!hasTable) {
      return res.json({
        error: 'Tabela tenants não existe',
        solution: 'Execute: npx knex migrate:latest'
      });
    }
    
    // Buscar todos
    const tenants = await db('tenants').select('*');
    
    res.json({
      message: 'Debug do banco SQLite',
      table_exists: hasTable,
      total_tenants: tenants.length,
      tenants: tenants
    });
    
  } catch (error) {
    console.error('❌ Erro no debug:', error);
    res.status(500).json({
      error: error.message
    });
  }
});

// ========== TESTE DIRETO DE LOGIN ==========
app.post('/api/test/login', async (req, res) => {
  try {
    const { db } = require('./config/database');
    const bcrypt = require('bcryptjs');
    
    console.log('🧪 Teste direto de login...');
    console.log('📄 Body recebido:', req.body);
    
    const { email, senha, codigoEmpresa } = req.body;
    
    // Buscar usuário
    const user = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .where('usuarios.email', email?.toLowerCase())
      .where('tenants.codigo', codigoEmpresa?.toUpperCase())
      .where('usuarios.ativo', 1)
      .where('tenants.ativo', 1)
      .select('usuarios.*', 'tenants.nome as tenant_name', 'tenants.codigo as tenant_code')
      .first();
    
    if (!user) {
      return res.json({
        teste: 'FALHOU',
        motivo: 'Usuário não encontrado',
        email_procurado: email?.toLowerCase(),
        codigo_procurado: codigoEmpresa?.toUpperCase()
      });
    }
    
    // Verificar senha
    const senhaValida = await bcrypt.compare(senha, user.senha);
    
    res.json({
      teste: senhaValida ? 'SUCESSO' : 'FALHOU',
      motivo: senhaValida ? 'Login válido' : 'Senha incorreta',
      usuario_encontrado: {
        nome: user.nome,
        email: user.email,
        tipo: user.tipo_usuario,
        tenant: user.tenant_name
      }
    });
    
  } catch (error) {
    console.error('❌ Erro no teste de login:', error);
    res.status(500).json({ 
      teste: 'ERRO',
      erro: error.message 
    });
  }
});

// 404 handler
app.use('*', (req, res) => {
  const availableEndpoints = [
    'GET /health',
    'GET /api/health', 
    'GET /api/test',
    'POST /api/test/login',
    'GET /api/tenant/verify/:codigo',
    'GET /api/tenant/list',
    'POST /api/auth/login',
    'POST /api/auth/register',
    'GET /api/auth/verify',
    'POST /api/auth/logout',
    'GET /api/debug/database'
  ];
  
  console.log(`404 - Endpoint não encontrado: ${req.method} ${req.originalUrl}`);
  
  res.status(404).json({ 
    error: 'Endpoint não encontrado',
    path: req.originalUrl,
    method: req.method,
    availableEndpoints
  });
});

// ========== DEBUG - LISTAR USUÁRIOS ==========
app.get('/api/debug/usuarios', async (req, res) => {
  try {
    const { db } = require('./config/database');
    
    const usuarios = await db('usuarios')
      .join('tenants', 'usuarios.tenant_id', 'tenants.id')
      .select(
        'usuarios.id',
        'usuarios.nome',
        'usuarios.email',
        'usuarios.tipo_usuario',
        'usuarios.ativo',
        'usuarios.data_criacao',
        'tenants.nome as empresa',
        'tenants.codigo as codigo_empresa'
      )
      .orderBy('usuarios.data_criacao', 'desc');
    
    res.json({
      message: 'Usuários na API Node.js',
      total: usuarios.length,
      usuarios: usuarios
    });
  } catch (error) {
    console.error('❌ Erro ao listar usuários:', error);
    res.status(500).json({ error: error.message });
  }
});

// ========== DEBUG - ATUALIZAR TIPO DE USUÁRIO ==========
app.post('/api/debug/update-user-type', async (req, res) => {
  try {
    const { email, tipo } = req.body;
    const { db } = require('./config/database');
    
    await db('usuarios')
      .where('email', email.toLowerCase())
      .update({ 
        tipo_usuario: tipo,
        data_atualizacao: new Date().toISOString()
      });
    
    const user = await db('usuarios')
      .where('email', email.toLowerCase())
      .first();
    
    res.json({ 
      message: 'Usuário atualizado na API',
      user: {
        email: user.email,
        nome: user.nome,
        tipo_usuario: user.tipo_usuario
      }
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Error handler
app.use((error, req, res, next) => {
  console.error('❌ Erro na aplicação:', error);
  
  res.status(500).json({
    error: 'Erro interno do servidor',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Algo deu errado'
  });
});

// ========== INICIALIZAÇÃO ==========
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 SeeNet API rodando em todas as interfaces na porta ${PORT}`);
  console.log(`📝 Health check: http://10.50.160.140:${PORT}/health`);
  console.log(`🧪 Teste: http://10.50.160.140:${PORT}/api/test`);
  console.log(`🏢 Verificar empresa: http://10.50.160.140:${PORT}/api/tenant/verify/DEMO2024`);
  console.log(`📊 Listar empresas: http://10.50.160.140:${PORT}/api/tenant/list`);
  console.log(`🔐 Login: http://10.50.160.140:${PORT}/api/auth/login`);
  console.log(`📝 Registro: http://10.50.160.140:${PORT}/api/auth/register`);
  console.log(`🗄️ Debug banco: http://10.50.160.140:${PORT}/api/debug/database`);
  console.log(`🔑 Gemini: ${process.env.GEMINI_API_KEY ? 'Configurado' : 'NÃO CONFIGURADO'}`);
  console.log(`🌐 IP atual: 10.50.160.140`);
});