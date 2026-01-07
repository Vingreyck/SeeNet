const express = require('express');
const router = express.Router();

console.log('\n🔥 === ARQUIVO routes/admin/categorias.js CARREGADO ===');
console.log('📍 Este log confirma que o arquivo foi lido pelo Node.js');

const { db } = require('../../config/database');

console.log('✅ Database importado:', typeof db);

const authMiddleware = require('../../middleware/auth');
const { adminMiddleware } = authMiddleware;

console.log('✅ Middlewares importados');

const { body, validationResult } = require('express-validator');

console.log('✅ express-validator importado');

// Aplicar middlewares
router.use((req, res, next) => {
  console.log('🔵 Middleware categorias atingido:', req.method, req.path);
  next();
});

router.use(authMiddleware);
router.use(adminMiddleware);

console.log('✅ Middlewares aplicados ao router');

// GET - Listar categorias
router.get('/', async (req, res) => {
  console.log('📥 === GET /admin/categorias EXECUTANDO ===');
  console.log('   User:', req.user?.email);
  console.log('   Tenant ID:', req.user?.tenant_id);
  
  try {
    const { tenant_id } = req.user;

    console.log('   🔍 Buscando categorias para tenant:', tenant_id);

    const categorias = await db('categorias_checkmark')
      .where({ tenant_id })
      .orderBy('ordem', 'asc')
      .select('*');

    console.log(`   ✅ ${categorias.length} categorias encontradas`);

    const categoriasComContagem = await Promise.all(
      categorias.map(async (cat) => {
        const result = await db('checkmarks')
          .where({ categoria_id: cat.id, tenant_id })
          .count('* as count')
          .first();

        return {
          ...cat,
          total_checkmarks: parseInt(result.count || 0)
        };
      })
    );

    console.log('   📤 Enviando resposta com', categoriasComContagem.length, 'categorias');

    res.json({
      success: true,
      data: categoriasComContagem
    });
  } catch (error) {
    console.error('   ❌ ERRO ao listar categorias:', error);
    console.error('   Stack:', error.stack);
    res.status(500).json({
      success: false,
      error: 'Erro ao listar categorias',
      details: error.message
    });
  }
});

// POST - Criar categoria
router.post(
  '/',
  [
    body('nome').trim().notEmpty().withMessage('Nome é obrigatório'),
    body('descricao').optional().trim(),
    body('ordem').optional()
  ],
  async (req, res) => {
    console.log('📥 === POST /admin/categorias EXECUTANDO ===');
    console.log('   Body:', req.body);
    
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: 'Dados inválidos',
          errors: errors.array()
        });
      }

      const { tenant_id, id: usuario_id } = req.user;
      const { nome, descricao, ordem } = req.body;

      const existente = await db('categorias_checkmark')
        .where({ tenant_id, nome })
        .first();

      if (existente) {
        return res.status(400).json({
          success: false,
          error: 'Já existe uma categoria com este nome'
        });
      }

      let ordemFinal = ordem;
      if (!ordemFinal) {
        const ultima = await db('categorias_checkmark')
          .where({ tenant_id })
          .orderBy('ordem', 'desc')
          .first();
        
        ordemFinal = ultima ? ultima.ordem + 1 : 1;
      }

      const [novaCategoria] = await db('categorias_checkmark')
        .insert({
          tenant_id,
          nome,
          descricao: descricao || null,
          ordem: ordemFinal,
          ativo: true,
          global: false,
          data_upload: new Date()
        })
        .returning('*');

      console.log('   ✅ Categoria criada:', novaCategoria.id);

      try {
        await db('logs_sistema').insert({
          tenant_id,
          usuario_id,
          acao: 'CRIAR_CATEGORIA',
          tabela_afetada: 'categorias_checkmark',
          registro_id: novaCategoria.id,
          dados_novos: JSON.stringify(novaCategoria),
          nivel: 'info',
          data_acao: new Date()
        });
      } catch (logError) {
        console.warn('⚠️ Erro ao criar log:', logError.message);
      }

      res.status(201).json({
        success: true,
        data: novaCategoria,
        message: 'Categoria criada com sucesso'
      });
    } catch (error) {
      console.error('❌ Erro ao criar categoria:', error);
      res.status(500).json({
        success: false,
        error: 'Erro ao criar categoria',
        details: error.message
      });
    }
  }
);

