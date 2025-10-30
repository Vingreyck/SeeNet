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
      .select('id', 'titulo', 'descricao', 'prompt_gemini', 'ativo', 'ordem');

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
  body('prompt_gemini').trim().isLength({ min: 10, max: 5000 }),
  body('ordem').optional().isInt({ min: 0 })
], async (req, res) => {
  console.log('🔵 === INICIANDO CRIAÇÃO DE CHECKMARK ===');
  
  try {
    // 1. Validação
    console.log('🔍 Etapa 1: Validando dados...');
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('❌ Validação falhou:', JSON.stringify(errors.array(), null, 2));
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }
    console.log('✅ Validação OK');

    // 2. Extrair dados
    console.log('🔍 Etapa 2: Extraindo dados do body...');
    const { categoria_id, titulo, descricao, prompt_gemini, ordem = 0 } = req.body;
    console.log('📦 Dados extraídos:', {
      categoria_id,
      titulo,
      descricao,
      prompt_gemini_length: prompt_gemini?.length,
      ordem,
      tenant_id: req.tenantId,
      user_id: req.user?.id
    });

    // 3. Verificar categoria
    console.log('🔍 Etapa 3: Verificando categoria...');
    const categoria = await db('categorias_checkmark')
      .where('id', categoria_id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!categoria) {
      console.log('❌ Categoria não encontrada:', { categoria_id, tenant_id: req.tenantId });
      return res.status(400).json({ error: 'Categoria não encontrada ou não pertence a esta empresa' });
    }
    console.log('✅ Categoria encontrada:', categoria.nome);

    // 4. Inserir no banco
    console.log('🔍 Etapa 4: Inserindo no banco...');
    const insertData = {
      tenant_id: req.tenantId,
      categoria_id,
      titulo,
      descricao,
      prompt_gemini,
      ordem,
      ativo: true,
      data_criacao: new Date().toISOString()
    };
    console.log('📝 Dados para inserção:', insertData);

    let checkmarkId;
    try {
      const result = await db('checkmarks').insert(insertData);
      checkmarkId = result[0];
      console.log('✅ Checkmark inserido, ID:', checkmarkId);
    } catch (dbError) {
      console.error('❌ ERRO NO BANCO DE DADOS:');
      console.error('   Mensagem:', dbError.message);
      console.error('   Código:', dbError.code);
      console.error('   Stack:', dbError.stack);
      throw dbError;
    }

    // 5. Log de auditoria
    console.log('🔍 Etapa 5: Registrando auditoria...');
    try {
      await auditService.log({
        action: 'CHECKMARK_CREATED',
        usuario_id: req.user.id,
        tenant_id: req.tenantId,
        tabela_afetada: 'checkmarks',
        registro_id: checkmarkId,
        dados_novos: { titulo, categoria_id, prompt_gemini },
        ip_address: req.ip
      });
      console.log('✅ Auditoria registrada');
    } catch (auditError) {
      console.error('⚠️ Erro na auditoria (não crítico):', auditError.message);
    }

    // 6. Sucesso
    logger.info(`✅ Checkmark criado: ${titulo} (ID: ${checkmarkId}, Tenant: ${req.tenantCode})`);
    console.log('🟢 === CHECKMARK CRIADO COM SUCESSO ===');

    res.status(201).json({
      message: 'Checkmark criado com sucesso',
      id: checkmarkId
    });

  } catch (error) {
    console.error('🔴 === ERRO FATAL AO CRIAR CHECKMARK ===');
    console.error('Tipo do erro:', error.constructor.name);
    console.error('Mensagem:', error.message);
    console.error('Código:', error.code);
    console.error('Stack completo:', error.stack);
    console.error('==========================================');
    
    logger.error('Erro ao criar checkmark:', error);
    
    res.status(500).json({ 
      error: 'Erro interno do servidor',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// ========== EDITAR CHECKMARK - VERSÃO CORRIGIDA ==========
router.put('/checkmarks/:id', adminMiddleware, [
  body('titulo').optional().trim().isLength({ min: 2, max: 255 }),
  body('descricao').optional().trim().isLength({ max: 1000 }),
  body('prompt_gemini').optional().trim().isLength({ min: 10, max: 5000 }),
  body('ativo').optional().isBoolean(),
  body('ordem').optional().isInt({ min: 0 })
], async (req, res) => {
  console.log('🔵 === EDITANDO CHECKMARK ===');
  
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('❌ Validação falhou:', errors.array());
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { id } = req.params;
    const { titulo, descricao, prompt_gemini, ativo, ordem } = req.body;

    console.log('📥 Dados recebidos:');
    console.log('   ID:', id);
    console.log('   ativo:', ativo, '(tipo:', typeof ativo, ')');
    console.log('   req.body:', JSON.stringify(req.body, null, 2));

    // Verificar se checkmark pertence ao tenant
    const checkmark = await db('checkmarks')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .first();

    if (!checkmark) {
      console.log('❌ Checkmark não encontrado:', id);
      return res.status(404).json({ error: 'Checkmark não encontrado' });
    }

    console.log('✅ Status ANTES da atualização:', checkmark.ativo);

    // ✅ IMPORTANTE: Montar objeto garantindo que campos booleanos sejam explícitos
    const updateData = {};
    if (titulo !== undefined) updateData.titulo = titulo;
    if (descricao !== undefined) updateData.descricao = descricao;
    if (prompt_gemini !== undefined) updateData.prompt_gemini = prompt_gemini;
    
    // ✅ CRÍTICO: Garantir que boolean seja tratado corretamente
    if (ativo !== undefined) {
      updateData.ativo = Boolean(ativo);  // Forçar conversão para boolean
      console.log('⚠️ Campo ativo será atualizado para:', updateData.ativo);
    }
    
    if (ordem !== undefined) updateData.ordem = ordem;

    console.log('📝 updateData:', JSON.stringify(updateData, null, 2));

    // ✅ EXECUTAR UPDATE com returning para PostgreSQL
    const result = await db('checkmarks')
      .where('id', id)
      .where('tenant_id', req.tenantId)
      .update(updateData)
      .returning('*');  // ✅ IMPORTANTE: PostgreSQL precisa disso

    console.log('✅ Resultado do UPDATE:', result);
    console.log('   Linhas retornadas:', result.length);
    
    if (result.length > 0) {
      console.log('   Status DEPOIS (do returning):', result[0].ativo);
    }

    // ✅ VERIFICAR NOVAMENTE no banco
    const checkmarkAtualizado = await db('checkmarks')
      .where('id', id)
      .first();

    console.log('🔍 Verificação final no banco:');
    console.log('   Status atual:', checkmarkAtualizado.ativo);
    console.log('   Título atual:', checkmarkAtualizado.titulo);

    // ✅ Se ainda não mudou, há um problema de trigger ou constraint
    if (ativo !== undefined && checkmarkAtualizado.ativo !== ativo) {
      console.error('🚨 ALERTA: Valor não foi atualizado no banco!');
      console.error('   Esperado:', ativo);
      console.error('   Obtido:', checkmarkAtualizado.ativo);
    }

    // Log de auditoria
    try {
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
    } catch (auditError) {
      console.error('⚠️ Erro na auditoria:', auditError.message);
    }

    logger.info(`✅ Checkmark atualizado: ${id}`);
    console.log('🟢 === EDIÇÃO CONCLUÍDA ===\n');

    res.json({ 
      message: 'Checkmark atualizado com sucesso',
      // ✅ Retornar o dado atualizado para o Flutter
      checkmark: {
        id: checkmarkAtualizado.id,
        ativo: checkmarkAtualizado.ativo,
        titulo: checkmarkAtualizado.titulo
      }
    });
  } catch (error) {
    console.error('🔴 === ERRO AO EDITAR ===');
    console.error('Mensagem:', error.message);
    console.error('Stack:', error.stack);
    
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