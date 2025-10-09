const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { db } = require('../config/database');
const authMiddleware = require('../middleware/auth');
const auditService = require('../services/auditService');
const logger = require('../config/logger');

const router = express.Router();

// ✅ APLICAR MIDDLEWARE EM TODAS AS ROTAS
router.use(authMiddleware);

// ========== CRIAR AVALIAÇÃO ==========
router.post('/', [
  body('titulo').optional().trim().isLength({ max: 255 }),
  body('descricao').optional().trim().isLength({ max: 1000 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { titulo, descricao } = req.body;

    // ✅ CORREÇÃO: .returning() retorna array [id], precisamos do primeiro elemento
    const result = await db('avaliacoes').insert({
      tenant_id: req.tenantId,
      tecnico_id: req.user.id,
      titulo: titulo || `Avaliação ${new Date().toLocaleString('pt-BR')}`,
      descricao,
      status: 'em_andamento',
      data_inicio: new Date().toISOString(),
      data_criacao: new Date().toISOString(),
    }).returning('id');
    
    // ✅ Extrair o ID corretamente (pode ser [123] ou [{id: 123}])
    const avaliacaoId = Array.isArray(result) 
      ? (typeof result[0] === 'object' ? result[0].id : result[0])
      : result;

    logger.info(`✅ Avaliação criada: ${avaliacaoId} (Tenant: ${req.tenantCode})`);

    await auditService.log({
      action: 'EVALUATION_STARTED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'avaliacoes',
      registro_id: avaliacaoId,
      details: `Avaliação iniciada: ${titulo || 'Sem título'}`,
      ip_address: req.ip,
    });

    // ✅ IMPORTANTE: Retornar o ID como número inteiro
    res.status(201).json({
      message: 'Avaliação criada com sucesso',
      id: parseInt(avaliacaoId), // Garantir que é número
    });
  } catch (error) {
    logger.error('❌ Erro ao criar avaliação:', error);
    logger.error('Stack:', error.stack);
    res.status(500).json({ 
      error: 'Erro interno do servidor',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// ========== FINALIZAR AVALIAÇÃO ==========
router.put('/:avaliacaoId/finalizar', async (req, res) => {
  try {
    const { avaliacaoId } = req.params;

    const avaliacao = await db('avaliacoes')
      .where('id', avaliacaoId)
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id)
      .first();

    if (!avaliacao) {
      return res.status(404).json({ error: 'Avaliação não encontrada' });
    }

    await db('avaliacoes')
      .where('id', avaliacaoId)
      .update({
        status: 'concluida',
        data_conclusao: new Date().toISOString(),
        data_atualizacao: new Date().toISOString(),
      });

    await auditService.log({
      action: 'EVALUATION_COMPLETED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'avaliacoes',
      registro_id: avaliacaoId,
      details: 'Avaliação finalizada',
      ip_address: req.ip,
    });

    logger.info(`✅ Avaliação finalizada: ${avaliacaoId}`);

    res.json({ message: 'Avaliação finalizada com sucesso' });
  } catch (error) {
    logger.error('❌ Erro ao finalizar avaliação:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LISTAR AVALIAÇÕES DO TÉCNICO ==========
router.get('/minhas', [
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('status').optional().isIn(['em_andamento', 'concluida', 'cancelada']),
], async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    
    let query = db('avaliacoes')
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id);

    if (req.query.status) {
      query = query.where('status', req.query.status);
    }

    const totalQuery = query.clone();
    const total = await totalQuery.count('id as count').first();

    const avaliacoes = await query
      .orderBy('data_criacao', 'desc')
      .limit(limit)
      .offset(offset)
      .select(
        'id',
        'titulo',
        'descricao',
        'status',
        'data_inicio',
        'data_conclusao',
        'data_criacao'
      );

    res.json({
      avaliacoes,
      pagination: {
        page,
        limit,
        total: parseInt(total.count),
        pages: Math.ceil(parseInt(total.count) / limit),
      },
    });
  } catch (error) {
    logger.error('❌ Erro ao listar avaliações:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== VER AVALIAÇÃO ESPECÍFICA ==========
router.get('/:avaliacaoId', async (req, res) => {
  try {
    const { avaliacaoId } = req.params;

    const avaliacao = await db('avaliacoes')
      .where('id', avaliacaoId)
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id)
      .first();

    if (!avaliacao) {
      return res.status(404).json({ error: 'Avaliação não encontrada' });
    }

    res.json({ avaliacao });
  } catch (error) {
    logger.error('❌ Erro ao buscar avaliação:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== SALVAR RESPOSTAS DE CHECKMARKS ==========
router.post('/:avaliacaoId/respostas', [
  body('checkmarks_marcados').isArray({ min: 1 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { avaliacaoId } = req.params;
    const { checkmarks_marcados } = req.body;

    const avaliacao = await db('avaliacoes')
      .where('id', avaliacaoId)
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id)
      .first();

    if (!avaliacao) {
      return res.status(404).json({ error: 'Avaliação não encontrada' });
    }

    // ✅ Usar transação para consistência
    await db.transaction(async (trx) => {
      for (const checkmarkId of checkmarks_marcados) {
        await trx('respostas_checkmark')
          .insert({
            avaliacao_id: avaliacaoId,
            checkmark_id: checkmarkId,
            marcado: true,
            data_resposta: new Date().toISOString(),
          })
          .onConflict(['avaliacao_id', 'checkmark_id'])
          .merge();
      }
    });

    logger.info(`✅ ${checkmarks_marcados.length} respostas salvas para avaliação ${avaliacaoId}`);

    res.json({
      message: 'Respostas salvas com sucesso',
      total: checkmarks_marcados.length,
    });
  } catch (error) {
    logger.error('❌ Erro ao salvar respostas:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

module.exports = router;