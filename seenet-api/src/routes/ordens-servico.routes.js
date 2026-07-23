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
router.get('/:id/trilha', OrdensServicoController.consultarTrilha.bind(OrdensServicoController));

// Buscar detalhes de uma OS
router.get('/:id/detalhes', OrdensServicoController.buscarDetalhesOS.bind(OrdensServicoController));

// Listar admins para seleção
router.get('/admins', OrdensServicoController.listarAdmins.bind(OrdensServicoController));

// Listar técnicos da empresa (para encaminhar OS)
router.get('/tecnicos', OrdensServicoController.listarTecnicos.bind(OrdensServicoController));

// 1️⃣ Deslocamento (técnico saindo)
router.post('/:id/deslocar', OrdensServicoController.deslocarParaOS.bind(OrdensServicoController));

// 2️⃣ Chegada ao local (técnico chegou)
router.post('/:id/chegar-local', OrdensServicoController.chegarAoLocal.bind(OrdensServicoController));

// 3️⃣ Finalizar OS (serviço concluído)
router.post('/:id/finalizar', OrdensServicoController.finalizarExecucao.bind(OrdensServicoController));

// 4️⃣ Reagendar OS (cliente não estava → volta pra "Aguardando Agendamento" no IXC)
router.post('/:id/reagendar', OrdensServicoController.reagendarOS.bind(OrdensServicoController));

// 5️⃣ Encaminhar OS para outro técnico
router.post('/:id/encaminhar', OrdensServicoController.encaminharOS.bind(OrdensServicoController));

// 🧹 Limpar MAC do login do cliente (botão Limpar MAC do IXC)
router.post('/:id/limpar-mac', OrdensServicoController.limparMac.bind(OrdensServicoController));

// 💾 Rascunho do wizard no servidor (preserva tudo ao reagendar/encaminhar)
router.get('/:id/rascunho', OrdensServicoController.buscarRascunho.bind(OrdensServicoController));
router.post('/:id/rascunho', OrdensServicoController.salvarRascunho.bind(OrdensServicoController));
router.delete('/:id/rascunho', OrdensServicoController.deletarRascunho.bind(OrdensServicoController));

router.get('/:id/historico-endereco', OrdensServicoController.buscarHistoricoEndereco.bind(OrdensServicoController));

// 📷 Foto da fachada (frente da casa) do cliente — 1 por cliente, só no SeeNet
router.get('/:id/fachada', OrdensServicoController.buscarFachada.bind(OrdensServicoController));
router.post('/:id/fachada', OrdensServicoController.salvarFachada.bind(OrdensServicoController));


module.exports = router;