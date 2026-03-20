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
            'Toque em um produto para editar CA e Fornecedor. Esses dados aparecerão no PDF da ficha de EPI.',
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
    final tamanhos = produto['tamanhos'];
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

            // Tamanhos
            if (tamanhos != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Tamanhos: ',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(
                    (tamanhos is List ? tamanhos.join(', ') : tamanhos.toString()),
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
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

  // ── Dialog Editar CA/Fornecedor ────────────────────────────────
  void _dialogEditarProduto(Map<String, dynamic> produto) {
    final caCtrl = TextEditingController(text: produto['ca'] ?? 'N/A');
    final fornCtrl = TextEditingController(text: produto['fornecedor'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(produto['nome'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (produto['id_produto_ixc'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'IXC: ${produto['descricao_ixc']} (ID ${produto['id_produto_ixc']})',
                  style:
                  const TextStyle(color: Color(0xFF00FF88), fontSize: 11),
                ),
              ),
            const Text('CA (Certificado de Aprovação)',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: caCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex: 39.457 ou N/A',
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
            const Text('Fornecedor / Fabricante',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: fornCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex: LIBUS BRASIL',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
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
              final result = await _service.atualizarProdutoEpi(
                produto['id'] as int,
                ca: caCtrl.text.trim(),
                fornecedor: fornCtrl.text.trim(),
              );
              if (result['success'] == true) {
                _carregar();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Produto atualizado!'),
                    backgroundColor: Color(0xFF00C853),
                  ));
                }
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

  // ── Dialog Adicionar Novo Produto ─────────────────────────────
  void _dialogAdicionarProduto() {
    final nomeCtrl = TextEditingController();
    final caCtrl = TextEditingController(text: 'N/A');
    final fornCtrl = TextEditingController();
    final idIxcCtrl = TextEditingController();

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
              const Text('Nome do EPI *',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nomeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: Protetor Auricular',
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
              const Text('ID Produto IXC (opcional)',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: idIxcCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ex: 397',
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
              const Text('CA',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: caCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: 39.457 ou N/A',
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
              const Text('Fornecedor',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: fornCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: LIBUS BRASIL',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
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
                ca: caCtrl.text.trim(),
                fornecedor: fornCtrl.text.trim(),
              );
              if (result['success'] == true) {
                _carregar();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Produto cadastrado!'),
                    backgroundColor: Color(0xFF00C853),
                  ));
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message'] ?? 'Erro'),
                    backgroundColor: Colors.red,
                  ));
                }
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