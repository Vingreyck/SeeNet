const express = require('express');
const router = express.Router();
const OrdensServicoController = require('../controllers/OrdensServicoController');
const authMiddleware = require('../middleware/auth');

// ✅ Todas as rotas requerem autenticação
router.use(authMiddleware);

// Buscar OSs do técnico logado (pendentes e em execução)
router.get('/minhas', OrdensServicoController.buscarMinhasOSs.bind(OrdensServicoController));

// Buscar OSs concluídas
router.get('/concluidas', OrdensServicoController.buscarOSsConcluidas.bind(OrdensServicoController));

// Rastreamento ao vivo
router.get('/acompanhamento', OrdensServicoController.listarAcompanhamento.bind(OrdensServicoController));
router.put('/:id/location', OrdensServicoController.atualizarLocalizacao.bind(OrdensServicoController));
router.get('/:id/location', OrdensServicoController.consultarLocalizacao.bind(OrdensServicoController));
router.delete('/:id/location', OrdensServicoController.pararLocalizacao.bind(OrdensServicoController));

// Buscar detalhes de uma OS
router.get('/:id/detalhes', OrdensServicoController.buscarDetalhesOS.bind(OrdensServicoController));

// Listar admins para seleção
router.get('/admins', OrdensServicoController.listarAdmins.bind(OrdensServicoController));

// 1️⃣ Deslocamento (técnico saindo)
router.post('/:id/deslocar', OrdensServicoController.deslocarParaOS.bind(OrdensServicoController));

// 2️⃣ Chegada ao local (técnico chegou)
router.post('/:id/chegar-local', OrdensServicoController.chegarAoLocal.bind(OrdensServicoController));

// 3️⃣ Finalizar OS (serviço concluído)
router.post('/:id/finalizar', OrdensServicoController.finalizarExecucao.bind(OrdensServicoController));

router.get('/:id/historico-endereco', OrdensServicoController.buscarHistoricoEndereco.bind(OrdensServicoController));


module.exports = router;