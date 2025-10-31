const express = require('express');
const { formatResponse, formatError } = require('./middleware/responseFormatter')
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const logger = require('./config/logger');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.set('trust proxy', 1);

logger.info('\n=== 🚀 INICIANDO SEENET API ===');
logger.info(`Ambiente: ${process.env.NODE_ENV || 'development'}`);
logger.info(`Porta: ${PORT}`);

// ========== MIDDLEWARES GLOBAIS ==========
app.use(helmet());
app.use(compression()); 
// Configurar morgan para usar o logger
app.use(morgan('[:date[iso]] :method :url :status :response-time ms - :res[content-length]', {
  stream: {
    write: (message) => {
      // Filtrar healthchecks para reduzir ruído
      if (!message.includes('/health')) {
        logger.info(message.trim());
      }
    }
  },
  skip: (req) => {
    // Não logar requests de health check em produção
    return process.env.NODE_ENV === 'production' && req.path === '/health';
  }
}));

// CORS settings
const corsOptions = {
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
};

app.use(express.json({ limit: '10mb' }));
app.use(formatResponse);
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
    
    // ✅ ADICIONAR ESTA LINHA:
    const { initDatabase } = require('./config/database');
    await initDatabase();
    
    // ✅ AGORA PEGAR O db
    const { db } = require('./config/database');
    
    console.log('📁 Carregando rotas...');

    // ========== ROTAS PÚBLICAS (SEM AUTENTICAÇÃO) ==========
    
    try {
      const tenantRoutes = require('./routes/tenant');
      app.use('/api/tenant', require('./routes/tenant'));
      console.log('✅ Rotas tenant carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas tenant:', error.message);
    }
    
    try {
      const authRoutes = require('./routes/auth');
      app.use('/api/auth', require('./routes/auth'));
      console.log('✅ Rotas auth carregadas');
    } catch (error) {
      console.error('⚠️ Rotas auth não encontradas');
    }

    // ========== ROTAS PROTEGIDAS (COM AUTENTICAÇÃO) ==========
    
    try {
      const checkmarksRoutes = require('./routes/checkmark');
      app.use('/api/checkmark', require('./routes/checkmark'));
      console.log('✅ Rotas checkmarks carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas checkmarks:', error.message);
    }
    
    try {
      const avaliacoesRoutes = require('./routes/avaliacoes');
      app.use('/api/avaliacoes', require('./routes/avaliacoes'));
      console.log('✅ Rotas avaliacoes carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas avaliacoes:', error.message);
    }

    // ========== DIAGNÓSTICOS (INLINE) ==========
    const { body, validationResult } = require('express-validator');
    const geminiService = require('./routes/geminiService');
    const  authMiddleware  = require('./middleware/auth');

    app.post('/api/diagnostics/gerar', 
      authMiddleware,
      [
        body('avaliacao_id').isInt({ min: 1 }),
        body('categoria_id').isInt({ min: 1 }),
        body('checkmarks_marcados').isArray({ min: 1 })
      ], 
      async (req, res) => {
        try {
          const errors = validationResult(req);
          if (!errors.isEmpty()) {
            console.log('❌ Validação falhou:', errors.array());
            return res.status(400).json({ 
              success: false, 
              error: 'Dados inválidos', 
              details: errors.array() 
            });
          }

          const { avaliacao_id, categoria_id, checkmarks_marcados } = req.body;

          logger.info('Iniciando geração de diagnóstico', {
            avaliacao_id,
            categoria_id,
            checkmarks_marcados,
            tenant_id: req.tenantId,
            usuario_id: req.user.id
          });

          // Verificar avaliação
          const avaliacao = await db('avaliacoes')
            .where('id', avaliacao_id)
            .where('tenant_id', req.tenantId)
            .first();

          if (!avaliacao) {
            logger.warn('Avaliação não encontrada', {
              avaliacao_id,
              tenant_id: req.tenantId,
              usuario_id: req.user.id
            });
            return res.status(404).json({ 
              success: false, 
              error: 'Avaliação não encontrada' 
            });
          }

          // Buscar checkmarks
          const checkmarks = await db('checkmarks')
            .whereIn('id', checkmarks_marcados)
            .where('tenant_id', req.tenantId)
            .select('id', 'titulo', 'descricao', 'prompt_gemini');

          if (checkmarks.length === 0) {
            logger.warn('Checkmarks não encontrados', {
              checkmarks_marcados,
              tenant_id: req.tenantId,
              usuario_id: req.user.id
            });
            return res.status(400).json({ 
              success: false, 
              error: 'Checkmarks não encontrados' 
            });
          }

          console.log(`✅ ${checkmarks.length} checkmarks encontrados`);

          // Montar prompt
          let prompt = "RELATÓRIO TÉCNICO DE PROBLEMAS IDENTIFICADOS:\n\n";
          checkmarks.forEach((c, i) => {
            prompt += `PROBLEMA ${i + 1}:\n`;
            prompt += `• Título: ${c.titulo}\n`;
            if (c.descricao) {
              prompt += `• Descrição: ${c.descricao}\n`;
            }
            prompt += `• Contexto técnico: ${c.prompt_gemini}\n\n`;
          });
          prompt += "TAREFA:\n";
          prompt += "Analise os problemas listados e forneça um diagnóstico técnico completo. ";
          prompt += "Considere correlações entre os problemas. ";
          prompt += "Forneça soluções práticas, começando pelas mais simples.";

          console.log('📝 Prompt montado. Enviando para Gemini...');

          // Gerar com Gemini
          let resposta;
          let statusApi = 'sucesso';
          let modeloIa = 'gemini-2.0-flash';
          
          try {
            resposta = await geminiService.gerarDiagnostico(prompt);
            
            if (!resposta) {
              throw new Error('Gemini retornou resposta vazia');
            }
            
            console.log('✅ Resposta recebida do Gemini');
          } catch (geminiError) {
            console.log('⚠️ Gemini falhou, usando fallback:', geminiError.message);
            statusApi = 'erro';
            modeloIa = 'fallback';
            
            const problemas = checkmarks.map(c => c.titulo).join(', ');
            resposta = `🔧 DIAGNÓSTICO TÉCNICO (MODO FALLBACK)

📊 PROBLEMAS IDENTIFICADOS: ${problemas}

🛠️ AÇÕES RECOMENDADAS:
1. Reinicie todos os equipamentos (modem, roteador, dispositivos)
2. Verifique todas as conexões físicas e cabos
3. Teste a conectividade em diferentes dispositivos
4. Documente os resultados de cada teste

📞 PRÓXIMOS PASSOS:
- Execute as soluções na ordem apresentada
- Anote o que funcionou ou não funcionou
- Se problemas persistirem, entre em contato com suporte técnico

---
⚠️ Este diagnóstico foi gerado em modo fallback devido à indisponibilidade da IA.`;
          }

          // Extrair resumo com validação
          let resumo = '';
          if (typeof resposta === 'string') {
            const linhas = resposta.split('\n');
            for (let linha of linhas) {
              if (linha.includes('DIAGNÓSTICO') || linha.includes('ANÁLISE') || linha.includes('PROBLEMA')) {
                resumo = linha.replace(/[🔍📊🎯*#]/g, '').trim();
                break;
              }
            }
            if (!resumo) {
              resumo = resposta.substring(0, 120);
            }
          } else {
            console.error('❌ Resposta não é uma string:', resposta);
            resumo = 'Erro ao gerar diagnóstico';
          }
          if (resumo.length > 120) {
            resumo = resumo.substring(0, 120) + '...';
          }

          const tokensUtilizados = Math.ceil((prompt + resposta).length / 4);

          console.log('💾 Salvando diagnóstico no banco...');

          // Salvar no banco
          const result = await db('diagnosticos').insert({
            tenant_id: req.tenantId,
            avaliacao_id,
            categoria_id,
            prompt_enviado: prompt,
            resposta_gemini: resposta,
            resumo_diagnostico: resumo,
            status_api: statusApi,
            modelo_ia: modeloIa,
            tokens_utilizados: tokensUtilizados,
            data_criacao: new Date().toISOString()
          }).returning(['id', 'resposta_gemini', 'resumo_diagnostico', 'tokens_utilizados']);
          
          const diagnostico = result[0];

          console.log(`✅ Diagnóstico ${diagnostico.id} gerado com sucesso!`);
          console.log(`   Status: ${statusApi}`);
          console.log(`   Modelo: ${modeloIa}`);
          console.log(`   Tokens: ${tokensUtilizados}`);

          // Log dos dados antes de enviar
          console.log('📤 Enviando resposta:', {
            id: diagnostico.id,
            resposta: diagnostico.resposta_gemini ? diagnostico.resposta_gemini.substring(0, 50) + '...' : 'N/A',
            resumo: diagnostico.resumo_diagnostico,
            tokens: diagnostico.tokens_utilizados
          });

          return res.json({
            success: true,
            message: 'Diagnóstico gerado com sucesso',
            data: {
              id: diagnostico.id,
              resposta: diagnostico.resposta_gemini,
              resumo: diagnostico.resumo_diagnostico,
              tokens_utilizados: diagnostico.tokens_utilizados,
              status: statusApi,
              modelo: modeloIa
            }
          });

        } catch (error) {
          console.error('❌ Erro ao gerar diagnóstico:', error);
          return res.status(500).json({ 
            success: false, 
            error: 'Erro interno do servidor',
            details: process.env.NODE_ENV === 'production' ? undefined : error.message
          });
        }
    });

    console.log('✅ Rota POST /api/diagnostics/gerar registrada (inline)');

    app.get('/api/admin/categorias/test', (req, res) => {
  console.log('🧪 Rota de teste /api/admin/categorias/test chamada');
  res.json({ 
    message: 'Rota de teste funcionando!',
    timestamp: new Date().toISOString()
  });
});

    // ========== ADMIN ==========
try {
  console.log('\n=== CARREGANDO ROTAS ADMIN ===');
  console.log('📂 Tentando carregar: ./routes/admin.routes');
  const adminRoutes = require('./routes/admin.routes');
  console.log('✅ admin.routes carregado com sucesso');
  
  app.use('/api/admin', adminRoutes);
  console.log('✅ Rotas /api/admin registradas');
  console.log('=== FIM ROTAS ADMIN ===\n');
} catch (error) {
  console.error('❌ ERRO AO CARREGAR admin.routes:', error.message);
  console.error('Stack:', error.stack);
}

// ========== ADMIN CATEGORIAS ==========
try {
  console.log('\n=== CARREGANDO ROTAS ADMIN/CATEGORIAS ===');
  console.log('📂 Tentando carregar: ./routes/admin/categorias');
  
  // Verificar se arquivo existe
  const fs = require('fs');
  const path = require('path');
  const categoriaPath = path.join(__dirname, 'routes', 'admin', 'categorias.js');
  console.log('📍 Caminho completo:', categoriaPath);
  console.log('📄 Arquivo existe?', fs.existsSync(categoriaPath));
  
  const categoriasAdminRoutes = require('./routes/admin/categorias');
  console.log('✅ admin/categorias carregado com sucesso');
  console.log('   Tipo:', typeof categoriasAdminRoutes);
  console.log('   É router?', categoriasAdminRoutes.stack ? 'SIM' : 'NÃO');
  
  app.use('/api/admin/categorias', categoriasAdminRoutes);
  console.log('✅ Rotas /api/admin/categorias registradas');
  console.log('=== FIM ROTAS ADMIN/CATEGORIAS ===\n');
} catch (error) {
  console.error('❌ ERRO AO CARREGAR admin/categorias:', error.message);
  console.error('Stack:', error.stack);
}
    
    // ========== ROTAS DE DEBUG ==========
    
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
        const tenants = await db('tenants').select('*').limit(5);
        res.json({
          message: 'Debug do banco PostgreSQL',
          total_tenants: tenants.length,
          tenants: tenants,
          connection: 'PostgreSQL OK'
        });
      } catch (error) {
        res.status(500).json({ error: error.message });
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
        res.status(500).json({ success: false, error: error.message });
      }
    });

    app.use('*', (req, res) => {
      res.status(404).json({ 
        error: 'Endpoint não encontrado',
        path: req.originalUrl,
        method: req.method
      });
    });

    // Handler de erros global
    app.use((error, req, res, next) => {
      // Estruturar informações do erro
      const errorInfo = {
        type: error.constructor.name,
        message: error.message,
        path: req.path,
        method: req.method,
        userId: req.user?.id,
        tenantId: req.tenantId,
        timestamp: new Date().toISOString()
      };

      // Log detalhado para erros não tratados
      logger.error('Erro não tratado na aplicação', {
        ...errorInfo,
        stack: error.stack,
        body: req.body,
        query: req.query,
        headers: req.headers
      });

      // Determinar status HTTP apropriado
      const status = error.status || 
        (error.name === 'ValidationError' ? 400 : 
         error.name === 'UnauthorizedError' ? 401 : 500);

      // Resposta ao cliente
      res.status(status).json({
        error: status === 500 ? 'Erro interno do servidor' : error.message,
        type: error.name,
        path: req.path,
        ...(process.env.NODE_ENV === 'development' && {
          details: error.message,
          stack: error.stack
        })
      });
    });

    // Listar todas as rotas registradas
