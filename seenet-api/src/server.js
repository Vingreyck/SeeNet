// seenet-api/src/server.js - SEÇÃO DE ROTAS CORRIGIDA

// ========== INICIALIZAR BANCO E ROTAS ==========
async function startServer() {
  try {
    console.log('🔌 Inicializando banco de dados...');
    
    const { initDatabase } = require('./config/database');
    await initDatabase();
    
    console.log('📁 Carregando rotas...');

    // ✅ ROTAS PÚBLICAS (sem autenticação)
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
      console.error('❌ Erro ao carregar rotas auth:', error.message);
    }

    // ✅ ADICIONAR MIDDLEWARE DE AUTENTICAÇÃO AQUI
    const authMiddleware = require('./middleware/auth');
    app.use('/api', authMiddleware); // Protege todas as rotas abaixo
    console.log('🔐 Middleware de autenticação aplicado');

    // ✅ ROTAS PROTEGIDAS (precisam de autenticação)
    
    // ✅ CORRIGIDO: Usar 'checkmark' (singular) conforme o arquivo
    try {
      const checkmarkRoutes = require('./routes/checkmark');
      app.use('/api/checkmark', checkmarkRoutes); // SINGULAR!
      console.log('✅ Rotas checkmark carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas checkmark:', error.message);
    }
    
    try {
      const avaliacoesRoutes = require('./routes/avaliacoes');
      app.use('/api/avaliacoes', avaliacoesRoutes);
      console.log('✅ Rotas avaliacoes carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas avaliacoes:', error.message);
    }

    try {
      const diagnosticsRoutes = require('./routes/diagnostics');
      app.use('/api/diagnostics', diagnosticsRoutes);
      console.log('✅ Rotas diagnostics carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas diagnostics:', error.message);
    }

    try {
      const transcriptionsRoutes = require('./routes/transcriptions');
      app.use('/api/transcriptions', transcriptionsRoutes);
      console.log('✅ Rotas transcriptions carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas transcriptions:', error.message);
    }

    // Health check
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

    // Debug endpoints
    app.get('/api/debug/routes', (req, res) => {
      res.json({
        message: 'Rotas disponíveis',
        routes: [
          'GET  /health',
          'GET  /api/health',
          'POST /api/auth/login',
          'POST /api/auth/register',
          'GET  /api/tenant/verify/:codigo',
          'GET  /api/checkmark/categorias', // CORRIGIDO!
          'GET  /api/checkmark/categoria/:id',
          'POST /api/avaliacoes',
          'POST /api/diagnostics/gerar',
          'POST /api/transcriptions'
        ]
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

    // 404 Handler
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
          'POST /api/auth/login',
          'POST /api/auth/register',
          'GET /api/checkmark/categorias', // CORRIGIDO!
          'GET /api/checkmark/categoria/:id',
          'GET /api/debug/database',
          'GET /api/debug/routes'
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

    // Iniciar servidor
    if (process.env.VERCEL !== '1') {
      app.listen(PORT, '0.0.0.0', () => {
        console.log(`
╔══════════════════════════════════════════════════════════╗
║              🚀 SEENET API INICIADA 🚀                  ║
║  Porta:        ${PORT}                                   ║
║  Rotas disponíveis:                                     ║
║  • POST /api/auth/login                                 ║
║  • POST /api/auth/register                              ║
║  • GET  /api/tenant/verify/:codigo                      ║
║  • GET  /api/checkmark/categorias (CORRIGIDO!)          ║
║  • GET  /api/checkmark/categoria/:id                    ║
╚══════════════════════════════════════════════════════════╝
        `);
      });
    }

  } catch (error) {
    console.error('❌ Falha ao iniciar servidor:', error);
    process.exit(1);
  }
}