// lib/ordem_de_servico/widgets/materiais_estoque_widget.dart
import 'package:flutter/material.dart';
import '../../services/estoque_service.dart';

class MateriaisEstoqueWidget extends StatefulWidget {
  final String? osIdExterno;
  final Function(List<ItemOS>) onItensAlterados;

  const MateriaisEstoqueWidget({
    super.key,
    this.osIdExterno,
    required this.onItensAlterados,
  });

  @override
  State<MateriaisEstoqueWidget> createState() => _MateriaisEstoqueWidgetState();
}

class _MateriaisEstoqueWidgetState extends State<MateriaisEstoqueWidget> {
  final EstoqueService _service = EstoqueService();
  final List<ItemOS> _itensAdicionados = [];

  // Dados carregados do IXC
  List<ProdutoEstoque> _produtosEstoque = [];
  List<PatrimonioEstoque> _patrimoniosEstoque = [];
  bool _isLoading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() { _isLoading = true; _erro = null; });

    try {
      final resultados = await Future.wait([
        _service.buscarSaldoEstoque(),
        _service.buscarPatrimonios(),
      ]);

      setState(() {
        _produtosEstoque = resultados[0] as List<ProdutoEstoque>;
        _patrimoniosEstoque = resultados[1] as List<PatrimonioEstoque>;
        _isLoading = false;
      });

      print('✅ Estoque carregado: ${_produtosEstoque.length} produtos, ${_patrimoniosEstoque.length} patrimônios');
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar estoque: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botões de adicionar
        Row(
          children: [
            Expanded(
              child: _buildBotaoAdicionar(
                icone: Icons.inventory_2,
                label: 'Produto',
                sublabel: 'Materiais de consumo',
                onTap: _abrirBuscaProduto,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBotaoAdicionar(
                icone: Icons.router,
                label: 'Patrimônio',
                sublabel: 'Equipamentos com serial',
                onTap: _abrirBuscaPatrimonio,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Status de carregamento
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF00FF88)),
                  SizedBox(height: 12),
                  Text('Carregando estoque...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),

        if (_erro != null)
          _buildErroWidget(),

        // Contador
        if (_itensAdicionados.isNotEmpty)
          _buildContador(),

        if (_itensAdicionados.isNotEmpty) const SizedBox(height: 12),

        // Lista de itens adicionados
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _itensAdicionados.length,
          itemBuilder: (context, index) => _buildItemCard(index),
        ),

        // Total
        if (_itensAdicionados.isNotEmpty) _buildTotalCard(),
      ],
    );
  }

  // ──────────────────────────────────────
  // BOTÕES
  // ──────────────────────────────────────

  Widget _buildBotaoAdicionar({
    required IconData icone,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: const Color(0xFF00FF88), size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(sublabel, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildContador() {
    final totalProdutos = _itensAdicionados.where((i) => !i.isPatrimonio).length;
    final totalPatrimonios = _itensAdicionados.where((i) => i.isPatrimonio).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF88).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00FF88)),
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist, color: Color(0xFF00FF88), size: 20),
          const SizedBox(width: 8),
          Text(
            '${_itensAdicionados.length} item(ns) adicionado(s)',
            style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Spacer(),
          if (totalProdutos > 0)
            Text('$totalProdutos prod.  ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (totalPatrimonios > 0)
            Text('$totalPatrimonios equip.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErroWidget() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: _carregarDados,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────
  // CARD DO ITEM ADICIONADO
  // ──────────────────────────────────────

  Widget _buildItemCard(int index) {
    final item = _itensAdicionados[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.isPatrimonio ? Colors.orange.withOpacity(0.5) : const Color(0xFF00FF88).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (item.isPatrimonio ? Colors.orange : const Color(0xFF00FF88)).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.isPatrimonio ? Icons.router : Icons.inventory_2,
                    color: item.isPatrimonio ? Colors.orange : const Color(0xFF00FF88),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.produto.descricao,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.patrimonio != null)
                        Text(
                          'S/N: ${item.patrimonio!.serial}  |  MAC: ${item.patrimonio!.mac}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removerItem(index),
                ),
              ],
            ),
          ),

          // Body - Quantidade e Valor
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Quantidade
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quantidade', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      item.isPatrimonio
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232323),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('1', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      )
                          : Row(
                        children: [
                          _buildQtdButton(Icons.remove, () {
                            if (item.quantidade > 1) {
                              setState(() {
                                _itensAdicionados[index].quantidade--;
                              });
                              widget.onItensAlterados(List.from(_itensAdicionados));
                            }
                          }),
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              item.quantidade.toStringAsFixed(item.quantidade == item.quantidade.truncateToDouble() ? 0 : 1),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          _buildQtdButton(Icons.add, () {
                            setState(() {
                              _itensAdicionados[index].quantidade++;
                            });
                            widget.onItensAlterados(List.from(_itensAdicionados));
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Valor unitário
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Valor Unit.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        'R\$ ${item.valorUnitario.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // Total
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        'R\$ ${item.valorTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF00FF88), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtdButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF00FF88), size: 20),
      ),
    );
  }

  Widget _buildTotalCard() {
    final total = _itensAdicionados.fold<double>(0, (sum, item) => sum + item.valorTotal);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF88).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF88)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('TOTAL MATERIAIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────
  // BUSCA DE PRODUTO (BottomSheet)
  // ──────────────────────────────────────

  void _abrirBuscaProduto() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BuscaProdutoSheet(
        produtos: _produtosEstoque,
        onSelecionado: (produto) {
          Navigator.pop(ctx);
          _adicionarProduto(produto);
        },
      ),
    );
  }

  void _adicionarProduto(ProdutoEstoque produto) {
    // Verifica se já foi adicionado
    final existente = _itensAdicionados.indexWhere((i) => i.produto.id == produto.id && !i.isPatrimonio);
    if (existente >= 0) {
      setState(() => _itensAdicionados[existente].quantidade++);
    } else {
      setState(() {
        _itensAdicionados.add(ItemOS(produto: produto));
      });
    }
    widget.onItensAlterados(_itensAdicionados);
  }

  // ──────────────────────────────────────
  // BUSCA DE PATRIMÔNIO (BottomSheet)
  // ──────────────────────────────────────

  void _abrirBuscaPatrimonio() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BuscaPatrimonioSheet(
        patrimonios: _patrimoniosEstoque,
        produtosRef: _produtosEstoque,
        onSelecionado: (patrimonio, produto) {
          Navigator.pop(ctx);
          _adicionarPatrimonio(patrimonio, produto);
        },
      ),
    );
  }

  void _adicionarPatrimonio(PatrimonioEstoque patrimonio, ProdutoEstoque produto) {
    // Verifica se patrimônio já foi adicionado
    final jaExiste = _itensAdicionados.any((i) => i.patrimonio?.id == patrimonio.id);
    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este patrimônio já foi adicionado'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _itensAdicionados.add(ItemOS(
        produto: produto,
        patrimonio: patrimonio,
        quantidade: 1,
        valorUnitario: patrimonio.valorBem > 0 ? patrimonio.valorBem : produto.valorUnitario,
      ));
    });
    widget.onItensAlterados(_itensAdicionados);
  }

  void _removerItem(int index) {
    setState(() => _itensAdicionados.removeAt(index));
    widget.onItensAlterados(_itensAdicionados);
  }
}

