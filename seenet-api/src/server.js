const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.set('trust proxy', 1); // Confiar apenas no primeiro proxy (Railway)
console.log('🚀 Iniciando servidor SeeNet API...');

// ========== MIDDLEWARES GLOBAIS ==========
app.use(helmet());
app.use(compression()); 
app.use(morgan('combined'));

app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? '*'
    : [
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

// ========== ROTAS BÁSICAS ==========
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
    
    const { initDatabase } = require('./config/database');
    await initDatabase();
    
    console.log('📁 Carregando rotas...');

    try {
      const checkmarksRoutes = require('./routes/checkmarks');
      app.use('/api/checkmarks', checkmarksRoutes);
      console.log('✅ Rotas checkmarks carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas checkmarks:', error.message);
    }
    
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
      console.error('⚠️ Rotas auth não encontradas');
    }
    
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

    app.use((error, req, res, next) => {
      console.error('❌ Erro na aplicação:', error);
      res.status(500).json({
        error: 'Erro interno do servidor',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Algo deu errado'
      });
    });

    // Só inicia o servidor se não estiver no Vercel
    if (process.env.VERCEL !== '1') {
      app.listen(PORT, '0.0.0.0', () => {
        console.log(`🚀 SeeNet API rodando na porta ${PORT}`);
      });
    }

  } catch (error) {
    console.error('❌ Falha ao iniciar servidor:', error);
    process.exit(1);
  }
}

// Iniciar servidor
startServer();

// Export para Vercel (serverless)
module.exports = app;