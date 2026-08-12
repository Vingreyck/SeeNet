// lib/seguranca/widgets/aba_produtos_epi.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';

class AbaProdutosEpi extends StatefulWidget {
  const AbaProdutosEpi({super.key});

  @override
  State<AbaProdutosEpi> createState() => _AbaProdutosEpiState();
}

class _AbaProdutosEpiState extends State<AbaProdutosEpi> {
  final _service = Get.find<SegurancaService>();
  List<Map<String, dynamic>> _produtos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    final lista = await _service.buscarProdutosEpiCadastro();
    setState(() {
      _produtos = lista;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00FF88)));
    }

    return Column(
      children: [
        // Header com botão adicionar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Color(0xFF00FF88), size: 20),
              const SizedBox(width: 8),
              Text('${_produtos.length} produto(s) cadastrado(s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: _dialogAdicionarProduto,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Color(0xFF00FF88), size: 16),
                      SizedBox(width: 4),
                      Text('Novo',
                          style: TextStyle(
                              color: Color(0xFF00FF88),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Legenda
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Toque no produto (ou no ⋮) para editar. CA e Fornecedor aparecem no PDF da ficha de EPI; os Tamanhos viram as opções que o técnico escolhe ao pedir.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        const SizedBox(height: 8),

        // Lista
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregar,
            color: const Color(0xFF00FF88),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _produtos.length,
              itemBuilder: (context, i) => _buildCard(_produtos[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> produto) {
    final ca = produto['ca'] as String? ?? 'N/A';
    final fornecedor = produto['fornecedor'] as String? ?? '';
    final idIxc = produto['id_produto_ixc'];
    final descIxc = produto['descricao_ixc'] as String? ?? '';
    final tamanhos = SegurancaService.parseTamanhos(produto['tamanhos']);
    final temCA = ca.isNotEmpty && ca != 'N/A';
    final temFornecedor = fornecedor.isNotEmpty;

    return GestureDetector(
      onTap: () => _dialogEditarProduto(produto),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (temCA && temFornecedor)
                ? const Color(0xFF00FF88).withOpacity(0.2)
                : Colors.orange.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome do produto
            Row(
              children: [
                Expanded(
                  child: Text(produto['nome'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(
                  (temCA && temFornecedor)
                      ? Icons.check_circle
                      : Icons.warning_amber,
                  color: (temCA && temFornecedor)
                      ? const Color(0xFF00FF88)
                      : Colors.orange,
                  size: 18,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white38, size: 18),
                  color: const Color(0xFF2A2A2A),
                  padding: EdgeInsets.zero,
                  onSelected: (opcao) {
                    if (opcao == 'editar') _dialogEditarProduto(produto);
                    if (opcao == 'excluir') _confirmarExcluir(produto);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: Row(children: [
                        Icon(Icons.edit, color: Colors.white70, size: 16),
                        SizedBox(width: 8),
                        Text('Editar', style: TextStyle(color: Colors.white70)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // IXC vinculado
            if (idIxc != null) ...[
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'IXC: $descIxc (ID $idIxc)',
                  style:
                  const TextStyle(color: Color(0xFF00FF88), fontSize: 10),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // CA e Fornecedor
            Row(
              children: [
                _buildInfoChip('CA', ca, temCA),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Fornecedor',
                    temFornecedor ? fornecedor : 'Não informado',
                    temFornecedor,
                  ),
                ),
              ],
            ),

            // Tamanhos — passa pelo parse porque a coluna pode voltar como
            // lista OU como string JSON; sem isso apareceria `["P","M"]` cru.
            if (tamanhos.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Tamanhos: ',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Expanded(
                    child: Text(
                      tamanhos.join(', '),
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, bool preenchido) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: preenchido
            ? const Color(0xFF1A1A1A)
            : Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: preenchido ? Colors.white12 : Colors.orange.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Flexible(
            child: Text(value,
                style: TextStyle(
                  color: preenchido ? Colors.white70 : Colors.orange,
                  fontSize: 11,
                  fontWeight: preenchido ? FontWeight.normal : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _campo(String rotulo, TextEditingController ctrl, String dica,
      {TextInputType? teclado}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: teclado,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: dica,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // ── Dialog Editar ──────────────────────────────────────────────
  void _dialogEditarProduto(Map<String, dynamic> produto) {
    final nomeCtrl = TextEditingController(text: produto['nome'] ?? '');
    final caCtrl = TextEditingController(text: produto['ca'] ?? 'N/A');
    final fornCtrl = TextEditingController(text: produto['fornecedor'] ?? '');
    final idIxcCtrl = TextEditingController(
        text: produto['id_produto_ixc']?.toString() ?? '');
    final descIxcCtrl =
        TextEditingController(text: produto['descricao_ixc'] ?? '');
    final tamanhos =
        List<String>.from(SegurancaService.parseTamanhos(produto['tamanhos']));
    final nomeOriginal = (produto['nome'] ?? '').toString();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar EPI',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _campo('Nome do EPI *', nomeCtrl, 'Ex: Bota de Segurança'),
              _campo('ID Produto IXC (opcional)', idIxcCtrl, 'Ex: 397',
                  teclado: TextInputType.number),
              _campo('Descrição no IXC (opcional)', descIxcCtrl,
                  'Ex: BOTA DE SEGURANCA'),
              _campo('CA (Certificado de Aprovação)', caCtrl,
                  'Ex: 39.457 ou N/A'),
              _campo('Fornecedor / Fabricante', fornCtrl, 'Ex: LIBUS BRASIL'),
              _EditorTamanhos(tamanhos: tamanhos),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = nomeCtrl.text.trim();
              if (nome.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Nome obrigatório'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              Navigator.pop(context);

              // Renomear é o único campo com efeito colateral: as requisições
              // guardam o NOME do EPI em texto. As antigas ficam com o nome
              // velho (histórico preservado); só as novas usam o nome novo.
              if (nome != nomeOriginal && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Renomeado para "$nome". Requisições antigas continuam com o nome anterior.'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ));
              }

              final result = await _service.atualizarProdutoEpi(
                produto['id'] as int,
                nome: nome,
                idProdutoIxc: idIxcCtrl.text.trim(),
                descricaoIxc: descIxcCtrl.text.trim(),
                ca: caCtrl.text.trim(),
                fornecedor: fornCtrl.text.trim(),
                tamanhos: tamanhos,
              );
              if (!mounted) return;
              if (result['success'] == true) {
                _carregar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Produto atualizado!'),
                  backgroundColor: Color(0xFF00C853),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? 'Erro ao atualizar'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88)),
            child:
            const Text('Salvar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ── Dialog Excluir ─────────────────────────────────────────────
  void _confirmarExcluir(Map<String, dynamic> produto) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir EPI?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${produto['nome']}" sai da lista de EPIs que o técnico pode pedir.',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 10),
            const Text(
              'As requisições que já usaram este EPI continuam intactas — o produto só é desativado, nada é apagado.',
              style: TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result =
                  await _service.removerProdutoEpi(produto['id'] as int);
              if (!mounted) return;
              if (result['success'] == true) {
                _carregar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Produto removido!'),
                  backgroundColor: Color(0xFF00C853),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Erro ao remover'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Dialog Adicionar Novo Produto ─────────────────────────────
  void _dialogAdicionarProduto() {
    final nomeCtrl = TextEditingController();
    final caCtrl = TextEditingController(text: 'N/A');
    final fornCtrl = TextEditingController();
    final idIxcCtrl = TextEditingController();
    final descIxcCtrl = TextEditingController();
    final tamanhos = <String>[];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Novo Produto EPI',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _campo('Nome do EPI *', nomeCtrl, 'Ex: Protetor Auricular'),
              _campo('ID Produto IXC (opcional)', idIxcCtrl, 'Ex: 397',
                  teclado: TextInputType.number),
              _campo('Descrição no IXC (opcional)', descIxcCtrl,
                  'Ex: BOTA DE SEGURANCA'),
              _campo('CA', caCtrl, 'Ex: 39.457 ou N/A'),
              _campo('Fornecedor', fornCtrl, 'Ex: LIBUS BRASIL'),
              _EditorTamanhos(tamanhos: tamanhos),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomeCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Nome obrigatório'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              Navigator.pop(context);
              final result = await _service.criarProdutoEpi(
                nome: nomeCtrl.text.trim(),
                idProdutoIxc: idIxcCtrl.text.trim().isNotEmpty
                    ? idIxcCtrl.text.trim()
                    : null,
                descricaoIxc: descIxcCtrl.text.trim().isNotEmpty
                    ? descIxcCtrl.text.trim()
                    : null,
                ca: caCtrl.text.trim(),
                fornecedor: fornCtrl.text.trim(),
                tamanhos: tamanhos,
              );
              if (!mounted) return;
              if (result['success'] == true) {
                _carregar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Produto cadastrado!'),
                  backgroundColor: Color(0xFF00C853),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? 'Erro'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88)),
            child: const Text('Cadastrar',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

/// 📏 Editor dos tamanhos do EPI (bota, camisa, calça...).
///
/// Escreve DIRETO na lista recebida em [tamanhos] — o dialog que o contém lê
/// essa mesma lista na hora de salvar. Sem tamanho nenhum, o técnico não vê
/// seletor de tamanho ao pedir o EPI (que é o comportamento de capacete, luva
/// e afins).
class _EditorTamanhos extends StatefulWidget {
  final List<String> tamanhos;

  const _EditorTamanhos({required this.tamanhos});

  @override
  State<_EditorTamanhos> createState() => _EditorTamanhosState();
}

class _EditorTamanhosState extends State<_EditorTamanhos> {
  final _ctrl = TextEditingController();

  // Atalhos pros dois casos reais: roupa (letra) e calçado/calça (número).
  static const _sugestoes = <String, List<String>>{
    'Roupa (P ao GG)': ['P', 'M', 'G', 'GG'],
    'Calçado (36 ao 46)': ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'],
  };

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _adicionar(String valor) {
    final v = valor.trim().toUpperCase();
    if (v.isEmpty) return;
    if (widget.tamanhos.contains(v)) {
      _ctrl.clear();
      return;
    }
    setState(() => widget.tamanhos.add(v));
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tamanhos (opcional)',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        const Text(
          'Se preencher, o técnico escolhe o tamanho ao pedir este EPI.',
          style: TextStyle(color: Colors.white30, fontSize: 10.5),
        ),
        const SizedBox(height: 8),

        if (widget.tamanhos.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.tamanhos
                .map((t) => Chip(
                      label: Text(t,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                      backgroundColor: const Color(0xFF1A1A1A),
                      side: BorderSide(
                          color: const Color(0xFF00FF88).withOpacity(0.35)),
                      deleteIcon:
                          const Icon(Icons.close, size: 14, color: Colors.white54),
                      onDeleted: () => setState(() => widget.tamanhos.remove(t)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: _adicionar,
                decoration: InputDecoration(
                  hintText: 'Ex: 42 ou GG',
                  hintStyle: const TextStyle(color: Colors.white38),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _adicionar(_ctrl.text),
              icon: const Icon(Icons.add_circle, color: Color(0xFF00FF88)),
              tooltip: 'Adicionar tamanho',
            ),
          ],
        ),

        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            ..._sugestoes.entries.map((e) => ActionChip(
                  label: Text(e.key,
                      style: const TextStyle(
                          color: Color(0xFF00FF88), fontSize: 10.5)),
                  backgroundColor: const Color(0xFF00FF88).withOpacity(0.08),
                  side: BorderSide(
                      color: const Color(0xFF00FF88).withOpacity(0.3)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    for (final t in e.value) {
                      if (!widget.tamanhos.contains(t)) widget.tamanhos.add(t);
                    }
                  }),
                )),
            if (widget.tamanhos.isNotEmpty)
              ActionChip(
                label: const Text('Limpar',
                    style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                backgroundColor: const Color(0xFF1A1A1A),
                side: const BorderSide(color: Colors.white24),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(widget.tamanhos.clear),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}