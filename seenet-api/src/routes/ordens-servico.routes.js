const express = require('express');
const router = express.Router();
const OrdensServicoController = require('../controllers/OrdensServicoController');
const authMiddleware = require('../middlewares/auth');

// ✅ Todas as rotas requerem autenticação
router.use(authMiddleware);

// Buscar OSs do técnico logado
router.get('/minhas', OrdensServicoController.buscarMinhasOSs.bind(OrdensServicoController));

// Buscar detalhes de uma OS
router.get('/:id/detalhes', OrdensServicoController.buscarDetalhesOS.bind(OrdensServicoController));

// Iniciar execução
router.post('/:id/iniciar', OrdensServicoController.iniciarOS.bind(OrdensServicoController));

// Finalizar OS
router.post('/:id/finalizar', OrdensServicoController.finalizarOS.bind(OrdensServicoController));

module.exports = router;