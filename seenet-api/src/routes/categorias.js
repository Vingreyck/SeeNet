const express = require('express');
const router = express.Router();
const knex = require('../../config/database');
const { authenticateToken } = require('../../middleware/auth');
const { requireAdmin } = require('../../middleware/adminAuth');
const { body, validationResult } = require('express-validator');

// Listar todas as categorias do tenant
router.get('/', async (req, res) => {
  try {
    const { tenant_id } = req.user;

    const categorias = await knex('categorias_checkmark')
      .where({ tenant_id })
      .orderBy('ordem', 'asc')
      .select('*');

    // Contar checkmarks por categoria
    const categoriasComContagem = await Promise.all(
      categorias.map(async (cat) => {
        const { count } = await knex('checkmarks')
          .where({ categoria_id: cat.id, tenant_id })
          .count('* as count')
          .first();

        return {
          ...cat,
          total_checkmarks: parseInt(count)
        };
      })
    );

    res.json({
      success: true,
      data: categoriasComContagem
    });
  } catch (error) {
    console.error('Erro ao listar categorias:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao listar categorias'
    });
  }
});

// Criar nova categoria
router.post(
  '/',
  [
    body('nome').trim().notEmpty().withMessage('Nome é obrigatório'),
    body('descricao').optional().trim(),
    body('ordem').optional().isInt({ min: 0 })
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          errors: errors.array()
        });
      }

      const { tenant_id, id: usuario_id } = req.user;
      const { nome, descricao, ordem } = req.body;

      // Verificar se já existe categoria com este nome para o tenant
      const categoriaExistente = await knex('categorias_checkmark')
        .where({ tenant_id, nome })
        .first();

      if (categoriaExistente) {
        return res.status(400).json({
          success: false,
          error: 'Já existe uma categoria com este nome'
        });
      }

      // Se ordem não foi especificada, pegar a próxima disponível
      let ordemFinal = ordem;
      if (!ordemFinal) {
        const ultimaCategoria = await knex('categorias_checkmark')
          .where({ tenant_id })
          .orderBy('ordem', 'desc')
          .first();
        
        ordemFinal = ultimaCategoria ? ultimaCategoria.ordem + 1 : 1;
      }

      // Criar categoria
      const [novaCategoria] = await knex('categorias_checkmark')
        .insert({
          tenant_id,
          nome,
          descricao,
          ordem: ordemFinal,
          ativo: true,
          global: false
        })
        .returning('*');

      // Log de auditoria
      await knex('logs_sistema').insert({
        tenant_id,
        usuario_id,
        acao: 'CRIAR_CATEGORIA',
        tabela_afetada: 'categorias_checkmark',
        registro_id: novaCategoria.id,
        dados_novos: JSON.stringify(novaCategoria),
        nivel: 'info'
      });

      res.status(201).json({
        success: true,
        data: novaCategoria,
        message: 'Categoria criada com sucesso'
      });
    } catch (error) {
      console.error('Erro ao criar categoria:', error);
      res.status(500).json({
        success: false,
        error: 'Erro ao criar categoria'
      });
    }
  }
);

