// src/app.js - VERSÃO CORRIGIDA COM ROTA DIAGNOSTICS SEPARADA
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

const { initDatabase } = require('./config/database');
const logger = require('./config/logger');
const authMiddleware = require('./middleware/auth');


const app = express();

// ========== CONFIGURAÇÕES BÁSICAS ==========
app.set('trust proxy', 1);

// ========== MIDDLEWARES GLOBAIS ==========

// Segurança
app.use(helmet());

// Compressão
app.use(compression());

// CORS
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

// Body parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined', { 
    stream: { write: message => logger.info(message.trim()) } 
  }));
}

// Rate limiting global
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
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
    gemini: process.env.GEMINI_API_KEY ? 'Configurado' : 'Não configurado'
  });
});

// ========== ROTAS PÚBLICAS (sem autenticação) ==========
app.use('/api/auth', require('./routes/auth'));
app.use('/api/tenant', require('./routes/tenant'));

// ========== ROTAS PROTEGIDAS (com autenticação) ==========

// Checkmarks e Categorias
app.use('/api/checkmarks', authMiddleware, require('./routes/checkmark'));

// Avaliações
app.use('/api/avaliacoes', authMiddleware, require('./routes/avaliacoes'));

// ✅ DIAGNÓSTICOS - ROTA SEPARADA E CORRIGIDA
app.use('/api/diagnostics', authMiddleware, require('./routes/diagnostics'));

logger.info('✅ Rota /api/diagnostics registrada (arquivo separado)');

// Transcrições
app.use('/api/transcriptions', authMiddleware, require('./routes/transcriptions'));

// Admin
app.use('/api/admin', authMiddleware, require('./routes/admin.routes'));

// ========== DEBUG: LISTAR ROTAS REGISTRADAS ==========
if (process.env.NODE_ENV !== 'production') {
  logger.info('\n📋 === ROTAS REGISTRADAS ===');
  
  const routes = [];
  
  app._router.stack.forEach((middleware) => {
    if (middleware.route) {
      // Rota direta
      routes.push({
        path: middleware.route.path,
        methods: Object.keys(middleware.route.methods).join(', ').toUpperCase()
      });
    } else if (middleware.name === 'router') {
      // Router montado
      middleware.handle.stack.forEach((handler) => {
        if (handler.route) {
          const basePath = middleware.regexp.source
            .replace('\\/?', '')
            .replace('(?=\\/|$)', '')
            .replace(/\\\//g, '/');
          
          routes.push({
            path: basePath + handler.route.path,
            methods: Object.keys(handler.route.methods).join(', ').toUpperCase()
          });
        }
      });
    }
  });
  
  // Filtrar e mostrar rotas relevantes
  const relevantRoutes = routes.filter(r => 
    r.path.includes('/api/') || r.path === '/health'
  );
  
  relevantRoutes.forEach(route => {
    logger.info(`   ${route.methods.padEnd(6)} ${route.path}`);
  });
  
  logger.info('============================\n');
  
  // ✅ VERIFICAR ESPECIFICAMENTE A ROTA DE DIAGNÓSTICOS
  const diagnosticsRoutes = relevantRoutes.filter(r => 
    r.path.includes('diagnostic')
  );
  
  if (diagnosticsRoutes.length > 0) {
    logger.info('✅ Rotas de diagnósticos encontradas:');
    diagnosticsRoutes.forEach(route => {
      logger.info(`   ${route.methods} ${route.path}`);
    });
  } else {
    logger.error('❌ NENHUMA rota de diagnósticos registrada!');
  }
}

// ========== ROTA 404 ==========
app.use((req, res) => {
  logger.warn(`404 - Rota não encontrada: ${req.method} ${req.path}`);
  res.status(404).json({
    error: 'Rota não encontrada',
    path: req.path,
    method: req.method,
  });
});

// ========== HANDLER DE ERROS GLOBAL ==========
app.use((err, req, res, next) => {
  logger.error('Erro não tratado:', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method
  });
  
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      error: 'Erro de validação',
      details: err.message,
    });
  }
  
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({
      error: 'Não autorizado',
      details: err.message,
    });
  }
  
  if (err.code === 'ER_DUP_ENTRY' || err.code === '23505') {
    return res.status(409).json({
      error: 'Registro duplicado',
      details: 'Este registro já existe',
    });
  }
  
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
    logger.info('🚀 Iniciando SeeNet API...');
    
    // Inicializar banco
    await initDatabase();
    logger.info('✅ Banco de dados inicializado');
    
    // ✅ TESTAR CONEXÃO COM GEMINI
    if (process.env.GEMINI_API_KEY) {
      const geminiService = require('./services/geminiService');
      geminiService.debugConfig();
      
      // Teste opcional (comentar em produção se quiser economizar quota)
      // const testeGemini = await geminiService.testarConexao();
      // logger.info(`Gemini: ${testeGemini ? '✅ Funcionando' : '❌ Com problemas'}`);
    } else {
      logger.warn('⚠️ GEMINI_API_KEY não configurada!');
    }
    
    // Iniciar servidor
    if (process.env.VERCEL !== '1') {
      app.listen(PORT, '0.0.0.0', () => {
        logger.info(`
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║              🚀 SEENET API INICIADA 🚀                  ║
║                                                          ║
║  Porta:        ${PORT.toString().padEnd(42)}║
║  Ambiente:     ${(process.env.NODE_ENV || 'development').padEnd(42)}║
║  Banco:        PostgreSQL                               ║
║  Gemini:       ${(process.env.GEMINI_API_KEY ? 'Configurado ✅' : 'NÃO configurado ❌').padEnd(42)}║
║                                                          ║
║  Rotas principais:                                      ║
║  • GET  /health                                         ║
║  • POST /api/auth/login                                 ║
║  • POST /api/diagnostics/gerar ✅                       ║
║  • GET  /api/diagnostics/avaliacao/:id                  ║
║  • POST /api/transcriptions                             ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
        `);
        
        logger.info(`✅ Servidor rodando em http://localhost:${PORT}`);
      });
    }
    
  } catch (error) {
    logger.error('❌ Erro ao iniciar servidor:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM recebido. Encerrando...');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT recebido. Encerrando...');
  process.exit(0);
});

if (require.main === module) {
  startServer();
}

module.exports = app;