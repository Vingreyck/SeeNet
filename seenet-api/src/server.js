const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.set('trust proxy', 1);
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
    
    await initDatabase();
    const { db } = require('./config/database');

    
    console.log('📁 Carregando rotas...');

    // ========== ROTAS PÚBLICAS (SEM AUTENTICAÇÃO) ==========
    
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

    // ========== ROTAS PROTEGIDAS (COM AUTENTICAÇÃO) ==========
    
    try {
      const checkmarksRoutes = require('./routes/checkmark');
      app.use('/api/checkmark', checkmarksRoutes);
      console.log('✅ Rotas checkmarks carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas checkmarks:', error.message);
    }
    
    try {
      const avaliacoesRoutes = require('./routes/avaliacoes');
      app.use('/api/avaliacoes', avaliacoesRoutes);
      console.log('✅ Rotas avaliacoes carregadas');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas avaliacoes:', error.message);
    }

    // ========== DIAGNÓSTICOS (INLINE) ==========
    const { body, validationResult } = require('express-validator');
    const geminiService = require('./services/geminiService');
    const { authMiddleware } = require('./middleware/auth');

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
            console.log('❌ Avaliação não encontrada');
            return res.status(404).json({ 
              success: false, 
              error: 'Avaliação não encontrada' 
            });
          }

          // Buscar checkmarks
          const checkmarks = await db('checkmarks')
            .whereIn('id', checkmarks_marcados)
            .where('tenant_id', req.tenantId)
            .select('id', 'titulo', 'descricao', 'prompt_chatgpt');

          if (checkmarks.length === 0) {
            console.log('❌ Nenhum checkmark encontrado');
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
            prompt += `• Contexto técnico: ${c.prompt_chatgpt}\n\n`;
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

          const tokensUtilizados = Math.ceil((prompt + resposta).length / 4);

          console.log('💾 Salvando diagnóstico no banco...');

          // Salvar no banco
          const [diagnosticoId] = await db('diagnosticos').insert({
            tenant_id: req.tenantId,
            avaliacao_id,
            categoria_id,
            prompt_enviado: prompt,
            resposta_chatgpt: resposta,
            resumo_diagnostico: resumo,
            status_api: statusApi,
            modelo_ia: modeloIa,
            tokens_utilizados: tokensUtilizados,
            data_criacao: new Date().toISOString()
          });

          console.log(`✅ Diagnóstico ${diagnosticoId} gerado com sucesso!`);
          console.log(`   Status: ${statusApi}`);
          console.log(`   Modelo: ${modeloIa}`);
          console.log(`   Tokens: ${tokensUtilizados}`);

          return res.json({
            success: true,
            message: 'Diagnóstico gerado com sucesso',
            id: diagnosticoId,
            resumo: resumo,
            tokens_utilizados: tokensUtilizados
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

    // ========== ADMIN ==========
    try {
      console.log('🔍 Tentando carregar rotas admin...');
      const adminRoutes = require('./routes/admin.routes');
      app.use('/api/admin', adminRoutes);
      console.log('✅ Rotas admin registradas em /api/admin');
    } catch (error) {
      console.error('❌ Erro ao carregar rotas admin:', error.message);
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

    app.use((error, req, res, next) => {
      console.error('❌ Erro na aplicação:', error);
      res.status(500).json({
        error: 'Erro interno do servidor',
        message: process.env.NODE_ENV === 'development' ? error.message : 'Algo deu errado'
      });
    });

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

startServer();

module.exports = app;