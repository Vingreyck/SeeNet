// seenet-api/src/app.js - CONFIGURAÇÃO COMPLETA DE ROTAS
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const { initDatabase } = require('./config/database');
const logger = require('./config/logger');
const { authMiddleware } = require('./middleware/auth');

const app = express();

// ========== MIDDLEWARES GLOBAIS ==========

// Segurança
app.use(helmet());

// CORS
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Tenant-Code'],
  credentials: true,
}));

// Body parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
}

// Rate limiting global
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 100, // 100 requisições por IP
  message: { error: 'Muitas requisições. Tente novamente mais tarde.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', globalLimiter);

// ========== HEALTH CHECK (sem autenticação) ==========
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    database: 'connected',
    version: '1.0.0',
  });
});

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'SeeNet API is running',
    timestamp: new Date().toISOString(),
  });
});

// ========== ROTAS PÚBLICAS (sem autenticação) ==========
app.use('/api/auth', require('./routes/auth'));
app.use('/api/tenant', require('./routes/tenant'));

// ========== MIDDLEWARE DE AUTENTICAÇÃO ==========
// Todas as rotas abaixo precisam de autenticação
app.use('/api', authMiddleware);

// ========== ROTAS PROTEGIDAS ==========

// Checkmarks e Categorias
app.use('/api/checkmarks', require('./routes/checkmark'));

// Avaliações
app.use('/api/avaliacoes', require('./routes/avaliacoes'));

// Diagnósticos
app.use('/api/diagnostics', require('./routes/diagnostics'));

// Transcrições
app.use('/api/transcriptions', require('./routes/transcriptions'));

// Usuários (futuramente, endpoints de gerenciamento)
// app.use('/api/users', require('./routes/users'));

// Admin (futuramente)
app.use('/api/admin', require('./routes/admin.routes'));

// ========== ROTA 404 ==========
app.use((req, res) => {
  res.status(404).json({
    error: 'Rota não encontrada',
    path: req.path,
    method: req.method,
  });
});

// ========== HANDLER DE ERROS GLOBAL ==========
app.use((err, req, res, next) => {
  logger.error('Erro não tratado:', err);
  
  // Erro de validação
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Erro de validação',
      details: err.message,
    });
  }
  
  // Erro de autenticação
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({
      error: 'Não autorizado',
      details: err.message,
    });
  }
  
  // Erro de banco de dados
  if (err.code === 'ER_DUP_ENTRY' || err.code === '23505') {
    return res.status(409).json({
      error: 'Registro duplicado',
      details: 'Este registro já existe',
    });
  }
  
  // Erro genérico
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' 
      ? 'Erro interno do servidor' 
      : err.message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
});

// ========== INICIALIZAÇÃO ==========
const PORT = process.env.PORT || 3000;

async function startServer() {
  try {
    // Inicializar banco de dados
    await initDatabase();
    
    // Iniciar servidor
    app.listen(PORT, () => {
      logger.info(`
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              🚀 SEENET API INICIADA 🚀                  ║
║                                                          ║
║  Porta:        ${PORT.toString().padEnd(42)}║
║  Ambiente:     ${(process.env.NODE_ENV || 'development').padEnd(42)}║
║  Banco:        PostgreSQL (Railway/Neon)                ║
║  CORS:         ${(process.env.CORS_ORIGIN || '*').substring(0, 42).padEnd(42)}║
║                                                          ║
║  Rotas disponíveis:                                     ║
║  • GET  /health                                         ║
║  • POST /api/auth/login                                 ║
║  • POST /api/auth/register                              ║
║  • GET  /api/tenant/verify/:codigo                      ║
║  • GET  /api/checkmark/categorias                      ║
║  • GET  /api/checkmark/categoria/:id                   ║
║  • POST /api/avaliacoes                                 ║
║  • POST /api/diagnostics/gerar                          ║
║  • POST /api/transcriptions                             ║
║                                                          ║
║  📚 Docs: https://docs.seenet.api                       ║
║  🔧 Status: https://status.seenet.api                   ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
      `);
      
      logger.info(`✅ Servidor rodando em http://localhost:${PORT}`);
      logger.info(`✅ Health check: http://localhost:${PORT}/health`);
    });
    
  } catch (error) {
    logger.error('❌ Erro ao iniciar servidor:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM recebido. Encerrando servidor...');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT recebido. Encerrando servidor...');
  process.exit(0);
});

// Iniciar servidor
if (require.main === module) {
  startServer();
}

module.exports = app;