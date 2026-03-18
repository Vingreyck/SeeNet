// lib/seguranca/widgets/dialog_aprovacao_epi.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';
import '../controllers/seguranca_controller.dart';

class DialogAprovacaoEpi extends StatefulWidget {
  final Map<String, dynamic> requisicao;

  const DialogAprovacaoEpi({super.key, required this.requisicao});

  @override
  State<DialogAprovacaoEpi> createState() => _DialogAprovacaoEpiState();
}

class _DialogAprovacaoEpiState extends State<DialogAprovacaoEpi> {
  final _service = Get.find<SegurancaService>();
  final _controller = Get.find<SegurancaController>();
  final _obsController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;

  List<Map<String, dynamic>> _almoxarifados = [];
  List<Map<String, dynamic>> _mapeamentoEpi = [];
  String? _almoxSelecionadoId;
  String? _almoxSelecionadoNome;

  // Cada EPI solicitado → {id_produto, descricao_ixc, quantidade, tamanho}
  List<Map<String, dynamic>> _itensVinculados = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final almox = await _service.buscarAlmoxarifadosColaboradores();
    final mapeamento = await _service.buscarMapeamentoEpi();

    final epis = widget.requisicao['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];

    // Vincular automaticamente cada EPI ao produto IXC correspondente
    final itens = <Map<String, dynamic>>[];
    for (final epi in episLista) {
      final epiLimpo = epi.replaceAll(RegExp(r'\s*\(Tam\.\s*\w+\)'), '');
      final match = mapeamento.firstWhereOrNull(
            (m) => m['epi'] == epiLimpo,
      );
      itens.add({
        'epi': epi, // mantém o nome original com tamanho
        'epi_limpo': epiLimpo, // pra referência
        'id_produto': match?['id_produto'],
        'descricao_ixc': match?['descricao_ixc'],
        'quantidade': 1,
        'tamanhos': match?['tamanhos'] != null
            ? List<String>.from(match!['tamanhos'])
            : null,
        'tamanho_selecionado': null,
        'vinculado': match?['id_produto'] != null,
      });
    }

    setState(() {
      _almoxarifados = almox;
      _mapeamentoEpi = mapeamento;
      _itensVinculados = itens;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FF88)))
            : ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            const Text('Aprovar Requisição',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Técnico: ${widget.requisicao['tecnico_nome']}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // ── Almoxarifado do Colaborador ──
            _buildSectionTitle('Almoxarifado do Colaborador *'),
            const SizedBox(height: 4),
            const Text(
              'Selecione o almoxarifado do técnico que receberá os EPIs',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 8),
            _buildDropdownAlmoxarifado(),
            const SizedBox(height: 20),

            // ── Itens Vinculados ──
            _buildSectionTitle('EPIs → Produtos IXC'),
            const SizedBox(height: 4),
            const Text(
              'Vinculação automática. Ajuste quantidade e tamanho se necessário.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 10),
            ..._itensVinculados
                .asMap()
                .entries
                .map((e) => _buildItemCard(e.key, e.value)),
            const SizedBox(height: 16),

            // ── Observação ──
            _buildSectionTitle('Observação (opcional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _obsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Observação para o técnico...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Resumo ──
            _buildResumo(),
            const SizedBox(height: 20),

            // ── Botões ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSending
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _aprovar,
                    icon: _isSending
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.check,
                        color: Colors.black, size: 20),
                    label: Text(
                      _isSending ? 'Aprovando...' : 'Aprovar e Descontar',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor:
                      const Color(0xFF00FF88).withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3));
  }