// PUT - Atualizar categoria
router.put('/:id', async (req, res) => {
  console.log('📥 === PUT /admin/categorias/:id EXECUTANDO ===');
  console.log('   ID:', req.params.id);
  console.log('   Body recebido:', JSON.stringify(req.body));
  
  try {
    const { id } = req.params;
    const { tenant_id, id: usuario_id } = req.user;
    const { nome, descricao, ordem, ativo } = req.body;

    console.log('   Tenant ID:', tenant_id);
    console.log('   Usuario ID:', usuario_id);

    const existente = await db('categorias_checkmark')
      .where({ id, tenant_id })
      .first();

    console.log('   Categoria existente:', existente ? 'SIM' : 'NÃO');

    if (!existente) {
      return res.status(404).json({
        success: false,
        error: 'Categoria não encontrada'
      });
    }

    if (nome && nome !== existente.nome) {
      const duplicado = await db('categorias_checkmark')
        .where({ tenant_id, nome })
        .whereNot({ id })
        .first();

      if (duplicado) {
        return res.status(400).json({
          success: false,
          error: 'Já existe uma categoria com este nome'
        });
      }
    }

    // Montar dados para atualização
    const updateData = {};
    if (nome !== undefined && nome !== null) updateData.nome = nome;
    if (descricao !== undefined) updateData.descricao = descricao;
    if (ordem !== undefined && ordem !== null) updateData.ordem = parseInt(ordem);
    
    if (ativo !== undefined && ativo !== null) {
      if (typeof ativo === 'boolean') {
        updateData.ativo = ativo;
      } else if (typeof ativo === 'number') {
        updateData.ativo = ativo === 1;
      } else if (typeof ativo === 'string') {
        updateData.ativo = ativo.toLowerCase() === 'true' || ativo === '1';
      }
    }
    
    // ❌ REMOVER ESTA LINHA:
    // updateData.data_atualizacao = new Date();

    console.log('   Dados para update:', JSON.stringify(updateData));

    const result = await db('categorias_checkmark')
      .where({ id: parseInt(id), tenant_id })
      .update(updateData)
      .returning('*');

    if (!result || result.length === 0) {
      throw new Error('Nenhum registro foi atualizado');
    }

    const atualizada = result[0];

    console.log('   ✅ Categoria atualizada:', atualizada.id);

    // Log de auditoria
    try {
      await db('logs_sistema').insert({
        tenant_id,
        usuario_id,
        acao: 'ATUALIZAR_CATEGORIA',
        tabela_afetada: 'categorias_checkmark',
        registro_id: parseInt(id),
        dados_anteriores: JSON.stringify(existente),
        dados_novos: JSON.stringify(atualizada),
        nivel: 'info',
        data_acao: new Date()
      });
    } catch (logError) {
      console.warn('⚠️ Erro ao criar log de auditoria:', logError.message);
    }

    res.json({
      success: true,
      data: atualizada,
      message: 'Categoria atualizada com sucesso'
    });
  } catch (error) {
    console.error('❌ ERRO ao atualizar categoria:', error);
    console.error('   Tipo do erro:', error.constructor.name);
    console.error('   Mensagem:', error.message);
    console.error('   Stack:', error.stack);
    
    res.status(500).json({
      success: false,
      error: 'Erro ao atualizar categoria',
      details: process.env.NODE_ENV === 'production' ? undefined : error.message
    });
  }
});

// DELETE - Deletar categoria
router.delete('/:id', async (req, res) => {
  console.log('📥 === DELETE /admin/categorias/:id EXECUTANDO ===');
  
  try {
    const { id } = req.params;
    const { tenant_id, id: usuario_id } = req.user;

    const categoria = await db('categorias_checkmark')
      .where({ id, tenant_id })
      .first();

    if (!categoria) {
      return res.status(404).json({
        success: false,
        error: 'Categoria não encontrada'
      });
    }

    const { count } = await db('checkmarks')
      .where({ categoria_id: id, tenant_id })
      .count('* as count')
      .first();

    if (parseInt(count) > 0) {
      return res.status(400).json({
        success: false,
        error: `Não é possível deletar. Existem ${count} checkmarks associados.`,
        total_checkmarks: parseInt(count)
      });
    }

    await db('categorias_checkmark')
      .where({ id, tenant_id })
      .delete();

    console.log('   ✅ Categoria deletada');

    try {
      await db('logs_sistema').insert({
        tenant_id,
        usuario_id,
        acao: 'DELETAR_CATEGORIA',
        tabela_afetada: 'categorias_checkmark',
        registro_id: id,
        dados_anteriores: JSON.stringify(categoria),
        nivel: 'warning',
        data_acao: new Date()
      });
    } catch (logError) {
      console.warn('⚠️ Erro ao criar log:', logError.message);
    }

    res.json({
      success: true,
      message: 'Categoria deletada com sucesso'
    });
  } catch (error) {
    console.error('❌ Erro ao deletar categoria:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao deletar categoria',
      details: error.message
    });
  }
});

console.log('✅ Rotas GET, POST, PUT, DELETE definidas');
console.log('🔥 === FIM routes/admin/categorias.js ===\n');

module.exports = router;