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

//BACKUP BANCO NEON
app.get('/api/admin/backup-emergency', async (req, res) => {
  try {
    console.log('🚨 Backup emergência iniciado...');
    
    const { db } = require('./config/database');
    
    const tables = await db.raw(`
      SELECT tablename 
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `);
    
    let backup = `-- Backup Emergência SeeNet\n`;
    backup += `-- Data: ${new Date().toISOString()}\n\n`;
    
    for (const { tablename } of tables.rows) {
      console.log(`📦 ${tablename}`);
      
      const dados = await db(tablename).select('*');
      
      if (dados.length > 0) {
        backup += `\n-- ${tablename} (${dados.length} registros)\n`;
        backup += `TRUNCATE TABLE ${tablename} CASCADE;\n`;
        
        for (const row of dados) {
          const cols = Object.keys(row);
          const vals = cols.map(c => {
            const val = row[c];
            if (val === null) return 'NULL';
            if (typeof val === 'string') return `'${val.replace(/'/g, "''")}'`;
            if (val instanceof Date) return `'${val.toISOString()}'`;
            if (typeof val === 'object') return `'${JSON.stringify(val).replace(/'/g, "''")}'`;
            return val;
          });
          backup += `INSERT INTO ${tablename} (${cols.join(',')}) VALUES (${vals.join(',')});\n`;
        }
      }
    }
    
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Content-Disposition', 'attachment; filename=backup_seenet.sql');
    res.send(backup);
    
  } catch (error) {
    console.error('❌ Erro:', error);
    res.status(500).json({ error: error.message });
  }
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

    // ✅ INICIALIZAR SINCRONIZADOR IXC
try {
  console.log('🔄 Inicializando sincronizador IXC...');
  const SincronizadorIXC = require('./services/SincronizadorIXC');
  const sincronizador = new SincronizadorIXC();
  sincronizador.iniciar();
  console.log('✅ Sincronizador IXC ativo');
} catch (error) {
  console.error('⚠️ Erro ao iniciar sincronizador IXC:', error.message);
  console.error('   O sistema funcionará normalmente, mas a sincronização automática não estará ativa.');
}

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

    // ========== PLAY INTEGRITY API ==========
    try {
      const integrityRoutes = require('./routes/integrity');
      app.use('/api', integrityRoutes);
      console.log('✅ Rotas Play Integrity carregadas');
    } catch (error) {
      console.error('⚠️ Rotas Play Integrity não encontradas:', error.message);
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
          let modeloIa = 'gemini-1.5-flash';
          
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

// ========== ORDENS DE SERVIÇO ==========
try {
  console.log('\n=== CARREGANDO ROTAS ORDENS DE SERVIÇO ===');
  const ordensServicoRoutes = require('./routes/ordens-servico.routes');
  app.use('/api/ordens-servico', ordensServicoRoutes);
  console.log('✅ Rotas /api/ordens-servico registradas');
} catch (error) {
  console.error('❌ Erro ao carregar rotas ordens-servico:', error.message);
}

// ========== INTEGRAÇÕES (ADMIN) ==========
try {
  console.log('=== CARREGANDO ROTAS INTEGRAÇÕES ===');
  const integracoesRoutes = require('./routes/admin/integracoes.routes');
  app.use('/api/integracoes', integracoesRoutes);
  console.log('✅ Rotas /api/integracoes registradas');
} catch (error) {
  console.error('❌ Erro ao carregar rotas integracoes:', error.message);
}

// ============================================
// ROTA DE DEBUG: TESTAR ENDPOINTS IXC
// ============================================
app.get('/api/debug/test-ixc-endpoints', async (req, res) => {
  const axios = require('axios');
  
  try {
    console.log('🔍 Testando endpoints IXC...');
    
    // Buscar config do banco
    const integracao = await db('integracao_ixc')
      .where('tenant_id', 5)
      .first();
    
    if (!integracao) {
      return res.json({ error: 'Integração não configurada' });
    }
    
    console.log('📡 URL API:', integracao.url_api);
    
    const endpoints = [
      'su_oss_chamado',
      'su_os',
      'su_ordem_servico',
      'ordem_servico',
      'ordens_servico',
      'os',
      'chamado'
    ];
    
    const resultados = [];
    
    for (const endpoint of endpoints) {
      try {
        console.log(`   Testando: ${endpoint}`);
        
const params = new URLSearchParams({
  qtype: 'id',
  query: '',
  oper: '!=',
  page: '1',
  rp: '10'
});

const response = await axios.post(`${integracao.url_api}/${endpoint}`,
  params.toString(),
  {
    headers: {
      'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'ixcsoft': 'listar'
    },
    timeout: 5000
  }
);
        
        const qtd = response.data.registros?.length || 0;
        const total = response.data.total || 0;
        
        console.log(`   ✅ ${endpoint}: ${qtd} registros / ${total} total`);
        
        resultados.push({
          endpoint,
          status: 'OK',
          total: total,
          registros: qtd,
          campos: qtd > 0 ? Object.keys(response.data.registros[0]) : [],
          exemplo: qtd > 0 ? response.data.registros[0] : null
        });
        
      } catch (error) {
        const statusCode = error.response?.status;
        console.log(`   ❌ ${endpoint}: ${statusCode || error.message}`);
        
        resultados.push({
          endpoint,
          status: 'ERRO',
          erro: statusCode || error.message
        });
      }
    }
    
    console.log('✅ Teste concluído');
    
    res.json({
      url_api: integracao.url_api,
      resultados: resultados.sort((a, b) => {
        if (a.status === 'OK' && b.status !== 'OK') return -1;
        if (a.status !== 'OK' && b.status === 'OK') return 1;
        return 0;
      })
    });
    
  } catch (error) {
    console.error('❌ Erro:', error);
    res.status(500).json({ error: error.message });
  }
});


// ✅ ROTA TEMPORÁRIA PARA DESCOBRIR IP
app.get('/debug-ip', async (req, res) => {
  try {
    const axios = require('axios');
    const ipResponse = await axios.get('https://api.ipify.org?format=json');

    res.json({
      railway_ip: ipResponse.data.ip,
      request_ip: req.ip,
      forwarded_for: req.headers['x-forwarded-for'],
      user_agent: req.headers['user-agent']
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// TESTE: Buscar OS específica por ID
app.get('/api/debug/test-ixc-os/:osId', async (req, res) => {
  const axios = require('axios');
  
  try {
    const { osId } = req.params;
    
    const integracao = await db('integracao_ixc')
      .where('tenant_id', 5)
      .first();
    
    if (!integracao) {
      return res.status(404).json({ error: 'Integração não configurada' });
    }
    
    console.log(`🔍 Buscando OS ID ${osId} no IXC...`);
    
    // Tentar buscar por ID específico
const params = new URLSearchParams({
  qtype: 'id',
  query: osId.toString(),
  oper: '=',
  page: '1',
  rp: '1'
});

const response = await axios.post(`${integracao.url_api}/su_oss_chamado`,
  params.toString(),
  {
    headers: {
      'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'ixcsoft': 'listar'
    },
    timeout: 5000
  }
);
    
    console.log('✅ Resposta recebida');
    
    return res.status(200).json({
      sucesso: true,
      os: response.data
    });
    
  } catch (error) {
    console.error('❌ Erro:', error.response?.status, error.message);
    return res.status(500).json({ 
      erro: error.response?.status || error.message,
      detalhes: error.response?.data 
    });
  }
});

// Testar acesso a outros endpoints
// Testar acesso a outros endpoints
app.get('/api/debug/test-ixc-permissoes', async (req, res) => {
  const axios = require('axios');
  
  try {
    const integracao = await db('integracao_ixc')
      .where('tenant_id', 5)
      .first();
    
    if (!integracao) {
      return res.status(404).json({ error: 'Integração não configurada' });
    }
    
    const testes = [];
    
    // Teste 1: Listar clientes
    try {
      const params1 = new URLSearchParams({
        qtype: 'id',
        query: '',
        oper: '!=',
        page: '1',
        rp: '5'
      });

      const r1 = await axios.post(`${integracao.url_api}/cliente`,
        params1.toString(),
        {
          headers: {
            'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
            'Content-Type': 'application/x-www-form-urlencoded',
            'ixcsoft': 'listar'
          },
          timeout: 5000
        }
      );
      
      testes.push({ 
        modulo: 'Clientes', 
        total: r1.data.total || 0,
        status: 'OK'
      });
    } catch (e) {
      testes.push({ 
        modulo: 'Clientes', 
        erro: e.response?.status || e.message 
      });
    }
    
    // Teste 2: Listar colaboradores
    try {
      const params2 = new URLSearchParams({
        qtype: 'id',
        query: '',
        oper: '!=',
        page: '1',
        rp: '5'
      });

      const r2 = await axios.post(`${integracao.url_api}/funcionario`,
        params2.toString(),
        {
          headers: {
            'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
            'Content-Type': 'application/x-www-form-urlencoded',
            'ixcsoft': 'listar'
          },
          timeout: 5000
        }
      );
      
      testes.push({ 
        modulo: 'Funcionários', 
        total: r2.data.total || 0,
        status: 'OK'
      });
    } catch (e) {
      testes.push({ 
        modulo: 'Funcionários', 
        erro: e.response?.status || e.message 
      });
    }
    
    // Teste 3: Listar OSs
    try {
      const params3 = new URLSearchParams({
        qtype: 'id',
        query: '',
        oper: '!=',
        page: '1',
        rp: '5'
      });

      const r3 = await axios.post(`${integracao.url_api}/su_oss_chamado`,
        params3.toString(),
        {
          headers: {
            'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
            'Content-Type': 'application/x-www-form-urlencoded',
            'ixcsoft': 'listar'
          },
          timeout: 5000
        }
      );
      
      testes.push({ 
        modulo: 'Ordens de Serviço', 
        total: r3.data.total || 0,
        status: 'OK'
      });
    } catch (e) {
      testes.push({ 
        modulo: 'Ordens de Serviço', 
        erro: e.response?.status || e.message 
      });
    }
    
    return res.status(200).json({ testes });
    
  } catch (error) {
    console.error('❌ Erro:', error);
    return res.status(500).json({ error: error.message });
  }
});

// Testar se consegue listar QUALQUER coisa
app.get('/api/debug/test-ixc-listar-modulos', async (req, res) => {
  const axios = require('axios');
  
  try {
    const integracao = await db('integracao_ixc')
      .where('tenant_id', 5)
      .first();
    
    // Tentar listar colaboradores (sabemos que funciona)
    const params = new URLSearchParams({
      qtype: 'id',
      query: '',
      oper: '!=',
      page: '1',
      rp: '5'
    });

    const response = await axios.post(`${integracao.url_api}/colaborador`,
      params.toString(),
      {
        headers: {
          'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
        },
        timeout: 5000
      }
    );
    
    return res.json({
      total_colaboradores: response.data.total || 0,
      colaboradores: response.data.registros || []
    });
    
  } catch (error) {
    return res.status(500).json({ 
      erro: error.message,
      detalhes: error.response?.data 
    });
  }
});

// Testar endpoints alternativos de OS
app.get('/api/debug/test-ixc-endpoints-alternativos', async (req, res) => {
  const axios = require('axios');
  
  try {
    const integracao = await db('integracao_ixc')
      .where('tenant_id', 5)
      .first();
    
    if (!integracao) {
      return res.json({ error: 'Integração não configurada' });
    }
    
    // Testar variações de endpoints
    const endpoints = [
      'su_oss_chamado',
      'su_chamado',
      'chamado',
      'chamados',
      'ordem',
      'ordens',
      'su_ordem',
      'su_ordens',
      'ticket',
      'tickets',
      'su_ticket',
      'atendimento',
      'atendimentos',
      'su_atendimento',
      'su_atendimentos',
      'os',
      'oss',
      'su_os',
      'su_oss'
    ];
    
    const resultados = [];
    
    for (const endpoint of endpoints) {
      try {
        const params = new URLSearchParams({
          qtype: 'id',
          query: '',
          oper: '!=',
          page: '1',
          rp: '5'
        });

        const response = await axios.post(
          `${integracao.url_api}/${endpoint}`,
          params.toString(),
          {
            headers: {
              'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
              'Content-Type': 'application/x-www-form-urlencoded',
              'ixcsoft': 'listar'
            },
            timeout: 5000
          }
        );
        
        const total = response.data.total || 0;
        
        if (total > 0) {
          resultados.push({
            endpoint,
            status: 'OK',
            total: total,
            registros: response.data.registros?.length || 0,
            campos: response.data.registros?.[0] ? Object.keys(response.data.registros[0]) : [],
            exemplo: response.data.registros?.[0] || null
          });
        } else {
          resultados.push({
            endpoint,
            status: 'OK_MAS_VAZIO',
            total: 0
          });
        }
        
      } catch (error) {
        if (error.response?.status === 404) {
          resultados.push({
            endpoint,
            status: '404_NAO_EXISTE'
          });
        } else {
          resultados.push({
            endpoint,
            status: 'ERRO',
            erro: error.response?.status || error.message
          });
        }
      }
      
      // Pausa entre requests
      await new Promise(resolve => setTimeout(resolve, 300));
    }
    
    // Ordenar: endpoints com dados primeiro
    resultados.sort((a, b) => {
      if (a.total > 0 && b.total === 0) return -1;
      if (a.total === 0 && b.total > 0) return 1;
      return 0;
    });
    
    return res.json({
      url_api: integracao.url_api,
      total_testados: endpoints.length,
      com_dados: resultados.filter(r => r.total > 0).length,
      resultados
    });
    
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// Testar com GET + JSON (igual o suporte usou)
app.get('/api/debug/test-ixc-get-json', async (req, res) => {
  const axios = require('axios');
  
  try {
    const integracao = await db('integracao_ixc')
      .where('tenant_id', 5)
      .first();
    
    // Usar GET com JSON (como o suporte fez)
    const response = await axios.get(`${integracao.url_api}/cliente`, {
      headers: {
        'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
        'Content-Type': 'application/json',
        'ixcsoft': 'listar'
      },
      data: {
        qtype: 'cliente.id',
        query: '1',
        oper: '>=',
        page: '1',
        rp: '19',
        sortname: 'cliente.id',
        sortorder: 'desc'
      }
    });
    
    return res.json({
      total: response.data.total || 0,
      registros: response.data.registros?.length || 0,
      dados: response.data
    });
    
  } catch (error) {
    return res.status(500).json({ 
      erro: error.message,
      detalhes: error.response?.data 
    });
  }
});

// Testar busca de TODAS as OSs (sem filtro)
app.get('/api/debug/test-ixc-todas-os', async (req, res) => {
  const axios = require('axios');
  
  try {
    const integracao = await db('integracao_ixc')
      .where('tenant_id', 5)
      .first();
    
    if (!integracao) {
      return res.status(404).json({ error: 'Integração não configurada' });
    }
    
    console.log('🔍 Buscando TODAS as OSs (sem filtro de técnico)...');
    
    // Buscar SEM filtro de técnico
const params = new URLSearchParams({
  qtype: 'id',
  query: '',
  oper: '!=',
  page: '1',
  rp: '50',
  sortname: 'id',
  sortorder: 'desc'
});

const response = await axios.post(`${integracao.url_api}/su_oss_chamado`, 
  params.toString(),
  {
    headers: {
      'Authorization': `Basic ${Buffer.from(integracao.token_api).toString('base64')}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'ixcsoft': 'listar'
    },
    timeout: 5000
  }
);
    
    const oss = response.data.registros || [];
    
    console.log(`✅ ${oss.length} OSs encontradas no total`);
    
    // Mostrar as 5 mais recentes
    const recentes = oss.slice(0, 5).map(os => ({
      id: os.id,
      protocolo: os.protocolo,
      cliente: os.cliente_razao || os.razao,
      tecnico_id: os.id_responsavel || os.id_tecnico,
      tecnico_nome: os.responsavel || os.tecnico,
      setor: os.setor || os.id_setor,
      status: os.status
    }));
    
    return res.status(200).json({
      total: response.data.total || 0,
      encontradas: oss.length,
      os_recentes: recentes
    });
    
  } catch (error) {
    console.error('❌ Erro:', error.message);
    return res.status(500).json({ 
      error: error.message,
      detalhes: error.response?.data 
    });
  }
});

// Descobrir IP REAL do Railway AGORA
app.get('/api/debug/meu-ip-agora', async (req, res) => {
  const axios = require('axios');
  
  try {
    const ipPublico = await axios.get('https://api.ipify.org?format=json');
    
    return res.json({
      ip_atual_railway: ipPublico.data.ip,
      data_hora: new Date().toISOString()
    });
  } catch (error) {
    return res.json({ erro: error.message });
  }
});
/* Rota para forçar sincronização de todas as empresas via debug sem token necessario agora 
app.get('/api/debug/force-sync', async (req, res) => {
  try {
    console.log('🚀 === SYNC FORÇADO VIA DEBUG ===');
    
    // Chamar sincronizador
    const SincronizadorIXC = require('./services/SincronizadorIXC');
    const sincronizador = new SincronizadorIXC();
    await sincronizador.sincronizarTodasEmpresas();
    
    res.json({
      success: true,
      message: 'Sincronização executada'
    });
  } catch (error) {
    console.error('❌ Erro:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
*/
// Rota para forçar sincronização de todas as empresas
  app.get('/api/sync/force', authMiddleware, async (req, res) => {
  try {
    console.log('🚀 Sincronização forçada via GET');
    
    // Chamar função de sincronização
    // (ajuste conforme sua implementação)
    const resultado = await sincronizarTodasEmpresas();
    
    res.json({
      success: true,
      message: 'Sincronização executada',
      data: resultado
    });
  } catch (error) {
    console.error('❌ Erro ao forçar sync:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
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
    })



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