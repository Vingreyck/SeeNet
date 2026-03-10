// ============================================
// ARQUIVO: src/routes/estoque.routes.js
// Rotas de integração com estoque IXC
// ============================================
const express = require('express');
const router = express.Router();
const EstoqueController = require('../controllers/EstoqueController');
const authMiddleware = require('../middleware/auth');

// Todas as rotas requerem autenticação
router.use(authMiddleware);

// ── PRODUTOS (materiais de consumo) ──────────────────
// Buscar produtos do estoque IXC (com busca)
router.get('/produtos', EstoqueController.buscarProdutos.bind(EstoqueController));

// Buscar produto específico por ID
router.get('/produtos/:id', EstoqueController.buscarProdutoPorId.bind(EstoqueController));

// ── PATRIMÔNIOS (equipamentos com serial) ────────────
// Buscar patrimônios (por serial, MAC ou número patrimonial)
router.get('/patrimonios', EstoqueController.buscarPatrimonios.bind(EstoqueController));

// ── ESTOQUE POR ALMOXARIFADO ─────────────────────────
// Buscar saldo de produtos no almoxarifado do técnico
router.get('/saldo', EstoqueController.buscarSaldoEstoque.bind(EstoqueController));

// ── VINCULAR PRODUTO À OS ────────────────────────────
// Adicionar produto/patrimônio a uma OS no IXC
router.post('/os/:osIdExterno/produtos', EstoqueController.adicionarProdutoOS.bind(EstoqueController));

// Listar produtos já vinculados a uma OS
router.get('/os/:osIdExterno/produtos', EstoqueController.listarProdutosOS.bind(EstoqueController));

// Remover produto de uma OS
router.delete('/os/:osIdExterno/produtos/:movimentoId', EstoqueController.removerProdutoOS.bind(EstoqueController));

module.exports = router;