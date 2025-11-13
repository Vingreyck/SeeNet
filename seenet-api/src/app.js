// seenet-api/src/app.js - CONFIGURAÇÃO COMPLETA DE ROTAS
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const { initDatabase, db } = require('./config/database');
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

// ========== DIAGNÓSTICOS (INLINE) ==========
const { body, validationResult } = require('express-validator');
const geminiService = require('./services/geminiService');

// Error handler específico para diagnósticos
const handleDiagnosticError = (error, req, res) => {
  console.error('\n❌ === ERRO NO DIAGNÓSTICO ===');
  console.error('Tipo:', error.constructor.name);
  console.error('Mensagem:', error.message);
  console.error('Stack:', error.stack);
  
  if (error.response) {
    console.error('Detalhes da resposta:');
    console.error('Status:', error.response.status);
    console.error('Data:', JSON.stringify(error.response.data, null, 2));
  }

  // Log do contexto no momento do erro
  console.error('Contexto:');
  console.error('User:', req.user ? `${req.user.id} - ${req.user.nome}` : 'N/A');
  console.error('Tenant:', req.tenantId);
  console.error('Body:', req.body);

  return res.status(500).json({
    success: false,
    error: 'Erro interno do servidor',
    details: process.env.NODE_ENV === 'development' ? {
      message: error.message,
      type: error.constructor.name,
      stack: error.stack
    } : undefined
  });
};

