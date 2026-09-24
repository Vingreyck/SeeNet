// lib/seguranca/screens/gestao_requisicoes_screen.dart — REDESIGN
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';
import 'perfil_tecnico_gestor_screen.dart';
import '../widgets/aba_produtos_epi.dart';
import '../widgets/dialog_aprovacao_epi.dart';
import '../controllers/seguranca_controller.dart';

class GestaoRequisicoesScreen extends StatefulWidget {
  const GestaoRequisicoesScreen({super.key});

  @override
  State<GestaoRequisicoesScreen> createState() =>
      _GestaoRequisicoesScreenState();
}

class _GestaoRequisicoesScreenState extends State<GestaoRequisicoesScreen>
    with SingleTickerProviderStateMixin {
  final controller = Get.find<SegurancaController>();
  late TabController _tabController;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    final initialTab = args?['initialTab'] as int? ?? 0;
    _tabController =
        TabController(length: 5, vsync: this, initialIndex: initialTab);
    controller.carregarPendentes();
    controller.carregarDevolucoesPendentes();
    controller.carregarDevedores();
    controller.carregarAguardandoValidacao();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmarAprovacao(Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DialogAprovacaoEpi(requisicao: req),
    );
  }

  /// ✏️ Abre a folha pro gestor ajustar os itens do pedido.
  void _editarPedido(Map<String, dynamic> req) {
    final bruto = req['epis_solicitados'];
    final List<String> textos = bruto is List ? bruto.cast<String>() : [];

    if (textos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Este pedido não tem itens para ajustar'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditarPedidoSheet(
        requisicaoId: req['id'] as int,
        tecnicoNome: (req['tecnico_nome'] ?? 'Técnico').toString(),
        itensOriginais: textos,
        controller: controller,
      ),
    );
  }

  void _confirmarRecusa(int id) {
    final obsController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Recusar Requisição',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o motivo da recusa:',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Motivo da recusa *',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF111111),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF00FF88), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (obsController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Informe o motivo da recusa'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context);
              final result = await controller.recusar(id,
                  observacao: obsController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? ''),
                  backgroundColor:
                  result['success'] == true ? Colors.orange : Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Recusar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _aprovarDevolucao(Map<String, dynamic> dev) {
    String? codigoSelecionado;
    final codigos = ['PE', 'SP', 'DT', 'IU', 'AD', 'DE'];
    final descricoes = {
      'PE': 'Perda ou Extravio',
      'SP': 'Subst. (Perda Vida Útil)',
      'DT': 'Danificado p/ Trabalho',
      'IU': 'Impróprio para Uso',
      'AD': 'Apresenta Defeito',
      'DE': 'Deslig. da Empresa',
    };

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: const Text('Aprovar Devolução',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EPI: ${dev['epi_nome']}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
              Text('Técnico: ${dev['tecnico_nome']}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Código de Substituição:',
                  style:
                  TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: codigos.map((cod) => ChoiceChip(
                  label: Text('$cod - ${descricoes[cod]}',
                      style: TextStyle(
                          color: codigoSelecionado == cod
                              ? Colors.black
                              : Colors.white70,
                          fontSize: 11)),
                  selected: codigoSelecionado == cod,
                  selectedColor: const Color(0xFF00FF88),
                  backgroundColor: const Color(0xFF111111),
                  onSelected: (sel) => setDialogState(
                          () => codigoSelecionado = sel ? cod : null),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: codigoSelecionado == null
                  ? null
                  : () async {
                Navigator.pop(dialogContext);
                final result = await Get.find<SegurancaService>()
                    .aprovarDevolucao(
                    dev['id'] as int, codigoSelecionado!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message'] ?? ''),
                    backgroundColor: result['success'] == true
                        ? const Color(0xFF00C853)
                        : Colors.red,
                  ));
                  controller.carregarDevolucoesPendentes();
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88)),
              child: const Text('Aprovar',
                  style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _recusarDevolucao(int id) {
    final obsController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Recusar Devolução',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('O técnico será marcado como DEVEDOR.',
                style: TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Observação (opcional)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF111111),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await Get.find<SegurancaService>()
                  .recusarDevolucao(id,
                  observacao: obsController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? ''),
                  backgroundColor: result['success'] == true
                      ? Colors.orange
                      : Colors.red,
                ));
                controller.carregarDevolucoesPendentes();
                controller.carregarDevedores();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Marcar Devedor',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatarData(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '--';
    }
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 0, left: 8, right: 16,
            ),
            color: const Color(0xFF111111),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gestão de Requisições',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3)),
                          Text('EPIs • Devoluções • Estoque',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white38, size: 20),
                      onPressed: () {
                        controller.carregarPendentes();
                        controller.carregarDevolucoesPendentes();
                        controller.carregarDevedores();
                        setState(() {});
                      },
                    ),
                  ],
                ),

                // ── Tabs ────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Obx(() => TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      color: const Color(0xFF00FF88),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 12),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                          text:
                          'Pendentes (${controller.requisicoesPendentes.length})'),
                      Tab(
                          text:
                          'Devoluções (${controller.devolucoesPendentes.length})'),
                      const Tab(text: 'Produtos'),
                      Tab(
                          text:
                          'Devedores (${controller.devedores.length})'),
                      Tab(
                          text:
                          'Validar (${controller.requisicoesAguardandoValidacao.length})'),
                    ],
                  )),
                ),
              ],
            ),
          ),

          // ── Conteúdo ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaPendentes(),
                _buildListaDevolucoes(),
                const AbaProdutosEpi(),
                _buildListaDevedores(),
                _buildListaValidacao(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ABAs ─────────────────────────────────────────────────────

  Widget _buildListaPendentes() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF00FF88), strokeWidth: 2.5));
      }
      if (controller.requisicoesPendentes.isEmpty) {
        return _buildVazio('Nenhuma requisição pendente',
            Icons.check_circle_outline_rounded);
      }
      return RefreshIndicator(
        onRefresh: controller.carregarPendentes,
        color: const Color(0xFF00FF88),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: controller.requisicoesPendentes.length,
          itemBuilder: (context, i) =>
              _buildCardPendente(controller.requisicoesPendentes[i]),
        ),
      );
    });
  }

  Widget _buildCardPendente(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista =
    epis is List ? epis.cast<String>() : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.12),
                    border: Border.all(
                        color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.orange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['tecnico_nome'] ?? 'Técnico',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(_formatarData(req['data_criacao']),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                // ✏️ Ajustar o pedido sem precisar recusar. Faltando um item
                // no estoque, o gestor tira só ele (ou troca tamanho/qtde) e
                // aprova o resto — antes o técnico tinha que refazer tudo.
                Tooltip(
                  message: 'Ajustar itens do pedido',
                  child: InkWell(
                    onTap: () => _editarPedido(req),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.35)),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.blue, size: 16),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('PENDENTE',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // EPIs
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${episLista.length} EPI(s) solicitado(s):',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5, runSpacing: 5,
                  children: episLista
                      .map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(e,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),
          // Ações
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmarRecusa(req['id'] as int),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.red),
                    label: const Text('Recusar',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(() => ElevatedButton.icon(
                    onPressed: controller.isSending.value
                        ? null
                        : () => _confirmarAprovacao(req),
                    icon: const Icon(Icons.check_rounded,
                        size: 16, color: Colors.black),
                    label: const Text('Aprovar',
                        style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════ #2: ABA "VALIDAR" (gestor confere assinatura) ════════════
  Widget _buildListaValidacao() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFFB388FF), strokeWidth: 2.5));
      }
      if (controller.requisicoesAguardandoValidacao.isEmpty) {
        return _buildVazio(
            'Nenhuma assinatura para validar', Icons.fact_check_outlined);
      }
      return RefreshIndicator(
        onRefresh: controller.carregarAguardandoValidacao,
        color: const Color(0xFFB388FF),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: controller.requisicoesAguardandoValidacao.length,
          itemBuilder: (context, i) => _buildCardValidacao(
              controller.requisicoesAguardandoValidacao[i]),
        ),
      );
    });
  }

  Widget _buildImagemBase64(String? b64, String label, IconData icone) {
    final temImg = b64 != null && b64.isNotEmpty;
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 4),
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: temImg ? Colors.white : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            clipBehavior: Clip.antiAlias,
            child: temImg
                ? Builder(builder: (_) {
                    try {
                      return Image.memory(base64Decode(b64.split(',').last),
                          fit: BoxFit.contain);
                    } catch (_) {
                      return const Center(
                          child:
                              Icon(Icons.broken_image, color: Colors.white24));
                    }
                  })
                : Center(child: Icon(icone, color: Colors.white24, size: 22)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardValidacao(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];
    const roxo = Color(0xFFB388FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: roxo.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: roxo.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fact_check_rounded, color: roxo, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['tecnico_nome'] ?? 'Técnico',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(
                          'Assinou em ${_formatarData(req['data_confirmacao_recebimento']?.toString())}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${episLista.length} EPI(s):',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: episLista
                      .map((e) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(e,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagemBase64(req['foto_recebimento_base64'] as String?,
                        'Foto', Icons.photo_camera_outlined),
                    const SizedBox(width: 10),
                    _buildImagemBase64(
                        req['assinatura_recebimento_base64'] as String?,
                        'Assinatura',
                        Icons.draw_outlined),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmarReprovacaoValidacao(req['id'] as int),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.red),
                    label: const Text('Reprovar',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(() => ElevatedButton.icon(
                        onPressed: controller.isSending.value
                            ? null
                            : () => _aceitarValidacao(req['id'] as int),
                        icon: const Icon(Icons.check_rounded,
                            size: 16, color: Colors.black),
                        label: const Text('Aceitar',
                            style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _aceitarValidacao(int id) async {
    final result = await controller.validarRecebimento(id, aprovar: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? ''),
        backgroundColor:
            result['success'] == true ? const Color(0xFF00AA66) : Colors.red,
      ));
    }
  }

  void _confirmarReprovacaoValidacao(int id) {
    final obsController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reprovar assinatura',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'O técnico vai precisar assinar de novo. Informe o motivo:',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Motivo da reprovação *',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF111111),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF00FF88), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (obsController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Informe o motivo da reprovação'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context);
              final result = await controller.validarRecebimento(id,
                  aprovar: false, observacao: obsController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? ''),
                  backgroundColor:
                      result['success'] == true ? Colors.orange : Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Reprovar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildListaDevolucoes() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF00FF88), strokeWidth: 2.5));
      }
      if (controller.devolucoesPendentes.isEmpty) {
        return _buildVazio('Nenhuma devolução pendente',
            Icons.assignment_return_outlined);
      }
      return RefreshIndicator(
        onRefresh: controller.carregarDevolucoesPendentes,
        color: const Color(0xFF00FF88),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: controller.devolucoesPendentes.length,
          itemBuilder: (context, i) =>
              _buildCardDevolucao(controller.devolucoesPendentes[i]),
        ),
      );
    });
  }

  Widget _buildCardDevolucao(Map<String, dynamic> dev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.12),
                    border:
                    Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.assignment_return_rounded,
                      color: Colors.blue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dev['tecnico_nome'] ?? 'Técnico',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(dev['epi_nome'] ?? '',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Text(
                          _formatarData(
                              dev['data_devolucao']?.toString()),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('DEVOLUÇÃO',
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _recusarDevolucao(dev['id'] as int),
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.red),
                    label: const Text('Não Devolveu',
                        style:
                        TextStyle(color: Colors.red, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _aprovarDevolucao(dev),
                    icon: const Icon(Icons.check_rounded,
                        size: 16, color: Colors.black),
                    label: const Text('Confirmar',
                        style: TextStyle(
                            color: Colors.black, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaDevedores() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF00FF88), strokeWidth: 2.5));
      }
      if (controller.devedores.isEmpty) {
        return _buildVazio(
            'Nenhum devedor registrado', Icons.warning_amber_outlined);
      }
      return RefreshIndicator(
        onRefresh: controller.carregarDevedores,
        color: const Color(0xFF00FF88),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: controller.devedores.length,
          itemBuilder: (context, i) {
            final dev = controller.devedores[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.warning_rounded,
                        color: Colors.red, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dev['tecnico_nome'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(dev['epi_nome'] ?? '',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)),
                        if (dev['observacao_gestor'] != null)
                          Text(dev['observacao_gestor'].toString(),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                              maxLines: 1),
                        Text(_formatarData(dev['data_resposta']?.toString()),
                            style: const TextStyle(
                                color: Colors.white24, fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('DEVEDOR',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildVazio(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 15)),
        ],
      ),
    );
  }
}

// ── ✏️ Folha de edição do pedido de EPI (gestor) ───────────────────────────
//
// Existe porque o gestor só tinha "Aprovar" e "Recusar": faltando UM item no
// estoque, ele recusava e o técnico refazia o pedido inteiro. Aqui ele tira o
// item que faltou, corrige tamanho ou quantidade, e aprova o resto.
//
// Os itens vêm como TEXTO ("Bota de Segurança (Tam. 45) x2"). A folha
// desmonta com `parseItemEpi`, edita as partes e monta de volta com
// `montarItemEpi` — mesmo formato que o app do técnico gera, senão o PDF da
// ficha e o histórico saem errados.
class _EditarPedidoSheet extends StatefulWidget {
  final int requisicaoId;
  final String tecnicoNome;
  final List<String> itensOriginais;
  final SegurancaController controller;

  const _EditarPedidoSheet({
    required this.requisicaoId,
    required this.tecnicoNome,
    required this.itensOriginais,
    required this.controller,
  });

  @override
  State<_EditarPedidoSheet> createState() => _EditarPedidoSheetState();
}

class _EditarPedidoSheetState extends State<_EditarPedidoSheet> {
  late List<ItemEpi> _itens;
  final _motivoCtrl = TextEditingController();
  Map<String, List<String>> _tamanhosPorEpi = {};
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _itens = widget.itensOriginais.map(SegurancaService.parseItemEpi).toList();
    _carregarTamanhos();
  }

  /// Tamanhos vêm do CADASTRO (aba Produtos). Sem isso o gestor não teria como
  /// trocar 45 → 44. Se falhar, a folha segue funcionando: só não oferece a
  /// troca de tamanho (remover e mudar quantidade continuam valendo).
  Future<void> _carregarTamanhos() async {
    final mapa = await SegurancaService().buscarTamanhosPorEpi();
    if (mounted && mapa.isNotEmpty) setState(() => _tamanhosPorEpi = mapa);
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  bool get _mudou {
    final agora = _itens.map(SegurancaService.montarItemEpi).toList();
    if (agora.length != widget.itensOriginais.length) return true;
    for (var i = 0; i < agora.length; i++) {
      if (agora[i] != widget.itensOriginais[i]) return true;
    }
    return false;
  }

  Future<void> _salvar() async {
    if (_itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('O pedido ficaria vazio. Para negar tudo, use Recusar.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _salvando = true);
    final res = await widget.controller.editarItens(
      widget.requisicaoId,
      epis: _itens.map(SegurancaService.montarItemEpi).toList(),
      motivo: _motivoCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);

    if (res['success'] == true) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${res['message'] ?? 'Pedido ajustado'} — '
            '${widget.tecnicoNome} foi avisado'),
        backgroundColor: const Color(0xFF00FF88),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${res['message']}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          // Sobe junto com o teclado quando o gestor escreve o motivo.
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ajustar pedido',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(widget.tecnicoNome,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Tire o que faltou no estoque ou corrija tamanho e '
                      'quantidade. O técnico é avisado do que mudou.',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (_itens.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: const Text(
                            'Você tirou todos os itens. Para negar o pedido '
                            'inteiro, feche aqui e use o botão Recusar.',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 12)),
                      )
                    else
                      ..._itens
                          .asMap()
                          .entries
                          .map((e) => _linhaItem(e.key, e.value)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _motivoCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Motivo (opcional)',
                        hintText: 'Ex: bota 45 em falta, enviando 44',
                        labelStyle: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                        hintStyle: const TextStyle(
                            color: Colors.white24, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF111111),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _salvando ? null : () => Navigator.pop(context),
                        child: const Text('Cancelar',
                            style: TextStyle(color: Colors.white38)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        // Travado enquanto nada mudou: evita gravar "editou"
                        // no histórico à toa e notificar o técnico sem motivo.
                        onPressed: (_salvando || !_mudou) ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black38))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_salvando
                            ? 'Salvando...'
                            : (_mudou ? 'Salvar ajuste' : 'Nada mudou')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF2A2A2A),
                          disabledForegroundColor: Colors.white30,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaItem(int i, ItemEpi item) {
    final tamanhos = _tamanhosPorEpi[item.nome] ?? const <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.nome,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              InkWell(
                onTap: () => setState(() => _itens.removeAt(i)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Qtd',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              _botaoQtd(
                  Icons.remove,
                  item.quantidade > 1
                      ? () => setState(() => _itens[i] =
                          item.copyWith(quantidade: item.quantidade - 1))
                      : null),
              Container(
                width: 34,
                alignment: Alignment.center,
                child: Text('${item.quantidade}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
              _botaoQtd(
                  Icons.add,
                  item.quantidade < 99
                      ? () => setState(() => _itens[i] =
                          item.copyWith(quantidade: item.quantidade + 1))
                      : null),
            ],
          ),
          // Tamanho só aparece se o EPI tiver tamanhos no cadastro, ou se o
          // técnico já tinha escolhido um.
          if (tamanhos.isNotEmpty || item.tamanho != null) ...[
            const SizedBox(height: 10),
            const Text('Tamanho',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              // Se o tamanho que o técnico pediu saiu do cadastro, ele aparece
              // assim mesmo — senão sumiria da tela sem o gestor entender.
              children: <String>{
                ...tamanhos,
                if (item.tamanho != null) item.tamanho!,
              }.map((t) {
                final ativo = item.tamanho == t;
                return InkWell(
                  onTap: () => setState(() => _itens[i] = ativo
                      ? item.copyWith(limparTamanho: true)
                      : item.copyWith(tamanho: t)),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ativo
                          ? Colors.blue.withOpacity(0.18)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: ativo ? Colors.blue : Colors.white12),
                    ),
                    child: Text(t,
                        style: TextStyle(
                            color: ativo ? Colors.blue : Colors.white54,
                            fontSize: 12,
                            fontWeight: ativo ? FontWeight.bold : null)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _botaoQtd(IconData icone, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icone,
              size: 15, color: onTap == null ? Colors.white12 : Colors.white54),
        ),
      );
}