  // ── Dropdown Almoxarifado ─────────────────────────────────────
  Widget _buildDropdownAlmoxarifado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _almoxSelecionadoId != null
              ? const Color(0xFF00FF88).withOpacity(0.4)
              : Colors.white12,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _almoxSelecionadoId,
          hint: const Text('Selecione o almoxarifado',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          isExpanded: true,
          menuMaxHeight: 300,
          onChanged: (v) {
            final almox = _almoxarifados.firstWhere((a) => a['id'].toString() == v);
            setState(() {
              _almoxSelecionadoId = v;
              _almoxSelecionadoNome = almox['descricao'];
            });
          },
          items: _almoxarifados.map((a) {
            return DropdownMenuItem<String>(
              value: a['id'].toString(),
              child: Text(
                '${a['id']} - ${a['descricao']}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Card de cada item EPI ─────────────────────────────────────
  Widget _buildItemCard(int index, Map<String, dynamic> item) {
    final vinculado = item['vinculado'] == true;
    final tamanhos = item['tamanhos'] as List<String>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: vinculado
              ? const Color(0xFF00FF88).withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // EPI solicitado
          Row(
            children: [
              Icon(
                vinculado ? Icons.link : Icons.link_off,
                color: vinculado ? const Color(0xFF00FF88) : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item['epi'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          if (vinculado) ...[
            const SizedBox(height: 6),
            // Produto IXC vinculado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '→ ${item['descricao_ixc']} (ID ${item['id_produto']})',
                style:
                const TextStyle(color: Color(0xFF00FF88), fontSize: 11),
              ),
            ),

            const SizedBox(height: 8),

            // Quantidade + Tamanho
            Row(
              children: [
                // Quantidade
                const Text('Qtd:',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (item['quantidade'] > 1) {
                      setState(() => _itensVinculados[index]['quantidade']--);
                    }
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child:
                      Icon(Icons.remove, color: Colors.white54, size: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${item['quantidade']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _itensVinculados[index]['quantidade']++);
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child:
                      Icon(Icons.add, color: Color(0xFF00FF88), size: 16),
                    ),
                  ),
                ),

                // Tamanho (se aplicável)
                if (tamanhos != null) ...[
                  const SizedBox(width: 16),
                  const Text('Tam:',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: tamanhos.map((t) {
                          final sel = item['tamanho_selecionado'] == t;
                          return GestureDetector(
                            onTap: () => setState(() =>
                            _itensVinculados[index]
                            ['tamanho_selecionado'] = t),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFF00FF88)
                                    : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFF00FF88)
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                    color:
                                    sel ? Colors.black : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '⚠ Sem produto vinculado no IXC — não será descontado',
                style: TextStyle(color: Colors.orange, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Resumo ────────────────────────────────────────────────────
  Widget _buildResumo() {
    final vinculados =
        _itensVinculados.where((i) => i['vinculado'] == true).length;
    final naoVinculados = _itensVinculados.length - vinculados;
    final totalItens = _itensVinculados
        .where((i) => i['vinculado'] == true)
        .fold<int>(0, (sum, i) => sum + (i['quantidade'] as int));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF88).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo da Aprovação',
              style: TextStyle(
                  color: Color(0xFF00FF88),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildResumoRow('📦 Almoxarifado destino',
              _almoxSelecionadoNome ?? 'Não selecionado'),
          _buildResumoRow('✅ Itens vinculados ao IXC', '$vinculados'),
          _buildResumoRow('📊 Total de itens a descontar', '$totalItens'),
          if (naoVinculados > 0)
            _buildResumoRow('⚠ Sem vínculo IXC', '$naoVinculados'),
        ],
      ),
    );
  }

  Widget _buildResumoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Aprovar ───────────────────────────────────────────────────
  Future<void> _aprovar() async {
    // Validar almoxarifado
    if (_almoxSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione o almoxarifado do colaborador'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Validar tamanhos obrigatórios
    for (final item in _itensVinculados) {
      if (item['vinculado'] == true &&
          item['tamanhos'] != null &&
          item['tamanho_selecionado'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Selecione o tamanho de: ${item['epi']}'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSending = true);

    try {
      // Montar itens_ixc (só os vinculados)
      final itensIxc = _itensVinculados
          .where((i) => i['vinculado'] == true && i['id_produto'] != null)
          .map((i) {
        String descricao = i['descricao_ixc'] ?? i['epi'];
        if (i['tamanho_selecionado'] != null) {
          descricao += ' - Tam. ${i['tamanho_selecionado']}';
        }
        return {
          'id_produto': i['id_produto'],
          'descricao': descricao,
          'quantidade': i['quantidade'],
        };
      }).toList();

      // Montar observação com tamanhos e almoxarifado
      String obs = _obsController.text.trim();
      final tamanhosInfo = _itensVinculados
          .where((i) =>
      i['vinculado'] == true && i['tamanho_selecionado'] != null)
          .map((i) => '${i['epi']}: ${i['tamanho_selecionado']}')
          .toList();
      if (tamanhosInfo.isNotEmpty) {
        obs += (obs.isNotEmpty ? '\n' : '') +
            'Tamanhos: ${tamanhosInfo.join(', ')}';
      }
      if (_almoxSelecionadoNome != null) {
        obs += (obs.isNotEmpty ? '\n' : '') +
            'Almox: $_almoxSelecionadoNome (ID $_almoxSelecionadoId)';
      }

      final result = await _controller.aprovar(
        widget.requisicao['id'] as int,
        observacao: obs,
        itensIxc: itensIxc.cast<Map<String, dynamic>>(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Aprovado!'),
          backgroundColor:
          result['success'] == true ? const Color(0xFF00C853) : Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}