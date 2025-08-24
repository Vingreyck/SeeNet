const express = require('express');
const { body, validationResult } = require('express-validator');
const { db } = require('../config/database');
const logger = require('../config/logger');

const router = express.Router();

// ========== VERIFICAR CÓDIGO DA EMPRESA ==========
router.get('/verify/:codigo', async (req, res) => {
  try {
    const { codigo } = req.params;

    const tenant = await db('tenants')
      .where('codigo', codigo.toUpperCase())
      .where('ativo', true)
      .select('nome', 'codigo', 'plano', 'descricao')
      .first();

    if (!tenant) {
      return res.status(404).json({ 
        error: 'Código da empresa não encontrado ou empresa inativa' 
      });
    }

    // Contar usuários ativos
    const userCount = await db('usuarios')
      .where('tenant_id', tenant.id)
      .where('ativo', true)
      .count('id as total')
      .first();

    res.json({
      empresa: {
        nome: tenant.nome,
        codigo: tenant.codigo,
        plano: tenant.plano,
        descricao: tenant.descricao,
        usuarios_ativos: userCount.total
      }
    });

  } catch (error) {
    logger.error('Erro ao verificar tenant:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

module.exports = router;