console.log('\n=== ROTAS REGISTRADAS ===');
app._router.stack.forEach((middleware) => {
  if (middleware.route) {
    // Rotas diretas
    console.log(`${Object.keys(middleware.route.methods)[0].toUpperCase()} ${middleware.route.path}`);
  } else if (middleware.name === 'router') {
    // Routers montados
    middleware.handle.stack.forEach((handler) => {
      if (handler.route) {
        const path = middleware.regexp.source
          .replace('\\/?', '')
          .replace('(?=\\/|$)', '')
          .replace(/\\/g, '');
        console.log(`${Object.keys(handler.route.methods)[0].toUpperCase()} ${path}${handler.route.path}`);
      }
    });
  }
});

    if (process.env.VERCEL !== '1') {
      app.listen(PORT, '0.0.0.0', () => {
        logger.info('\n=== ✨ SERVIDOR INICIADO COM SUCESSO ===', {
          port: PORT,
          environment: process.env.NODE_ENV,
          nodeVersion: process.version,
          timestamp: new Date().toISOString()
        });
      });
    }

  } catch (error) {
    logger.error('Falha crítica ao iniciar servidor', {
      error: {
        type: error.constructor.name,
        message: error.message,
        stack: error.stack
      },
      environment: process.env.NODE_ENV,
      timestamp: new Date().toISOString()
    });
    process.exit(1);
  }
}

startServer();

module.exports = app;