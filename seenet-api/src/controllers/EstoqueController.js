// ============================================
// ARQUIVO: src/controllers/EstoqueController.js
// Controller para integração com estoque IXC
// ============================================
const { db } = require('../config/database');
const IXCService = require('../services/IXCService');

class EstoqueController {

  /**
   * Helper: Criar instância do IXCService para o tenant
   */
  async _getIXCService(tenantId) {
    const integracao = await db('integracao_ixc')
      .where('tenant_id', tenantId)
      .where('ativo', true)
      .first();

    if (!integracao) {
      throw new Error('Integração IXC não configurada');
    }

    return new IXCService(integracao.url_api, integracao.token_api);
  }

  /**
   * Helper: Buscar almoxarifado do técnico logado
   */
  async _getAlmoxarifadoTecnico(userId, tenantId) {
    const mapeamento = await db('mapeamento_tecnicos_ixc')
      .where('usuario_id', userId)
      .where('tenant_id', tenantId)
      .first();

    if (!mapeamento) {
      throw new Error('Técnico não mapeado no IXC');
    }

    return {
      tecnicoIxcId: mapeamento.tecnico_ixc_id,
      almoxarifadoId: mapeamento.id_almoxarifado,
      almoxarifadoNome: mapeamento.almoxarifado_nome
    };
  }