app.post('/api/diagnostics/gerar',
  async (req, res, next) => {
    try {
      console.log('\n🚨 === REQUISIÇÃO RECEBIDA: /api/diagnostics/gerar ===');
      console.log('📦 Body:', JSON.stringify(req.body, null, 2));
      console.log('🔐 Authorization header:', req.headers.authorization ? 'PRESENTE' : 'AUSENTE');
      console.log('🏢 X-Tenant-Code header:', req.headers['x-tenant-code'] || 'AUSENTE');
      
      // Log do tenant e usuário
      console.log('👤 Usuário:', req.user ? `${req.user.id} - ${req.user.nome}` : 'NÃO IDENTIFICADO');
      console.log('🏢 Tenant:', req.tenantId ? `ID ${req.tenantId}` : 'NÃO IDENTIFICADO');
      
      // Verificar se os dados necessários estão presentes
      if (!req.body.avaliacao_id || !req.body.categoria_id || !req.body.checkmarks_marcados) {
        console.log('❌ Dados obrigatórios ausentes no body');
        console.log('   avaliacao_id:', req.body.avaliacao_id);
        console.log('   categoria_id:', req.body.categoria_id);
        console.log('   checkmarks_marcados:', req.body.checkmarks_marcados);
      }
      
      next();
    } catch (error) {
      console.error('❌ Erro no middleware de diagnóstico:', error);
      next(error);
    }
  },
  authMiddleware,  // ← Vai mostrar logs agora
  [
    body('avaliacao_id').isInt({ min: 1 }),
    body('categoria_id').isInt({ min: 1 }),
    body('checkmarks_marcados').isArray({ min: 1 })
  ],
  async (req, res) => {
    console.log('\n✨ === INICIANDO GERAÇÃO DE DIAGNÓSTICO ===');
    console.log('👤 Usuário:', req.user.id, '-', req.user.nome);
    console.log('🏢 Tenant:', req.tenantId);
    console.log('📦 Dados:', JSON.stringify(req.body, null, 2));
    
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

      console.log('🚀 Gerando diagnóstico...');
      console.log(`   Avaliação: ${avaliacao_id}`);
      console.log(`   Categoria: ${categoria_id}`);
      console.log(`   Checkmarks: ${JSON.stringify(checkmarks_marcados)}`);

      // Verificar avaliação
      const avaliacao = await db('avaliacoes')
        .where('id', avaliacao_id)
        .where('tenant_id', req.tenantId)
        .first();

      if (!avaliacao) {
        logger.warn('❌ Avaliação não encontrada');
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
        logger.warn('❌ Nenhum checkmark encontrado');
        return res.status(400).json({ 
          success: false, 
          error: 'Checkmarks não encontrados' 
        });
      }

      logger.info(`✅ ${checkmarks.length} checkmarks encontrados`);

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

      logger.info('📝 Prompt montado. Enviando para Gemini...');

      // Gerar com Gemini
      let resposta;
      let statusApi = 'sucesso';
      let modeloIa = 'gemini-1.5-flash';
      
      try {
        resposta = await geminiService.gerarDiagnostico(prompt);
        
        if (!resposta) {
          throw new Error('Gemini retornou resposta vazia');
        }
        
        logger.info('✅ Resposta recebida do Gemini');
      } catch (geminiError) {
        logger.warn('⚠️ Gemini falhou, usando fallback:', geminiError.message);
        statusApi = 'erro';
        modeloIa = 'fallback';
        
        // Fallback
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

      // Extrair resumo
      const linhas = resposta.split('\n');
      let resumo = '';
      for (let linha of linhas) {
        if (linha.includes('DIAGNÓSTICO') || linha.includes('ANÁLISE') || linha.includes('PROBLEMA')) {
          resumo = linha.replace(/[🔍📊🎯*#]/g, '').trim();
          break;
        }
      }
      if (!resumo) {
        resumo = resposta.substring(0, 120);
      }
      if (resumo.length > 120) {
        resumo = resumo.substring(0, 120) + '...';
      }

      // Contar tokens
      const tokensUtilizados = Math.ceil((prompt + resposta).length / 4);

      logger.info('💾 Salvando diagnóstico no banco...');

      // Salvar no banco
      const [diagnosticoId] = await db('diagnosticos').insert({
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
      });

      logger.info(`   Status: ${statusApi}`);
      logger.info(`   Modelo: ${modeloIa}`);
      logger.info(`   Tokens: ${tokensUtilizados}`);

      return res.json({
        success: true,
        message: 'Diagnóstico gerado com sucesso',
        id: diagnosticoId,
        resumo: resumo,
        tokens_utilizados: tokensUtilizados
      });

    } catch (error) {
      logger.error('\n❌ === ERRO AO GERAR DIAGNÓSTICO ===');
      logger.error('Tipo:', error.constructor.name);
      logger.error('Mensagem:', error.message);
      logger.error('Stack:', error.stack);
      
      // Log detalhado para erros do Gemini
      if (error.response) {
        logger.error('Resposta da API:');
        logger.error('Status:', error.response.status);
        logger.error('Data:', JSON.stringify(error.response.data, null, 2));
        logger.error('Headers:', JSON.stringify(error.response.headers, null, 2));
      }
      
      // Capturando detalhes do contexto
      logger.error('Contexto da execução:');
      logger.error('Usuário:', req.user ? `${req.user.id} - ${req.user.nome}` : 'N/A');
      logger.error('Tenant:', req.tenantId);
      logger.error('Body:', JSON.stringify(req.body, null, 2));
      
      return res.status(500).json({ 
        success: false, 
        error: 'Erro interno do servidor',
        details: process.env.NODE_ENV === 'production' 
          ? undefined 
          : {
              message: error.message,
              type: error.constructor.name,
              code: error.code || 'UNKNOWN_ERROR'
            }
      });
    }
});

logger.info('✅ Rota POST /api/diagnostics/gerar registrada (inline)');
// ✅ ADICIONAR ESTE LOG DE DEBUG:
console.log('🔍 DEBUG: Rota de diagnósticos registrada com sucesso');
app._router.stack.forEach(function(r){
  if (r.route && r.route.path && r.route.path.includes('diagnostic')){
    console.log('   Rota encontrada:', Object.keys(r.route.methods), r.route.path);
  }
});
// Transcrições
app.use('/api/transcriptions', require('./routes/transcriptions'));

// Admin
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
    await initDatabase();
    
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
║  • POST /api/diagnostics/gerar ✅ (inline)             ║
║  • POST /api/transcriptions                             ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
      `);
      
      logger.info(`✅ Servidor rodando em http://localhost:${PORT}`);
    });
    
  } catch (error) {
    logger.error('❌ Erro ao iniciar servidor:', error);
    process.exit(1);
  }
}

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