// ══════════════════════════════════════════════
// BOTTOM SHEET: Busca de Produto
// ══════════════════════════════════════════════

class _BuscaProdutoSheet extends StatefulWidget {
  final List<ProdutoEstoque> produtos;
  final Function(ProdutoEstoque) onSelecionado;

  const _BuscaProdutoSheet({required this.produtos, required this.onSelecionado});

  @override
  State<_BuscaProdutoSheet> createState() => _BuscaProdutoSheetState();
}

class _BuscaProdutoSheetState extends State<_BuscaProdutoSheet> {
  final TextEditingController _buscaController = TextEditingController();
  List<ProdutoEstoque> _filtrados = [];

  @override
  void initState() {
    super.initState();
    _filtrados = widget.produtos;
  }

  void _filtrar(String texto) {
    setState(() {
      if (texto.isEmpty) {
        _filtrados = widget.produtos;
      } else {
        final busca = texto.toLowerCase();
        _filtrados = widget.produtos.where((p) =>
        p.descricao.toLowerCase().contains(busca) ||
            p.id.contains(busca)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2, color: Color(0xFF00FF88), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selecionar Produto', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Materiais do seu almoxarifado', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // Campo de busca
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _buscaController,
                onChanged: _filtrar,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou código...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _buscaController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, color: Colors.white38), onPressed: () { _buscaController.clear(); _filtrar(''); })
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF232323),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF88))),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('${_filtrados.length} produto(s)', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),

            // Lista
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtrados.length,
                itemBuilder: (context, index) {
                  final p = _filtrados[index];
                  return InkWell(
                    onTap: () => widget.onSelecionado(p),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232323),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          // ID
                          Container(
                            width: 48,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF88).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(p.id, style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),

                          // Descrição + saldo
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.descricao, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Saldo: ${p.saldoAlmoxarifado.toStringAsFixed(0)}', style: TextStyle(color: p.saldoAlmoxarifado > 0 ? const Color(0xFF00FF88) : Colors.red, fontSize: 12)),
                                    const SizedBox(width: 12),
                                    Text('R\$ ${p.valorUnitario.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Icon(Icons.add_circle_outline, color: Color(0xFF00FF88), size: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════
// BOTTOM SHEET: Busca de Patrimônio
// ══════════════════════════════════════════════

class _BuscaPatrimonioSheet extends StatefulWidget {
  final List<PatrimonioEstoque> patrimonios;
  final List<ProdutoEstoque> produtosRef;
  final Function(PatrimonioEstoque, ProdutoEstoque) onSelecionado;

  const _BuscaPatrimonioSheet({
    required this.patrimonios,
    required this.produtosRef,
    required this.onSelecionado,
  });

  @override
  State<_BuscaPatrimonioSheet> createState() => _BuscaPatrimonioSheetState();
}

class _BuscaPatrimonioSheetState extends State<_BuscaPatrimonioSheet> {
  final TextEditingController _buscaController = TextEditingController();
  List<PatrimonioEstoque> _filtrados = [];
  String _tipoBusca = 'serial'; // serial, mac, patrimonial

  @override
  void initState() {
    super.initState();
    _filtrados = widget.patrimonios;
  }

  void _filtrar(String texto) {
    setState(() {
      if (texto.isEmpty) {
        _filtrados = widget.patrimonios;
      } else {
        final busca = texto.toLowerCase();
        _filtrados = widget.patrimonios.where((p) {
          switch (_tipoBusca) {
            case 'serial':
              return p.serial.toLowerCase().contains(busca);
            case 'mac':
              return p.mac.toLowerCase().contains(busca);
            case 'patrimonial':
              return p.id.contains(busca);
            default:
              return p.serial.toLowerCase().contains(busca) ||
                  p.mac.toLowerCase().contains(busca) ||
                  p.descricao.toLowerCase().contains(busca);
          }
        }).toList();
      }
    });
  }

  ProdutoEstoque _getProdutoRef(PatrimonioEstoque patrimonio) {
    return widget.produtosRef.firstWhere(
          (p) => p.id == patrimonio.idProduto,
      orElse: () => ProdutoEstoque(
        id: patrimonio.idProduto,
        descricao: patrimonio.descricao,
        valor: patrimonio.valorBem,
        tipo: 'P',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.router, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selecionar Patrimônio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Equipamentos do seu almoxarifado', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // Tabs de tipo de busca (como no InMap)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTipoBuscaChip('Núm. patrimonial', 'patrimonial'),
                  const SizedBox(width: 8),
                  _buildTipoBuscaChip('Núm. de série', 'serial'),
                  const SizedBox(width: 8),
                  _buildTipoBuscaChip('MAC', 'mac'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Campo de busca
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _buscaController,
                onChanged: _filtrar,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _tipoBusca == 'serial' ? 'Buscar por número de série...'
                      : _tipoBusca == 'mac' ? 'Buscar por endereço MAC...'
                      : 'Buscar por número patrimonial...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF232323),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('${_filtrados.length} patrimônio(s)', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),

            // Lista
            Expanded(
              child: _filtrados.isEmpty
                  ? const Center(child: Text('Nenhum resultado encontrado', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtrados.length,
                itemBuilder: (context, index) {
                  final pat = _filtrados[index];
                  final prod = _getProdutoRef(pat);

                  return InkWell(
                    onTap: () => widget.onSelecionado(pat, prod),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232323),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          // Ícone
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.router, color: Colors.orange, size: 24),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pat.descricao, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('S/N: ${pat.serial}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    if (pat.mac.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text('MAC: ${pat.mac}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ],
                                ),
                                Text('R\$ ${pat.valorBem.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),

                          const Icon(Icons.add_circle_outline, color: Colors.orange, size: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTipoBuscaChip(String label, String tipo) {
    final selecionado = _tipoBusca == tipo;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tipoBusca = tipo;
            _filtrar(_buscaController.text);
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? Colors.orange : const Color(0xFF232323),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selecionado ? Colors.orange : Colors.white24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selecionado ? Colors.white : Colors.white54,
              fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}