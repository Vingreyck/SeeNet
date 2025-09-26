const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

console.log('🚀 Iniciando servidor SeeNet API...');

// ========== MIDDLEWARES GLOBAIS ==========
app.use(helmet());
app.use(compression()); 
app.use(morgan('combined'));

app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'http://10.0.2.2:3000',
    'http://10.0.0.6:3000',
    'http://10.0.1.112:3000'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Tenant-Code']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ========== ROTAS BÁSICAS (antes da inicialização do banco) ==========
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    message: 'SeeNet API está funcionando!'
  });
});

app.get('/api/test', (req, res) => {
  res.json({
    message: 'API funcionando!',
    timestamp: new Date().toISOString(),
    ip: req.ip
  });
});

// ========== INICIALIZAR BANCO E ROTAS ==========
async function startServer() {
  try {
    console.log('🔌 Inicializando banco de dados...');
    
    // 1. Primeiro inicializar o banco
    const { initDatabase } = require('./config/database');
    await initDatabase();
    
    console.log('📁 Carregando rotas...');
    
    // 2. Agora carregar as rotas que usam banco
    try {
      const tenantRoutes = require('./routes/tenant');
      app.use('/api/tenant', tenantRoutes);
      console.log('✅ Rotas tenant carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas tenant:', error.message);
    }
    
    try {
      const authRoutes = require('./routes/auth');
      app.use('/api/auth', authRoutes);
      console.log('✅ Rotas auth carregadas');
    } catch (error) {
      console.error('⚠️ Rotas auth não encontradas (normal se não existir)');
    }
    
    // ========== ROTAS QUE USAM BANCO ==========
    
    app.get('/api/health', (req, res) => {
      res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        database: 'PostgreSQL conectado',
        gemini: process.env.GEMINI_API_KEY ? 'Configurado' : 'Não configurado'
      });
    });

    app.get('/api/debug/database', async (req, res) => {
      try {
        const { db } = require('./config/database');
        const tenants = await db('tenants').select('*').limit(5);
        
        res.json({
          message: 'Debug do banco PostgreSQL',
          total_tenants: tenants.length,
          tenants: tenants,
          connection: 'PostgreSQL OK'
        });
        
      } catch (error) {
        console.error('❌ Erro no debug:', error);
        res.status(500).json({
          error: error.message
        });
      }
    });

    app.get('/api/debug/connection', async (req, res) => {
      try {
        const Tenant = require('./models/Tenant');
        const isConnected = await Tenant.testConnection();
        res.json({
          success: isConnected,
          message: isConnected ? 'Conexão OK' : 'Conexão falhou'
        });
      } catch (error) {
        res.status(500).json({
          success: false,
          error: error.message
        });
      }
    });

    app.get('/api/debug/tenants', async (req, res) => {
      try {
        const Tenant = require('./models/Tenant');
        const tenants = await Tenant.getAllTenants();
        res.json({
          success: true,
          count: tenants.length,
          tenants: tenants
        });
      } catch (error) {
        res.status(500).json({
          success: false,
          error: error.message
        });
      }
    });

    // 404 handler
    app.use('*', (req, res) => {
      res.status(404).json({ 
        error: 'Endpoint não encontrado',
        path: req.originalUrl,
        method: req.method,
        availableEndpoints: [
          'GET /health',
          'GET /api/health', 
          'GET /api/test',
          'GET /api/tenant/verify/:codigo',
          'GET /api/tenant/list',
          'GET /api/debug/database',
          'GET /api/debug/tenants'
        ]
      });
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
      console.log(`🚀 SeeNet API rodando na porta ${PORT}`);
      console.log(`📝 Health: http://10.50.160.140:${PORT}/health`);
      console.log(`🏢 Tenant: http://10.50.160.140:${PORT}/api/tenant/verify/DEMO2024`);
      console.log(`🗄️ Debug: http://10.50.160.140:${PORT}/api/debug/database`);
    });

  } catch (error) {
    console.error('❌ Falha ao iniciar servidor:', error);
    process.exit(1);
  }
}

// Iniciar servidor
startServer();