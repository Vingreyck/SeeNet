// backend/routes/admin/categorias.js
const express = require('express');
const router = express.Router();
const { db } = require('../../config/database');
const authMiddleware = require('../../middleware/auth'); // ← Import padrão
const { adminMiddleware } = authMiddleware; // ← Extrair adminMiddleware
const { body, validationResult } = require('express-validator');

console.log('📋 Carregando routes/admin/categorias.js');

// Aplicar middlewares
router.use(authMiddleware); // ← Usar authMiddleware diretamente (não chamar como função)
router.use(adminMiddleware); // ← Adicionar verificação de admin

// Resto do código permanece igual...
router.get('/', async (req, res) => {
  console.log('📥 GET /admin/categorias');
  console.log('   Tenant ID:', req.user?.tenant_id);
  
  try {
    const { tenant_id } = req.user;

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

    res.json({
      success: true,
      data: categoriasComContagem
    });
  } catch (error) {
    console.error('❌ Erro ao listar categorias:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao listar categorias',
      details: error.message
    });
  }
});

router.post(
  '/',
  [
    body('nome').trim().notEmpty().withMessage('Nome é obrigatório'),
    body('descricao').optional().trim(),
    body('ordem').optional()
  ],
  async (req, res) => {
    console.log('📥 POST /admin/categorias');
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
          data_criacao: new Date()
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

router.put('/:id', async (req, res) => {
  console.log('📥 PUT /admin/categorias/:id');
  console.log('   ID:', req.params.id);
  
  try {
    const { id } = req.params;
    const { tenant_id, id: usuario_id } = req.user;
    const { nome, descricao, ordem, ativo } = req.body;

    const existente = await db('categorias_checkmark')
      .where({ id, tenant_id })
      .first();

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

    const updateData = {};
    if (nome !== undefined) updateData.nome = nome;
    if (descricao !== undefined) updateData.descricao = descricao;
    if (ordem !== undefined) updateData.ordem = ordem;
    if (ativo !== undefined) updateData.ativo = ativo;
    updateData.data_atualizacao = new Date();

    const [atualizada] = await db('categorias_checkmark')
      .where({ id, tenant_id })
      .update(updateData)
      .returning('*');

    console.log('   ✅ Categoria atualizada');

    try {
      await db('logs_sistema').insert({
        tenant_id,
        usuario_id,
        acao: 'ATUALIZAR_CATEGORIA',
        tabela_afetada: 'categorias_checkmark',
        registro_id: id,
        dados_anteriores: JSON.stringify(existente),
        dados_novos: JSON.stringify(atualizada),
        nivel: 'info',
        data_acao: new Date()
      });
    } catch (logError) {
      console.warn('⚠️ Erro ao criar log:', logError.message);
    }

    res.json({
      success: true,
      data: atualizada,
      message: 'Categoria atualizada com sucesso'
    });
  } catch (error) {
    console.error('❌ Erro ao atualizar categoria:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao atualizar categoria',
      details: error.message
    });
  }
});

router.delete('/:id', async (req, res) => {
  console.log('📥 DELETE /admin/categorias/:id');
  
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

console.log('✅ Routes admin/categorias carregadas');

module.exports = router;