// Atualizar categoria
router.put(
  '/:id',
  [
    body('nome').optional().trim().notEmpty(),
    body('descricao').optional().trim(),
    body('ordem').optional().isInt({ min: 0 }),
    body('ativo').optional().isBoolean()
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          errors: errors.array()
        });
      }

      const { id } = req.params;
      const { tenant_id, id: usuario_id } = req.user;
      const { nome, descricao, ordem, ativo } = req.body;

      // Verificar se categoria existe e pertence ao tenant
      const categoriaExistente = await knex('categorias_checkmark')
        .where({ id, tenant_id })
        .first();

      if (!categoriaExistente) {
        return res.status(404).json({
          success: false,
          error: 'Categoria não encontrada'
        });
      }

      // Se mudar nome, verificar duplicação
      if (nome && nome !== categoriaExistente.nome) {
        const nomeDuplicado = await knex('categorias_checkmark')
          .where({ tenant_id, nome })
          .whereNot({ id })
          .first();

        if (nomeDuplicado) {
          return res.status(400).json({
            success: false,
            error: 'Já existe uma categoria com este nome'
          });
        }
      }

      // Atualizar categoria
      const [categoriaAtualizada] = await knex('categorias_checkmark')
        .where({ id, tenant_id })
        .update({
          ...(nome && { nome }),
          ...(descricao !== undefined && { descricao }),
          ...(ordem !== undefined && { ordem }),
          ...(ativo !== undefined && { ativo }),
          data_atualizacao: knex.fn.now()
        })
        .returning('*');

      // Log de auditoria
      await knex('logs_sistema').insert({
        tenant_id,
        usuario_id,
        acao: 'ATUALIZAR_CATEGORIA',
        tabela_afetada: 'categorias_checkmark',
        registro_id: id,
        dados_anteriores: JSON.stringify(categoriaExistente),
        dados_novos: JSON.stringify(categoriaAtualizada),
        nivel: 'info'
      });

      res.json({
        success: true,
        data: categoriaAtualizada,
        message: 'Categoria atualizada com sucesso'
      });
    } catch (error) {
      console.error('Erro ao atualizar categoria:', error);
      res.status(500).json({
        success: false,
        error: 'Erro ao atualizar categoria'
      });
    }
  }
);

// Deletar categoria
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { tenant_id, id: usuario_id } = req.user;

    // Verificar se categoria existe
    const categoria = await knex('categorias_checkmark')
      .where({ id, tenant_id })
      .first();

    if (!categoria) {
      return res.status(404).json({
        success: false,
        error: 'Categoria não encontrada'
      });
    }

    // Verificar se há checkmarks associados
    const { count } = await knex('checkmarks')
      .where({ categoria_id: id, tenant_id })
      .count('* as count')
      .first();

    if (parseInt(count) > 0) {
      return res.status(400).json({
        success: false,
        error: `Não é possível deletar. Existem ${count} checkmarks associados a esta categoria.`,
        total_checkmarks: parseInt(count)
      });
    }

    // Deletar categoria
    await knex('categorias_checkmark')
      .where({ id, tenant_id })
      .delete();

    // Log de auditoria
    await knex('logs_sistema').insert({
      tenant_id,
      usuario_id,
      acao: 'DELETAR_CATEGORIA',
      tabela_afetada: 'categorias_checkmark',
      registro_id: id,
      dados_anteriores: JSON.stringify(categoria),
      nivel: 'warning'
    });

    res.json({
      success: true,
      message: 'Categoria deletada com sucesso'
    });
  } catch (error) {
    console.error('Erro ao deletar categoria:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao deletar categoria'
    });
  }
});

// Reordenar categorias
router.post('/reordenar', async (req, res) => {
  try {
    const { tenant_id, id: usuario_id } = req.user;
    const { categorias } = req.body; // Array de { id, ordem }

    if (!Array.isArray(categorias)) {
      return res.status(400).json({
        success: false,
        error: 'Formato inválido. Esperado array de categorias'
      });
    }

    // Atualizar ordem de cada categoria
    await knex.transaction(async (trx) => {
      for (const cat of categorias) {
        await trx('categorias_checkmark')
          .where({ id: cat.id, tenant_id })
          .update({ ordem: cat.ordem });
      }
    });

    // Log de auditoria
    await knex('logs_sistema').insert({
      tenant_id,
      usuario_id,
      acao: 'REORDENAR_CATEGORIAS',
      tabela_afetada: 'categorias_checkmark',
      dados_novos: JSON.stringify(categorias),
      nivel: 'info'
    });

    res.json({
      success: true,
      message: 'Categorias reordenadas com sucesso'
    });
  } catch (error) {
    console.error('Erro ao reordenar categorias:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao reordenar categorias'
    });
  }
});

module.exports = router;