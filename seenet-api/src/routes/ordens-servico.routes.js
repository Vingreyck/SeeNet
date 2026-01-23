const express = require('express');
const router = express.Router();
const OrdensServicoController = require('../controllers/OrdensServicoController');
const authMiddleware = require('../middleware/auth');

// ✅ Todas as rotas requerem autenticação
router.use(authMiddleware);

// Buscar OSs do técnico logado (pendentes e em execução)
router.get('/minhas', OrdensServicoController.buscarMinhasOSs.bind(OrdensServicoController));

// ✅ NOVO: Buscar OSs concluídas
router.get('/concluidas', OrdensServicoController.buscarOSsConcluidas.bind(OrdensServicoController));

// Buscar detalhes de uma OS
router.get('/:id/detalhes', OrdensServicoController.buscarDetalhesOS.bind(OrdensServicoController));

// Iniciar execução
router.post('/:id/iniciar', OrdensServicoController.iniciarOS.bind(OrdensServicoController));

// Finalizar OS
router.post('/:id/finalizar', OrdensServicoController.finalizarOS.bind(OrdensServicoController));

// Deslocamento
router.post(
  '/:id/deslocar',
  authMiddleware,
  ordensServicoController.deslocarParaOS
);

// Chegada ao local
router.post(
  '/:id/chegar-local',
  authMiddleware,
  ordensServicoController.chegarAoLocal
);

// Finalizar (já existe, mas confirme que está assim)
router.post(
  '/:id/finalizar',
  authMiddleware,
  ordensServicoController.finalizarOS
);
module.exports = router;