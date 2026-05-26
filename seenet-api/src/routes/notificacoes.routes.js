// src/routes/notificacoes.routes.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { db } = require('../config/database');

// GET /api/notificacoes
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { pagina = 1, limite = 30 } = req.query;
    const offset = (parseInt(pagina) - 1) * parseInt(limite);

    const notificacoes = await db('notificacoes')
      .where('usuario_id', req.user.id)
      .where('tenant_id', req.tenantId)
      .orderBy('data_criacao', 'desc')
      .limit(parseInt(limite))
      .offset(offset)
      .select('*');

    const { total: naoLidas } = await db('notificacoes')
      .where('usuario_id', req.user.id)
      .where('tenant_id', req.tenantId)
      .where('lida', false)
      .count('id as total')
      .first();

    res.json({
      success: true,
      data: notificacoes,
      nao_lidas: parseInt(naoLidas || 0),
    });
  } catch (error) {
    console.error('❌ Erro ao buscar notificações:', error.message);
    res.status(500).json({ success: false, error: 'Erro ao buscar notificações' });
  }
});

// PUT /api/notificacoes/todas-lidas
router.put('/todas-lidas', authMiddleware, async (req, res) => {
  try {
    await db('notificacoes')
      .where('usuario_id', req.user.id)
      .where('tenant_id', req.tenantId)
      .where('lida', false)
      .update({ lida: true });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Erro ao marcar notificações' });
  }
});

// PUT /api/notificacoes/:id/lida
router.put('/:id/lida', authMiddleware, async (req, res) => {
  try {
    await db('notificacoes')
      .where('id', req.params.id)
      .where('usuario_id', req.user.id)
      .update({ lida: true });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false });
  }
});

module.exports = router;