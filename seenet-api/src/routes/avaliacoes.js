const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { db } = require('../config/database');
const auditService = require('../services/auditService');
const logger = require('../config/logger');

const router = express.Router();

// ========== CRIAR AVALIAÇÃO ==========
router.post('/', [
  body('titulo').optional().trim().isLength({ max: 255 }),
  body('descricao').optional().trim().isLength({ max: 1000 }),
], async (req, res) => {
  try {
    console.log('📊 ========== DEBUG CRIAR AVALIAÇÃO ==========');
    console.log('📦 req.body:', req.body);
    console.log('👤 req.user:', req.user);
    console.log('🏢 req.tenantId:', req.tenantId);
    console.log('🏷️  req.tenantCode:', req.tenantCode);
    console.log('===============================================');

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('❌ Erros de validação:', errors.array());
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { titulo, descricao } = req.body;

    // ✅ Verificar se req.user e req.tenantId existem
    if (!req.user || !req.user.id) {
      console.log('❌ ERRO: req.user não está definido!');
      return res.status(401).json({ error: 'Usuário não autenticado' });
    }

    if (!req.tenantId) {
      console.log('❌ ERRO: req.tenantId não está definido!');
      return res.status(401).json({ error: 'Tenant não identificado' });
    }

    const dadosAvaliacao = {
      tenant_id: req.tenantId,
      tecnico_id: req.user.id,
      titulo: titulo || `Avaliação ${new Date().toLocaleString('pt-BR')}`,
      descricao: descricao || null,
      status: 'em_andamento',
      data_inicio: new Date().toISOString(),
      data_criacao: new Date().toISOString(),
    };

    console.log('💾 Tentando inserir avaliação:', dadosAvaliacao);

    const [avaliacaoId] = await db('avaliacoes').insert(dadosAvaliacao);

    console.log('✅ Avaliação criada com ID:', avaliacaoId);

    // ✅ Tentar log de auditoria (com tratamento de erro separado)
    try {
      await auditService.log({
        action: 'EVALUATION_STARTED',
        usuario_id: req.user.id,
        tenant_id: req.tenantId,
        tabela_afetada: 'avaliacoes',
        registro_id: avaliacaoId,
        details: `Avaliação iniciada: ${titulo}`,
        ip_address: req.ip,
      });
      console.log('✅ Log de auditoria salvo');
    } catch (auditError) {
      console.log('⚠️ Erro ao salvar log de auditoria (continuando):', auditError.message);
      // Não impedir a criação da avaliação se o log falhar
    }

    logger.info(`✅ Avaliação criada: ${avaliacaoId} (Tenant: ${req.tenantCode})`);

    res.status(201).json({
      success: true,
      message: 'Avaliação criada com sucesso',
      data: {
        id: avaliacaoId,
      }
    });
  } catch (error) {
    console.log('❌ ========== ERRO CRÍTICO ==========');
    console.log('Mensagem:', error.message);
    console.log('Stack:', error.stack);
    console.log('Código:', error.code);
    console.log('=====================================');
    
    logger.error('Erro ao criar avaliação:', error);
    
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

    // Verificar se avaliação pertence ao tenant e técnico
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

    try {
      await auditService.log({
        action: 'EVALUATION_COMPLETED',
        usuario_id: req.user.id,
        tenant_id: req.tenantId,
        tabela_afetada: 'avaliacoes',
        registro_id: avaliacaoId,
        details: 'Avaliação finalizada',
        ip_address: req.ip,
      });
    } catch (auditError) {
      console.log('⚠️ Erro ao salvar log de auditoria:', auditError.message);
    }

    logger.info(`✅ Avaliação finalizada: ${avaliacaoId}`);

    res.json({ 
      success: true,
      message: 'Avaliação finalizada com sucesso' 
    });
  } catch (error) {
    logger.error('Erro ao finalizar avaliação:', error);
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
      success: true,
      data: {
        avaliacoes,
        pagination: {
          page,
          limit,
          total: total.count,
          pages: Math.ceil(total.count / limit),
        },
      }
    });
  } catch (error) {
    logger.error('Erro ao listar avaliações:', error);
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

    res.json({ 
      success: true,
      data: { avaliacao } 
    });
  } catch (error) {
    logger.error('Erro ao buscar avaliação:', error);
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

    console.log(`📊 Salvando respostas - Avaliação: ${avaliacaoId}, Checkmarks: ${checkmarks_marcados.length}`);

    // Verificar se avaliação pertence ao tenant
    const avaliacao = await db('avaliacoes')
      .where('id', avaliacaoId)
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id)
      .first();

    if (!avaliacao) {
      return res.status(404).json({ error: 'Avaliação não encontrada' });
    }

    // Inserir respostas
    for (const checkmarkId of checkmarks_marcados) {
      await db('respostas_checkmark').insert({
        avaliacao_id: avaliacaoId,
        checkmark_id: checkmarkId,
        marcado: true,
        data_resposta: new Date().toISOString(),
      }).onConflict(['avaliacao_id', 'checkmark_id']).merge();
    }

    logger.info(`✅ Respostas salvas para avaliação ${avaliacaoId}`);

    res.json({
      success: true,
      message: 'Respostas salvas com sucesso',
      data: {
        total: checkmarks_marcados.length,
      }
    });
  } catch (error) {
    console.log('❌ Erro ao salvar respostas:', error);
    logger.error('Erro ao salvar respostas:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

module.exports = router;