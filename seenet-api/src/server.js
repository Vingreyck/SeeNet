const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
require('dotenv').config();

const tenantRoutes = require('./routes/tenant')
const app = express();
const PORT = process.env.PORT || 3000;

// ========== MIDDLEWARES GLOBAIS ==========
app.use(helmet()); 
app.use(compression()); 
app.use(morgan('combined')); 

// CORS configurado para Flutter
app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || [
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'http://10.0.2.2:3000',
    'http://172.20.10.2:3000',
    'http://172.20.10.1:3000'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Tenant-Code']
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

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


app.get('/api/debug/tenants', async (req, res) => {
  try {
    const { db } = require('./config/database');
    const tenants = await db('tenants').select('*');
    
    res.json({
      message: 'Debug - Todos os tenants',
      tenants: tenants,
      total: tenants.length
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});


// Rota de teste
app.get('/api/test', (req, res) => {
  res.json({
    message: 'API funcionando!',
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    query: req.query,
    headers: {
      'content-type': req.get('content-type'),
      'user-agent': req.get('user-agent'),
      'authorization': req.get('authorization') ? 'Present' : 'Not present',
      'x-tenant-code': req.get('x-tenant-code') || 'Not present'
    }
  });
});

// Rota de teste POST
app.post('/api/test', (req, res) => {
  res.json({
    message: 'POST funcionando!',
    timestamp: new Date().toISOString(),
    body: req.body,
    headers: {
      'content-type': req.get('content-type'),
      'authorization': req.get('authorization') ? 'Present' : 'Not present',
      'x-tenant-code': req.get('x-tenant-code') || 'Not present'
    }
  });
});

// Rota de debug temporária
app.get('/api/debug/database', async (req, res) => {
  try {
    const { db } = require('./config/database');
    
    const tenants = await db('tenants').select('*');
    
    res.json({
      message: 'Debug do banco',
      total: tenants.length,
      tenants: tenants
    });
    
  } catch (error) {
    res.status(500).json({
      error: error.message
    });
  }
});

// 404 handler
app.use('*', (req, res) => {
  const availableEndpoints = [
    'GET /health',
    'GET /api/health', 
    'GET /api/test',
    'GET /api/tenant/verify/:codigo',
    'GET /api/tenant/list',
    'GET /api/debug/tenants',
    'POST /api/test'
  ];
  
  res.status(404).json({ 
    error: 'Endpoint não encontrado',
    path: req.originalUrl,
    method: req.method,
    availableEndpoints
  });
});

// Error handler básico
app.use((error, req, res, next) => {
  console.error('❌ Erro na aplicação:', error);
  
  res.status(500).json({
    error: 'Erro interno do servidor',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Algo deu errado',
    stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
  });
});

// ========== INICIALIZAÇÃO ==========
app.listen(PORT, '0.0.0.0', () => {
  console.log('\n🚀 ===================================');
  console.log('🚀 SeeNet API INICIADO COM SUCESSO!');
  console.log('🚀 ===================================');
  console.log(`📡 Porta: ${PORT}`);
  console.log(`🏠 Ambiente: ${process.env.NODE_ENV || 'development'}`);
  console.log(`📝 Health check: http://172.20.10.2:${PORT}/health`);
  console.log(`🧪 Teste GET: http://172.20.10.2:${PORT}/api/test`);
  console.log(`🏢 Verificar empresa: http://172.20.10.2:${PORT}/api/tenant/verify/DEMO2024`);
  console.log(`📊 Debug tenants: http://172.20.10.2:${PORT}/api/debug/tenants`);
  console.log(`🔑 Gemini API: ${process.env.GEMINI_API_KEY ? '✅ CONFIGURADO' : '❌ NÃO CONFIGURADO'}`);
  console.log(`🌐 CORS: ${process.env.CORS_ORIGINS || 'localhost padrão'}`);
  console.log('🚀 ===================================\n');
  
  // Teste inicial
  console.log('🧪 Executando teste inicial...');
  
  // Verificar .env
  if (process.env.GEMINI_API_KEY) {
    console.log('✅ Arquivo .env carregado corretamente');
    console.log(`✅ Gemini API Key: ${process.env.GEMINI_API_KEY.substring(0, 10)}...`);
  } else {
    console.log('⚠️ GEMINI_API_KEY não encontrada no .env');
  }
  
  console.log('\n🎯 Pronto para receber requisições do Flutter!\n');
});

// Tratamento graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM recebido. Fechando servidor...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT recebido. Fechando servidor...');
  process.exit(0);
});