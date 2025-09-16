const express = require('express');
const { db } = require('../config/database');
const geminiService = require('../services/geminiService');

const router = express.Router();

// Health check básico
router.get('/', async (req, res) => {
  try {
    const checks = {
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: '1.0.0',
      environment: process.env.NODE_ENV,
      database: false,
      gemini: false
    };

    // Verificar banco de dados
    try {
      await db.raw('SELECT 1');
      checks.database = true;
    } catch (dbError) {
      console.error('Database health check failed:', dbError);
    }

    // Verificar Gemini (opcional, para não atrasar muito)
    try {
      checks.gemini = geminiService.getInfo().configurado;
    } catch (geminiError) {
      console.error('Gemini health check failed:', geminiError);
    }

    const allHealthy = checks.database && checks.gemini;
    const status = allHealthy ? 200 : 503;

    res.status(status).json({
      status: allHealthy ? 'OK' : 'DEGRADED',
      checks
    });
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      error: error.message
    });
  }
});

// Health check detalhado (para monitoramento)
router.get('/detailed', async (req, res) => {
  try {
    const stats = {
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      cpu: process.cpuUsage(),
      environment: process.env.NODE_ENV,
      version: '1.0.0'
    };

    // Verificações do banco
    const dbStats = await db.raw(`
      SELECT 
        (SELECT COUNT(*) FROM tenants WHERE ativo = 1) as tenants_ativos,
        (SELECT COUNT(*) FROM usuarios WHERE ativo = 1) as usuarios_ativos,
        (SELECT COUNT(*) FROM avaliacoes WHERE data_criacao >= date('now', '-24 hours')) as avaliacoes_24h,
        (SELECT COUNT(*) FROM diagnosticos WHERE data_criacao >= date('now', '-24 hours')) as diagnosticos_24h
    `);

    stats.database = {
      connected: true,
      stats: dbStats[0]
    };

    // Verificações do Gemini
    stats.gemini = geminiService.getInfo();

    res.json({
      status: 'OK',
      stats
    });
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      error: error.message
    });
  }
});

module.exports = router;