  // ═══════════════════════════════════════════════════
  // PRODUTOS (materiais de consumo)
  // GET /api/estoque/produtos?busca=conector&page=1&rp=20
  // ═══════════════════════════════════════════════════
  async buscarProdutos(req, res) {
    try {
      const tenantId = req.tenantId;
      const userId = req.user.id;
      const { busca = '', page = 1, rp = 30 } = req.query;

      console.log(`🔍 Buscando produtos IXC: "${busca}"`);

      const ixc = await this._getIXCService(tenantId);
      const { almoxarifadoId } = await this._getAlmoxarifadoTecnico(userId, tenantId);

      // Buscar produtos no IXC
      const resultado = await ixc.listarProdutos({
        busca,
        page: parseInt(page),
        rp: parseInt(rp)
      });

      // Se tem almoxarifado mapeado, buscar saldo também
      let produtosComSaldo = resultado.registros || [];

      if (almoxarifadoId && produtosComSaldo.length > 0) {
        // Buscar saldo do almoxarifado para esses produtos
        const saldos = await ixc.buscarSaldoAlmoxarifado(almoxarifadoId);

        // Mapear saldo por id_produto
        const saldoMap = {};
        for (const s of saldos) {
          saldoMap[s.id_produto] = parseFloat(s.saldo) || 0;
        }

        // Adicionar saldo a cada produto
        produtosComSaldo = produtosComSaldo.map(p => ({
          id: p.id,
          descricao: p.descricao,
          valor: parseFloat(p.valor) || 0,
          preco_base: parseFloat(p.preco_base) || 0,
          unidade: p.unidade,
          tipo: p.tipo,
          controla_estoque: p.controla_estoque,
          saldo_almoxarifado: saldoMap[p.id] || 0,
          saldo_geral: parseFloat(p.saldo) || 0
        }));
      }

      console.log(`✅ ${produtosComSaldo.length} produto(s) encontrado(s)`);

      return res.json({
        success: true,
        total: parseInt(resultado.total) || 0,
        page: parseInt(page),
        data: produtosComSaldo
      });

    } catch (error) {
      console.error('❌ Erro ao buscar produtos:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // PRODUTO POR ID
  // GET /api/estoque/produtos/:id
  // ═══════════════════════════════════════════════════
  async buscarProdutoPorId(req, res) {
    try {
      const tenantId = req.tenantId;
      const { id } = req.params;

      console.log(`🔍 Buscando produto ID ${id}`);

      const ixc = await this._getIXCService(tenantId);
      const produto = await ixc.buscarProdutoPorId(id);

      if (!produto) {
        return res.status(404).json({
          success: false,
          error: 'Produto não encontrado'
        });
      }

      return res.json({
        success: true,
        data: {
          id: produto.id,
          descricao: produto.descricao,
          valor: parseFloat(produto.valor) || 0,
          preco_base: parseFloat(produto.preco_base) || 0,
          unidade: produto.unidade,
          tipo: produto.tipo,
          saldo: parseFloat(produto.saldo) || 0
        }
      });

    } catch (error) {
      console.error('❌ Erro ao buscar produto:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // PATRIMÔNIOS (equipamentos com serial)
  // GET /api/estoque/patrimonios?busca=HWTC&tipo=serial
  // tipo: serial | mac | patrimonial | todos
  // ═══════════════════════════════════════════════════
  async buscarPatrimonios(req, res) {
    try {
      const tenantId = req.tenantId;
      const userId = req.user.id;
      const { busca = '', tipo = 'todos', page = 1, rp = 20 } = req.query;

      console.log(`🔍 Buscando patrimônios IXC: "${busca}" (tipo: ${tipo})`);

      const ixc = await this._getIXCService(tenantId);
      const { almoxarifadoId } = await this._getAlmoxarifadoTecnico(userId, tenantId);

      const resultado = await ixc.listarPatrimonios({
        busca,
        tipo, // serial, mac, patrimonial, todos
        almoxarifadoId,
        page: parseInt(page),
        rp: parseInt(rp)
      });

      const patrimonios = (resultado.registros || []).map(p => ({
        id: p.id,
        descricao: p.descricao,
        serial: p.serial,
        id_mac: p.id_mac,
        id_produto: p.id_produto,
        id_filial: p.id_filial,
        id_almoxarifado: p.id_almoxarifado,
        situacao: p.situacao,
        valor_bem: parseFloat(p.valor_bem) || 0,
        estado: p.estado
      }));

      console.log(`✅ ${patrimonios.length} patrimônio(s) encontrado(s)`);

      return res.json({
        success: true,
        total: parseInt(resultado.total) || 0,
        data: patrimonios
      });

    } catch (error) {
      console.error('❌ Erro ao buscar patrimônios:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // SALDO DE ESTOQUE DO ALMOXARIFADO DO TÉCNICO
  // GET /api/estoque/saldo?busca=cabo
  // ═══════════════════════════════════════════════════
  async buscarSaldoEstoque(req, res) {
    try {
      const tenantId = req.tenantId;
      const userId = req.user.id;
      const { busca = '', page = 1, rp = 50 } = req.query;

      const ixc = await this._getIXCService(tenantId);
      const { almoxarifadoId, almoxarifadoNome } = await this._getAlmoxarifadoTecnico(userId, tenantId);

      if (!almoxarifadoId) {
        return res.status(400).json({
          success: false,
          error: 'Almoxarifado não configurado para este técnico'
        });
      }

      console.log(`📦 Buscando saldo do almoxarifado ${almoxarifadoId} (${almoxarifadoNome})`);

      const resultado = await ixc.buscarEstoquePorAlmoxarifado({
        almoxarifadoId,
        busca,
        page: parseInt(page),
        rp: parseInt(rp)
      });

      const itens = (resultado.registros || []).map(item => ({
        id: item.id,
        id_produto: item.id_produto,
        descricao: item.produto_descricao,
        saldo: parseFloat(item.saldo) || 0,
        tipo: item.produto_tipo,
        preco_base: parseFloat(item.produto_preco_base) || 0,
        unidade: item.produto_unidade,
        ativo: item.produto_ativo
      }));

      console.log(`✅ ${itens.length} item(ns) no almoxarifado`);

      return res.json({
        success: true,
        almoxarifado: {
          id: almoxarifadoId,
          nome: almoxarifadoNome
        },
        total: parseInt(resultado.total) || 0,
        data: itens
      });

    } catch (error) {
      console.error('❌ Erro ao buscar saldo:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // ADICIONAR PRODUTO/PATRIMÔNIO A UMA OS
  // POST /api/estoque/os/:osIdExterno/produtos
  // Body: { id_produto, quantidade, valor_unitario, id_patrimonio?, numero_serie? }
  // ═══════════════════════════════════════════════════
  async adicionarProdutoOS(req, res) {
    try {
      const tenantId = req.tenantId;
      const userId = req.user.id;
      const { osIdExterno } = req.params;
      const {
        id_produto,
        quantidade = 1,
        valor_unitario,
        id_patrimonio = 0,
        numero_serie = '',
        numero_patrimonial = '',
        descricao = ''
      } = req.body;

      if (!id_produto) {
        return res.status(400).json({
          success: false,
          error: 'id_produto é obrigatório'
        });
      }

      console.log(`📦 Adicionando produto ${id_produto} à OS ${osIdExterno}`);

      const ixc = await this._getIXCService(tenantId);
      const { almoxarifadoId, tecnicoIxcId } = await this._getAlmoxarifadoTecnico(userId, tenantId);

      // Buscar a OS no banco local para pegar o id_externo
      const os = await db('ordem_servico')
        .where('id_externo', osIdExterno)
        .where('tenant_id', tenantId)
        .first();

      // Buscar dados do produto se valor_unitario não foi informado
      let valorUnit = valor_unitario;
      if (!valorUnit) {
        const produto = await ixc.buscarProdutoPorId(id_produto);
        valorUnit = parseFloat(produto?.preco_base || produto?.valor || 0);
      }

      const valorTotal = (parseFloat(valorUnit) * parseFloat(quantidade)).toFixed(2);

      // Montar dados para o IXC (baseado na estrutura real da OS 273025)
      const dadosMovimento = {
        id_oss_chamado: osIdExterno,
        id_produto: id_produto,
        descricao: descricao,
        qtde_saida: quantidade.toString(),
        valor_unitario: valorUnit.toString(),
        valor_total: valorTotal,
        id_almox: almoxarifadoId || '',
        filial_id: os?.filial_id || '1',
        id_patrimonio: id_patrimonio.toString(),
        numero_serie: numero_serie,
        numero_patrimonial: numero_patrimonial,
        tipo: 'S', // Saída
        tipo_produto: id_patrimonio > 0 ? 'P' : 'O', // P = Patrimônio, O = Outro (consumo)
        origem_movimento: 'S', // Suporte
        estoque: 'N',
        garantia_oss: 'N',
        fator_conversao: '1.000000000',
        pdesconto: '0.00000',
        vdesconto: '0.00',
        pcomissao: '0.00'
      };

      // Inserir no IXC via su_oss_mov_produto
      const resultado = await ixc.adicionarProdutoOS(dadosMovimento);

      console.log(`✅ Produto adicionado à OS ${osIdExterno}: ${descricao || id_produto}`);

      return res.json({
        success: true,
        message: 'Produto adicionado à OS com sucesso',
        data: resultado
      });

    } catch (error) {
      console.error('❌ Erro ao adicionar produto à OS:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // LISTAR PRODUTOS JÁ VINCULADOS A UMA OS
  // GET /api/estoque/os/:osIdExterno/produtos
  // ═══════════════════════════════════════════════════
  async listarProdutosOS(req, res) {
    try {
      const tenantId = req.tenantId;
      const { osIdExterno } = req.params;

      console.log(`📋 Listando produtos da OS ${osIdExterno}`);

      const ixc = await this._getIXCService(tenantId);
      const resultado = await ixc.listarProdutosOS(osIdExterno);

      const produtos = (resultado.registros || []).map(p => ({
        id: p.id,
        id_produto: p.id_produto,
        descricao: p.descricao,
        quantidade: parseFloat(p.qtde_saida) || 0,
        valor_unitario: parseFloat(p.valor_unitario) || 0,
        valor_total: parseFloat(p.valor_total) || 0,
        id_patrimonio: p.id_patrimonio,
        numero_serie: p.numero_serie,
        id_almox: p.id_almox,
        tipo_produto: p.tipo_produto,
        data: p.data
      }));

      console.log(`✅ ${produtos.length} produto(s) na OS`);

      return res.json({
        success: true,
        total: parseInt(resultado.total) || 0,
        data: produtos
      });

    } catch (error) {
      console.error('❌ Erro ao listar produtos da OS:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // REMOVER PRODUTO DE UMA OS
  // DELETE /api/estoque/os/:osIdExterno/produtos/:movimentoId
  // ═══════════════════════════════════════════════════
  async removerProdutoOS(req, res) {
    try {
      const tenantId = req.tenantId;
      const { osIdExterno, movimentoId } = req.params;

      console.log(`🗑️ Removendo produto ${movimentoId} da OS ${osIdExterno}`);

      const ixc = await this._getIXCService(tenantId);
      await ixc.removerProdutoOS(movimentoId);

      console.log(`✅ Produto ${movimentoId} removido da OS`);

      return res.json({
        success: true,
        message: 'Produto removido da OS com sucesso'
      });

    } catch (error) {
      console.error('❌ Erro ao remover produto:', error.message);
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }
  }
}

module.exports = new EstoqueController();