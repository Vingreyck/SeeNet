// routes/diagnostics.js - ROTA CORRIGIDA E COMPLETA
const express = require('express');
const { body, validationResult } = require('express-validator');
const { db } = require('../config/database');
const geminiService = require('../services/geminiService');
const authMiddleware = require('../middleware/auth');
const logger = require('../config/logger');

const router = express.Router();

// ========== APLICAR AUTENTICAÇÃO EM TODAS AS ROTAS ==========
router.use(authMiddleware);

// ========== GERAR DIAGNÓSTICO ==========
router.post('/gerar', [
  body('avaliacao_id').isInt({ min: 1 }).withMessage('ID da avaliação inválido'),
  body('categoria_id').isInt({ min: 1 }).withMessage('ID da categoria inválido'),
  body('checkmarks_marcados')
    .isArray({ min: 1 })
    .withMessage('Deve marcar pelo menos um checkmark')
], async (req, res) => {
  const requestId = `DIAG-${Date.now()}`;
  
  try {
    logger.info(`[${requestId}] 🚀 Iniciando geração de diagnóstico`);
    logger.info(`[${requestId}] Tenant: ${req.tenantCode} (ID: ${req.tenantId})`);
    logger.info(`[${requestId}] Usuário: ${req.user.nome} (ID: ${req.user.id})`);

    // Validar entrada
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      logger.warn(`[${requestId}] ❌ Validação falhou:`, errors.array());
      return res.status(400).json({ 
        success: false, 
        error: 'Dados inválidos', 
        details: errors.array() 
      });
    }

    const { avaliacao_id, categoria_id, checkmarks_marcados } = req.body;

    logger.info(`[${requestId}] Dados recebidos:`, {
      avaliacao_id,
      categoria_id,
      checkmarks_count: checkmarks_marcados.length,
      checkmarks_ids: checkmarks_marcados
    });

    // Verificar avaliação
    const avaliacao = await db('avaliacoes')
      .where('id', avaliacao_id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!avaliacao) {
      logger.warn(`[${requestId}] ❌ Avaliação ${avaliacao_id} não encontrada para tenant ${req.tenantId}`);
      return res.status(404).json({ 
        success: false, 
        error: 'Avaliação não encontrada' 
      });
    }

    logger.info(`[${requestId}] ✅ Avaliação encontrada: "${avaliacao.titulo}"`);

    // Buscar checkmarks
    const checkmarks = await db('checkmarks')
      .whereIn('id', checkmarks_marcados)
      .where('tenant_id', req.tenantId)
      .select('id', 'titulo', 'descricao', 'prompt_chatgpt');

    if (checkmarks.length === 0) {
      logger.warn(`[${requestId}] ❌ Nenhum checkmark encontrado`);
      return res.status(400).json({ 
        success: false, 
        error: 'Checkmarks não encontrados' 
      });
    }

    if (checkmarks.length !== checkmarks_marcados.length) {
      logger.warn(`[${requestId}] ⚠️ Alguns checkmarks não foram encontrados (esperado: ${checkmarks_marcados.length}, encontrado: ${checkmarks.length})`);
    }

    logger.info(`[${requestId}] ✅ ${checkmarks.length} checkmarks carregados`);

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

    logger.info(`[${requestId}] 📝 Prompt montado (${prompt.length} caracteres)`);

    // Gerar com Gemini
    let resposta;
    let statusApi = 'sucesso';
    let modeloIa = 'gemini-2.0-flash';
    let erroApi = null;
    
    try {
      logger.info(`[${requestId}] 🤖 Enviando para Gemini...`);
      
      // ✅ ADICIONAR TIMEOUT E LOG DETALHADO
      const startTime = Date.now();
      resposta = await Promise.race([
        geminiService.gerarDiagnostico(prompt),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Timeout Gemini (30s)')), 30000)
        )
      ]);
      const duration = Date.now() - startTime;
      
      if (!resposta) {
        throw new Error('Gemini retornou resposta vazia');
      }
      
      logger.info(`[${requestId}] ✅ Resposta recebida do Gemini em ${duration}ms`);
      logger.info(`[${requestId}] Resposta: ${resposta.length} caracteres`);
      
    } catch (geminiError) {
      logger.error(`[${requestId}] ❌ Erro no Gemini:`, {
        error: geminiError.message,
        stack: geminiError.stack
      });
      
      statusApi = 'erro';
      modeloIa = 'fallback';
      erroApi = geminiError.message;
      
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
⚠️ Este diagnóstico foi gerado em modo fallback devido à indisponibilidade da IA.
Erro: ${geminiError.message}`;
      
      logger.info(`[${requestId}] 🔄 Usando fallback`);
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

    logger.info(`[${requestId}] 💾 Salvando diagnóstico no banco...`);

    // Salvar no banco
    const [diagnosticoId] = await db('diagnosticos').insert({
      tenant_id: req.tenantId,
      avaliacao_id,
      categoria_id,
      prompt_enviado: prompt,
      resposta_chatgpt: resposta,
      resumo_diagnostico: resumo,
      status_api: statusApi,
      erro_api: erroApi,
      modelo_ia: modeloIa,
      tokens_utilizados: tokensUtilizados,
      data_criacao: new Date().toISOString()
    });

    logger.info(`[${requestId}] ✅ Diagnóstico ${diagnosticoId} salvo com sucesso!`);
    logger.info(`[${requestId}] Status: ${statusApi}, Modelo: ${modeloIa}, Tokens: ${tokensUtilizados}`);

    return res.json({
      success: true,
      message: 'Diagnóstico gerado com sucesso',
      data: {
        id: diagnosticoId,
        resumo: resumo,
        resposta: resposta,
        status: statusApi,
        modelo: modeloIa,
        tokens_utilizados: tokensUtilizados
      }
    });

  } catch (error) {
    logger.error(`[${requestId}] ❌ ERRO CRÍTICO ao gerar diagnóstico:`, {
      error: error.message,
      stack: error.stack,
      tenant: req.tenantCode,
      user: req.user.id
    });
    
    return res.status(500).json({ 
      success: false, 
      error: 'Erro interno do servidor',
      details: process.env.NODE_ENV === 'production' ? undefined : error.message,
      requestId: requestId
    });
  }
});

// ========== LISTAR DIAGNÓSTICOS DE UMA AVALIAÇÃO ==========
router.get('/avaliacao/:avaliacaoId', async (req, res) => {
  try {
    const { avaliacaoId } = req.params;

    logger.info(`Listando diagnósticos da avaliação ${avaliacaoId} - Tenant: ${req.tenantCode}`);

    // Verificar se avaliação pertence ao tenant
    const avaliacao = await db('avaliacoes')
      .where('id', avaliacaoId)
      .where('tenant_id', req.tenantId)
      .first();

    if (!avaliacao) {
      return res.status(404).json({ 
        success: false, 
        error: 'Avaliação não encontrada' 
      });
    }

    const diagnosticos = await db('diagnosticos')
      .where('tenant_id', req.tenantId)
      .where('avaliacao_id', avaliacaoId)
      .orderBy('data_criacao', 'desc')
      .select(
        'id',
        'resumo_diagnostico',
        'status_api',
        'modelo_ia',
        'tokens_utilizados',
        'data_criacao'
      );

    res.json({ 
      success: true, 
      data: { diagnosticos } 
    });
    
  } catch (error) {
    logger.error('Erro ao listar diagnósticos:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Erro interno do servidor' 
    });
  }
});

// ========== VER DIAGNÓSTICO COMPLETO ==========
router.get('/:diagnosticoId', async (req, res) => {
  try {
    const { diagnosticoId } = req.params;

    const diagnostico = await db('diagnosticos')
      .where('id', diagnosticoId)
      .where('tenant_id', req.tenantId)
      .first();

    if (!diagnostico) {
      return res.status(404).json({ 
        success: false, 
        error: 'Diagnóstico não encontrado' 
      });
    }

    res.json({ 
      success: true, 
      data: { diagnostico } 
    });
    
  } catch (error) {
    logger.error('Erro ao buscar diagnóstico:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Erro interno do servidor' 
    });
  }
});

module.exports = router;