const express = require('express');
const { body, validationResult } = require('express-validator');
const { db } = require('../config/database');
const geminiService = require('../services/geminiService');
const auditService = require('../services/auditService');
const logger = require('../config/logger');
const Tenant = require('../models/Tenant');

const router = express.Router();

// ========== GERAR DIAGNÓSTICO ==========
router.post('/gerar', [
  body('avaliacao_id').isInt({ min: 1 }),
  body('categoria_id').isInt({ min: 1 }),
  body('checkmarks_marcados').isArray({ min: 1 }).withMessage('Deve marcar pelo menos um checkmark')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { avaliacao_id, categoria_id, checkmarks_marcados } = req.body;

    // Verificar limites do tenant
    const canGenerate = await Tenant.checkLimits(req.tenantId, 'api_calls');
    if (!canGenerate) {
      return res.status(429).json({ 
        error: 'Limite de diagnósticos do plano atingido' 
      });
    }

    // Verificar se avaliação pertence ao tenant
    const avaliacao = await db('avaliacoes')
      .where('id', avaliacao_id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!avaliacao) {
      return res.status(404).json({ error: 'Avaliação não encontrada' });
    }

    // Buscar checkmarks selecionados
    const checkmarks = await db('checkmarks')
      .whereIn('id', checkmarks_marcados)
      .where('tenant_id', req.tenantId)
      .select('id', 'titulo', 'descricao', 'prompt_chatgpt');

    if (checkmarks.length !== checkmarks_marcados.length) {
      return res.status(400).json({ error: 'Alguns checkmarks não foram encontrados' });
    }

    // Montar prompt
    const prompt = montarPromptDiagnostico(checkmarks);

    try {
      // Gerar diagnóstico com Gemini
      const resposta = await geminiService.gerarDiagnostico(prompt);
      
      if (!resposta) {
        throw new Error('Falha na API do Gemini');
      }

      // Salvar diagnóstico
      const [diagnosticoId] = await db('diagnosticos').insert({
        tenant_id: req.tenantId,
        avaliacao_id,
        categoria_id,
        prompt_enviado: prompt,
        resposta_chatgpt: resposta,
        resumo_diagnostico: extrairResumo(resposta),
        status_api: 'sucesso',
        modelo_ia: 'gemini-2.0-flash',
        tokens_utilizados: contarTokens(prompt + resposta),
        data_criacao: new Date().toISOString()
      });

      // Log de auditoria
      await auditService.log({
        action: 'DIAGNOSTIC_GENERATED',
        usuario_id: req.user.id,
        tenant_id: req.tenantId,
        tabela_afetada: 'diagnosticos',
        registro_id: diagnosticoId,
        details: `Diagnóstico gerado para avaliação ${avaliacao_id}`,
        ip_address: req.ip
      });

      logger.info(`✅ Diagnóstico gerado: ${diagnosticoId} (Tenant: ${req.tenantCode})`);

      res.json({
        message: 'Diagnóstico gerado com sucesso',
        id: diagnosticoId,
        resumo: extrairResumo(resposta),
        tokens_utilizados: contarTokens(prompt + resposta)
      });

    } catch (apiError) {
      // Salvar erro no banco
      const [diagnosticoId] = await db('diagnosticos').insert({
        tenant_id: req.tenantId,
        avaliacao_id,
        categoria_id,
        prompt_enviado: prompt,
        resposta_chatgpt: gerarDiagnosticoFallback(checkmarks),
        resumo_diagnostico: 'Diagnóstico gerado em modo fallback',
        status_api: 'erro',
        erro_api: apiError.message,
        modelo_ia: 'fallback',
        data_criacao: new Date().toISOString()
      });

      logger.warn(`⚠️ Fallback de diagnóstico: ${diagnosticoId} (Tenant: ${req.tenantCode})`);

      res.json({
        message: 'Diagnóstico gerado (modo fallback)',
        id: diagnosticoId,
        warning: 'IA indisponível, diagnóstico básico gerado'
      });
    }

  } catch (error) {
    logger.error('Erro ao gerar diagnóstico:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LISTAR DIAGNÓSTICOS DE UMA AVALIAÇÃO ==========
router.get('/avaliacao/:avaliacaoId', async (req, res) => {
  try {
    const { avaliacaoId } = req.params;

    // Verificar se avaliação pertence ao tenant
    const avaliacao = await db('avaliacoes')
      .where('id', avaliacaoId)
      .where('tenant_id', req.tenantId)
      .first();

    if (!avaliacao) {
      return res.status(404).json({ error: 'Avaliação não encontrada' });
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

    res.json({ diagnosticos });
  } catch (error) {
    logger.error('Erro ao listar diagnósticos:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
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
      return res.status(404).json({ error: 'Diagnóstico não encontrado' });
    }

    res.json({ diagnostico });
  } catch (error) {
    logger.error('Erro ao buscar diagnóstico:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== FUNÇÕES AUXILIARES ==========
function montarPromptDiagnostico(checkmarks) {
  let prompt = "RELATÓRIO TÉCNICO DE PROBLEMAS IDENTIFICADOS:\n\n";
  
  checkmarks.forEach((checkmark, index) => {
    prompt += `PROBLEMA ${index + 1}:\n`;
    prompt += `• Título: ${checkmark.titulo}\n`;
    if (checkmark.descricao) {
      prompt += `• Descrição: ${checkmark.descricao}\n`;
    }
    prompt += `• Contexto técnico: ${checkmark.prompt_chatgpt}\n\n`;
  });
  
  prompt += "TAREFA:\n";
  prompt += "Analise os problemas listados acima e forneça um diagnóstico técnico completo. ";
  prompt += "Considere que pode haver correlação entre os problemas. ";
  prompt += "Forneça soluções práticas, começando pelas mais simples e eficazes.";
  
  return prompt;
}

function extrairResumo(resposta) {
  const linhas = resposta.split('\n');
  for (let linha of linhas) {
    if (linha.includes('DIAGNÓSTICO') || linha.includes('ANÁLISE')) {
      let resumo = linha.replace(/[🔍📊🎯*]/g, '').trim();
      return resumo.length > 120 ? resumo.substring(0, 120) + '...' : resumo;
    }
  }
  return resposta.length > 120 ? resposta.substring(0, 120) + '...' : resposta;
}

function contarTokens(texto) {
  // Estimativa simples: ~4 caracteres por token
  return Math.ceil(texto.length / 4);
}

function gerarDiagnosticoFallback(checkmarks) {
  const problemas = checkmarks.map(c => c.titulo).join(', ');
  return `🔧 **DIAGNÓSTICO TÉCNICO (MODO FALLBACK)**

📊 **PROBLEMAS IDENTIFICADOS:** ${problemas}

🛠️ **AÇÕES RECOMENDADAS:**
1. Reinicie todos os equipamentos (modem, roteador, dispositivos)
2. Verifique todas as conexões físicas e cabos
3. Teste a conectividade em diferentes dispositivos
4. Documente os resultados de cada teste

📞 **PRÓXIMOS PASSOS:**
• Execute as soluções na ordem apresentada
• Anote o que funcionou ou não funcionou
• Se problemas persistirem, entre em contato com suporte técnico

---
⚠️ Este diagnóstico foi gerado em modo fallback devido à indisponibilidade da IA.
Para diagnósticos mais detalhados, aguarde o restabelecimento do serviço.`;
}

module.exports = router;
