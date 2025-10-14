// routes/checkmark.js (ou checkmark.routes.js)
const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { db } = require('../config/database');
const authMiddleware = require('../middleware/auth');
const { adminMiddleware } = require('../middleware/auth');
const auditService = require('../services/auditService');
const logger = require('../config/logger');

const router = express.Router();
router.use(authMiddleware);

// ========== LISTAR CATEGORIAS ==========
router.get('/categorias', async (req, res) => {
  try {
    const categorias = await db('categorias_checkmark')
      .where('tenant_id', req.tenantId)
      .where('ativo', true)
      .orderBy('ordem')
      .select('id', 'nome', 'descricao', 'ordem');

    res.json({ categorias });
  } catch (error) {
    logger.error('Erro ao listar categorias:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LISTAR CHECKMARKS POR CATEGORIA ==========
router.get('/categoria/:categoriaId', [
  query('incluir_inativos').optional().isBoolean()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Parâmetros inválidos', details: errors.array() });
    }

    const { categoriaId } = req.params;
    const incluirInativos = req.query.incluir_inativos === 'true';

    // Verificar se categoria pertence ao tenant
    const categoria = await db('categorias_checkmark')
      .where('id', categoriaId)
      .where('tenant_id', req.tenantId)
      .first();

    if (!categoria) {
      return res.status(404).json({ error: 'Categoria não encontrada' });
    }

    let query = db('checkmarks')
      .where('tenant_id', req.tenantId)
      .where('categoria_id', categoriaId);

    if (!incluirInativos) {
      query = query.where('ativo', true);
    }

    const checkmarks = await query
      .orderBy('ordem')
      .select('id', 'titulo', 'descricao', 'prompt_chatgpt', 'ativo', 'ordem');

    res.json({ 
      categoria: categoria.nome,
      checkmarks 
    });
  } catch (error) {
    logger.error('Erro ao listar checkmarks:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== CRIAR CATEGORIA (ADMIN APENAS) ==========
router.post('/categorias', adminMiddleware, [
  body('nome').trim().isLength({ min: 2, max: 255 }).withMessage('Nome deve ter entre 2 e 255 caracteres'),
  body('descricao').optional().trim().isLength({ max: 1000 }),
  body('ordem').optional().isInt({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { nome, descricao, ordem = 0 } = req.body;

    // Verificar se já existe categoria com esse nome no tenant
    const existeCategoria = await db('categorias_checkmark')
      .where('tenant_id', req.tenantId)
      .where('nome', nome)
      .first();

    if (existeCategoria) {
      return res.status(400).json({ error: 'Já existe uma categoria com este nome' });
    }

    const [categoriaId] = await db('categorias_checkmark').insert({
      tenant_id: req.tenantId,
      nome,
      descricao,
      ordem,
      ativo: true,
      data_criacao: new Date().toISOString()
    });

    // Log de auditoria
    await auditService.log({
      action: 'CATEGORY_CREATED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'categorias_checkmark',
      registro_id: categoriaId,
      dados_novos: { nome, descricao, ordem },
      ip_address: req.ip
    });

    logger.info(`✅ Categoria criada: ${nome} (Tenant: ${req.tenantCode})`);

    res.status(201).json({
      message: 'Categoria criada com sucesso',
      id: categoriaId
    });
  } catch (error) {
    logger.error('Erro ao criar categoria:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== CRIAR CHECKMARK (ADMIN APENAS) ==========
router.post('/checkmarks', adminMiddleware, [
  body('categoria_id').isInt({ min: 1 }),
  body('titulo').trim().isLength({ min: 2, max: 255 }),
  body('descricao').optional().trim().isLength({ max: 1000 }),
  body('prompt_chatgpt').trim().isLength({ min: 10, max: 5000 }),
  body('ordem').optional().isInt({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { categoria_id, titulo, descricao, prompt_chatgpt, ordem = 0 } = req.body;

    // Verificar se categoria pertence ao tenant
    const categoria = await db('categorias_checkmark')
      .where('id', categoria_id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!categoria) {
      return res.status(400).json({ error: 'Categoria não encontrada ou não pertence a esta empresa' });
    }

    const [checkmarkId] = await db('checkmarks').insert({
      tenant_id: req.tenantId,
      categoria_id,
      titulo,
      descricao,
      prompt_chatgpt,
      ordem,
      ativo: true,
      data_criacao: new Date().toISOString()
    });

    // Log de auditoria
    await auditService.log({
      action: 'CHECKMARK_CREATED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'checkmarks',
      registro_id: checkmarkId,
      dados_novos: { titulo, categoria_id, prompt_chatgpt },
      ip_address: req.ip
    });

    logger.info(`✅ Checkmark criado: ${titulo} (Tenant: ${req.tenantCode})`);

    res.status(201).json({
      message: 'Checkmark criado com sucesso',
      id: checkmarkId
    });
  } catch (error) {
    logger.error('Erro ao criar checkmark:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== EDITAR CHECKMARK (ADMIN APENAS) ========== ✅ NOVO
router.put('/checkmarks/:id', adminMiddleware, [
  body('titulo').optional().trim().isLength({ min: 2, max: 255 }),
  body('descricao').optional().trim().isLength({ max: 1000 }),
  body('prompt_chatgpt').optional().trim().isLength({ min: 10, max: 5000 }),
  body('ativo').optional().isBoolean(),
  body('ordem').optional().isInt({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { id } = req.params;
    const { titulo, descricao, prompt_chatgpt, ativo, ordem } = req.body;

    // Verificar se checkmark pertence ao tenant
    const checkmark = await db('checkmarks')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!checkmark) {
      return res.status(404).json({ error: 'Checkmark não encontrado' });
    }

    // Montar objeto de atualização (só campos fornecidos)
    const updateData = {};
    if (titulo !== undefined) updateData.titulo = titulo;
    if (descricao !== undefined) updateData.descricao = descricao;
    if (prompt_chatgpt !== undefined) updateData.prompt_chatgpt = prompt_chatgpt;
    if (ativo !== undefined) updateData.ativo = ativo;
    if (ordem !== undefined) updateData.ordem = ordem;

    await db('checkmarks')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .update(updateData);

    // Log de auditoria
    await auditService.log({
      action: 'CHECKMARK_UPDATED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'checkmarks',
      registro_id: parseInt(id),
      dados_antigos: checkmark,
      dados_novos: updateData,
      ip_address: req.ip
    });

    logger.info(`✅ Checkmark atualizado: ${id} (Tenant: ${req.tenantCode})`);

    res.json({ message: 'Checkmark atualizado com sucesso' });
  } catch (error) {
    logger.error('Erro ao atualizar checkmark:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== DELETAR CHECKMARK (ADMIN APENAS) ========== ✅ NOVO
router.delete('/checkmarks/:id', adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    // Verificar se checkmark pertence ao tenant
    const checkmark = await db('checkmarks')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!checkmark) {
      return res.status(404).json({ error: 'Checkmark não encontrado' });
    }

    await db('checkmarks')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .delete();

    // Log de auditoria
    await auditService.log({
      action: 'CHECKMARK_DELETED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'checkmarks',
      registro_id: parseInt(id),
      dados_antigos: checkmark,
      ip_address: req.ip
    });

    logger.info(`✅ Checkmark deletado: ${id} (Tenant: ${req.tenantCode})`);

    res.json({ message: 'Checkmark removido com sucesso' });
  } catch (error) {
    logger.error('Erro ao deletar checkmark:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== EDITAR CATEGORIA (ADMIN APENAS) ========== ✅ NOVO
router.put('/categorias/:id', adminMiddleware, [
  body('nome').optional().trim().isLength({ min: 2, max: 255 }),
  body('descricao').optional().trim().isLength({ max: 1000 }),
  body('ordem').optional().isInt({ min: 0 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { id } = req.params;
    const { nome, descricao, ordem } = req.body;

    // Verificar se categoria pertence ao tenant
    const categoria = await db('categorias_checkmark')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!categoria) {
      return res.status(404).json({ error: 'Categoria não encontrada' });
    }

    const updateData = {};
    if (nome !== undefined) updateData.nome = nome;
    if (descricao !== undefined) updateData.descricao = descricao;
    if (ordem !== undefined) updateData.ordem = ordem;

    await db('categorias_checkmark')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .update(updateData);

    await auditService.log({
      action: 'CATEGORY_UPDATED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'categorias_checkmark',
      registro_id: parseInt(id),
      dados_antigos: categoria,
      dados_novos: updateData,
      ip_address: req.ip
    });

    logger.info(`✅ Categoria atualizada: ${id} (Tenant: ${req.tenantCode})`);

    res.json({ message: 'Categoria atualizada com sucesso' });
  } catch (error) {
    logger.error('Erro ao atualizar categoria:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== DELETAR CATEGORIA (ADMIN APENAS) ========== ✅ NOVO
router.delete('/categorias/:id', adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    // Verificar se categoria pertence ao tenant
    const categoria = await db('categorias_checkmark')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!categoria) {
      return res.status(404).json({ error: 'Categoria não encontrada' });
    }

    // Verificar se há checkmarks usando esta categoria
    const checkmarksCount = await db('checkmarks')
      .where('categoria_id', id)
      .where('tenant_id', req.tenantId)
      .count('* as total')
      .first();

    if (checkmarksCount && checkmarksCount.total > 0) {
      return res.status(400).json({ 
        error: 'Não é possível deletar categoria com checkmarks associados',
        details: `Existem ${checkmarksCount.total} checkmark(s) nesta categoria`
      });
    }

    await db('categorias_checkmark')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .delete();

    await auditService.log({
      action: 'CATEGORY_DELETED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'categorias_checkmark',
      registro_id: parseInt(id),
      dados_antigos: categoria,
      ip_address: req.ip
    });

    logger.info(`✅ Categoria deletada: ${id} (Tenant: ${req.tenantCode})`);

    res.json({ message: 'Categoria removida com sucesso' });
  } catch (error) {
    logger.error('Erro ao deletar categoria:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

module.exports = router;