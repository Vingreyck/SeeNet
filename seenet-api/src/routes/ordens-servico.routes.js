const express = require('express');
const router = express.Router();
const OrdensServicoController = require('../controllers/OrdensServicoController');
const authMiddleware = require('../middleware/auth');

// ✅ Todas as rotas requerem autenticação
router.use(authMiddleware);

// Buscar OSs do técnico logado (pendentes e em execução)
router.get('/minhas', OrdensServicoController.buscarMinhasOSs);

// Buscar OSs concluídas
router.get('/concluidas', OrdensServicoController.buscarOSsConcluidas);

// Buscar detalhes de uma OS
router.get('/:id/detalhes', OrdensServicoController.buscarDetalhesOS);

// 1️⃣ Deslocamento (técnico saindo)
router.post('/:id/deslocar', OrdensServicoController.deslocarParaOS);

// 2️⃣ Chegada ao local (técnico chegou)
router.post('/:id/chegar-local', OrdensServicoController.chegarAoLocal);

// 3️⃣ Finalizar OS (serviço concluído)
router.post('/:id/finalizar', OrdensServicoController.finalizarOS);

module.exports = router;