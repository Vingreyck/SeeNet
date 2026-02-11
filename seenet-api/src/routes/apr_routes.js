// src/routes/apr_routes.js
const express = require('express');
const router = express.Router();
console.log('✅ APR routes carregadas!');
const AprController = require('../controllers/AprController');
const authMiddleware = require('../middleware/auth');

// Todas as rotas precisam de autenticação
router.use(authMiddleware);

// GET /api/apr/checklist - buscar todas as perguntas
router.get('/checklist', AprController.getChecklist);

// GET /api/apr/status/:osId - verificar se APR foi preenchido
router.get('/status/:osId', AprController.getStatus);

// GET /api/apr/respostas/:osId - buscar respostas de uma OS
router.get('/respostas/:osId', AprController.getRespostas);

// POST /api/apr/respostas - salvar respostas
router.post('/respostas', AprController.salvarRespostas);

// GET /api/apr/pdf/:osId - gerar PDF do APR
router.get('/pdf/:osId', AprController.gerarPdf);

module.exports = router;