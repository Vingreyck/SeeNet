const express = require('express');
const router = express.Router();
const { db } = require('../config/database');
const authMiddleware = require('../middleware/auth');
const logger = require('../config/logger');

router.use(authMiddleware);

// Criar avaliação
router.post('/', async (req, res) => {
  try {
    const { titulo, descricao } = req.body;

    const [avaliacaoId] = await db('avaliacoes').insert({
      tenant_id: req.tenantId,
      tecnico_id: req.user.id,
      titulo,
      descricao,
      status: 'em_andamento',
      data_criacao: new Date().toISOString()
    });

    res.json({ success: true, data: { id: avaliacaoId } });
  } catch (error) {
    logger.error('Erro ao criar avaliação:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Salvar respostas
router.post('/:id/respostas', async (req, res) => {
  try {
    const { id } = req.params;
    const { checkmarks_marcados } = req.body;

    const respostas = checkmarks_marcados.map(checkmarkId => ({
      avaliacao_id: id,
      checkmark_id: checkmarkId,
      marcado: true,
      data_criacao: new Date().toISOString()
    }));

    await db('respostas_checkmark').insert(respostas);

    res.json({ success: true });
  } catch (error) {
    logger.error('Erro ao salvar respostas:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// Finalizar avaliação
router.put('/:id/finalizar', async (req, res) => {
  try {
    const { id } = req.params;

    await db('avaliacoes')
      .where('id', id)
      .update({
        status: 'finalizada',
        data_finalizacao: new Date().toISOString()
      });

    res.json({ success: true });
  } catch (error) {
    logger.error('Erro ao finalizar avaliação:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

module.exports = router;