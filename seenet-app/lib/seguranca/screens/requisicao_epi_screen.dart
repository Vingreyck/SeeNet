// lib/seguranca/screens/requisicao_epi_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../controllers/seguranca_controller.dart';
import '../services/seguranca_service.dart';
import '../../controllers/usuario_controller.dart';
import '../../widgets/assinatura_expandida.dart';

class RequisicaoEpiScreen extends StatefulWidget {
  const RequisicaoEpiScreen({super.key});

  @override
  State<RequisicaoEpiScreen> createState() =>
      _RequisicaoEpiScreenState();
}

class _RequisicaoEpiScreenState
    extends State<RequisicaoEpiScreen>
    with TickerProviderStateMixin {

  final SegurancaController controller =
  Get.find<SegurancaController>();

  final UsuarioController usuarioController =
  Get.find<UsuarioController>();

  final SegurancaService _service = SegurancaService();

  late TabController _tabController;

  final List<String> _passos = [
    'Selecionar',
    'Confirmar',
  ];

  Map<String, dynamic> _episDuplicados = {};

  bool _carregouDuplicados = false;

  Color get corTipo => usuarioController.isAdmin
      ? const Color(0xFFFF9800)
      : usuarioController.isGestorSeguranca
      ? const Color(0xFF2196F3)
      : const Color(0xFF00FF88);

  Color get corFundo => usuarioController.isAdmin
      ? const Color(0xFF2A1A08)
      : usuarioController.isGestorSeguranca
      ? const Color(0xFF0A1A2A)
      : const Color(0xFF1A2A1A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    controller.limparSelecao();
    controller.carregarEpis();
    _carregarDuplicados();
  }

  Future<void> _carregarDuplicados() async {
    final result = await _service.buscarEpisDuplicados();
    if (mounted) {
      setState(() {
        _episDuplicados = result;
        _carregouDuplicados = true;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const Map<String, List<String>> _tamanhosPorEpi = {
    'Bota de Segurança': ['39', '40', '41', '43'],
    'Calça Operacional': ['36', '38', '40', '41', '42', '46', '48'],
    'Camisa Manga Longa (Jaleco)': ['P', 'M', 'G', 'GG'],
  };

  void _abrirAssinaturaDevolucao(
      String epiNome, Map<String, dynamic> info) {
    final sigController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Assinatura de Devolução',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Devolvendo: $epiNome',
                  style: const TextStyle(
                      color: Colors.orange, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Ao assinar, você confirma a devolução deste EPI.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => abrirAssinaturaExpandida(
                  context,
                  sigController,
                  titulo: 'Assinatura de Devolução',
                ),
                child: AbsorbPointer(
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Signature(
                        controller: sigController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => sigController.clear(),
                  icon: const Icon(Icons.refresh_rounded,
                      size: 13, color: Colors.white38),
                  label: const Text('Limpar',
                      style:
                      TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (sigController.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Assine antes de enviar'),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final Uint8List? bytes =
                    await sigController.toPngBytes();
                    if (bytes == null) return;
                    final base64Str =
                        'data:image/png;base64,${base64Encode(bytes)}';
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Enviando devolução...'),
                          backgroundColor: Color(0xFF00FF88),
                          duration: Duration(seconds: 1)),
                    );
                    final result = await _service.registrarDevolucao(
                      requisicaoOriginalId:
                      info['requisicao_id'] as int,
                      epiNome: info['epi_completo'] as String,
                      assinaturaBase64: base64Str,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result['message'] ?? ''),
                        backgroundColor: result['success'] == true
                            ? const Color(0xFF00C853)
                            : Colors.red,
                      ));
                      if (result['success'] == true) {
                        setState(() => _episDuplicados.remove(epiNome));
                      }
                    }
                    sigController.dispose();
                  },
                  icon: const Icon(Icons.send_rounded,
                      size: 16, color: Colors.black),
                  label: const Text('Enviar Devolução',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corTipo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _avancar(int etapa) async {
    if (etapa == 0 && controller.episSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione ao menos um EPI'),
            backgroundColor: Colors.red),
      );
      return;
    }
    for (final epi in controller.episSelecionados) {
      if (_tamanhosPorEpi.containsKey(epi) &&
          controller.tamanhosSelecionados[epi] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Selecione o tamanho de: $epi'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }
    if (etapa == 1) {
      final result = await controller.enviarRequisicao();
      if (result['success'] == true) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68, height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: corTipo.withOpacity(0.1),
                      border: Border.all(
                          color: corTipo.withOpacity(0.4),
                          width: 2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Color(0xFF00FF88), size: 32),
                  ),
                  const SizedBox(height: 14),
                  const Text('Requisição Enviada!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Sua requisição aguarda aprovação do gestor. Você será notificado ao receber os EPIs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corTipo,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Fechar',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                Text(result['message'] ?? 'Erro ao enviar'),
                backgroundColor: Colors.red),
          );
        }
      }
      return;
    }
    _tabController.animateTo(etapa + 1);
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  corFundo,
                  const Color(0xFF111111),
                ],
              ),
            ),
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
                          Text('Nova Requisição de EPI',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3)),
                          Text('Solicitar equipamentos de proteção',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                // Barra de progresso
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (_, __) {
                    final progress =
                        (_tabController.index + 1) / 2;
                    return Column(
                      children: [
                        // Step indicators
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: List.generate(
                              _passos.length, (i) {
                            final ativo =
                                i == _tabController.index;
                            final concluido =
                                i < _tabController.index;
                            final cor = concluido || ativo
                                ? corTipo
                                : Colors.white12;
                            return Row(children: [
                              Column(children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: concluido
                                        ? corTipo
                                        : ativo
                                        ? corTipo
                                        .withOpacity(0.15)
                                        : Colors.white
                                        .withOpacity(0.05),
                                    border: ativo
                                        ? Border.all(
                                      color: corTipo,
                                      width: 1.5,
                                    )
                                        : null,
                                  ),
                                  child: Center(
                                    child: concluido
                                        ? const Icon(Icons.check,
                                        color: Colors.black,
                                        size: 14)
                                        : Text('${i + 1}',
                                        style: TextStyle(
                                            color: ativo
                                                ? corTipo
                                                : Colors.white24,
                                            fontSize: 12,
                                            fontWeight:
                                            FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(_passos[i],
                                    style: TextStyle(
                                        color: ativo
                                            ? corTipo
                                            : Colors.white24,
                                        fontSize: 9,
                                        fontWeight: ativo
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ]),
                              if (i < _passos.length - 1)
                                Container(
                                    width: 40, height: 1,
                                    margin: const EdgeInsets.only(
                                        bottom: 14),
                                    color: concluido
                                        ? corTipo
                                        : Colors.white12),
                            ]);
                          }),
                        ),
                        const SizedBox(height: 10),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor:
                            Colors.white.withOpacity(0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(corTipo),
                            minHeight: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Conteúdo das etapas ──────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepEpis(),
                _buildStepEnviar(),
              ],
            ),
          ),

          // ── Botões de navegação ──────────────────────────────
          _buildBotaoNavegacao(),
        ],
      ),
    );
  }

  // ── PASSO 1: EPIs ────────────────────────────────────────────

  Widget _buildStepEpis() {
    return Obx(() => ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: [
        Row(
          children: [
            const Text('Selecione os EPIs necessários:',
                style: TextStyle(
                    color: Colors.white70, fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('${controller.episSelecionados.length} selecionado(s)',
                style: const TextStyle(
                    color: Color(0xFF00FF88), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        ...controller.epis.map((epi) {
          final selecionado =
          controller.episSelecionados.contains(epi);
          return _buildEpiTile(epi, selecionado);
        }),
      ],
    ));
  }

  Widget _buildEpiTile(String epi, bool selecionado) {
    final tamanhos = _tamanhosPorEpi[epi];
    final temTamanho = tamanhos != null;
    final temDuplicado = _episDuplicados.containsKey(epi);

    return GestureDetector(
      onTap: () => controller.toggleEpi(epi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? corTipo.withOpacity(0.07)
              : const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado
                ? (temDuplicado
                ? Colors.orange
                : corTipo)
                : Colors.white.withOpacity(0.07),
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selecionado
                          ? corTipo
                          : Colors.transparent,
                      border: Border.all(
                        color: selecionado
                            ? corTipo
                            : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: selecionado
                        ? const Icon(Icons.check,
                        color: Colors.black, size: 13)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(epi,
                        style: TextStyle(
                            color: selecionado
                                ? Colors.white
                                : Colors.white60,
                            fontSize: 14,
                            fontWeight: selecionado
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                  if (temDuplicado)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded,
                              color: Colors.orange, size: 11),
                          SizedBox(width: 2),
                          Text('TROCA',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Alerta devolução
            if (selecionado && temDuplicado)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 15),
                        SizedBox(width: 6),
                        Text('Você já possui este EPI!',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Assine a devolução do anterior para prosseguir.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _abrirAssinaturaDevolucao(
                            epi, _episDuplicados[epi]),
                        icon: const Icon(Icons.draw_rounded,
                            size: 13, color: Colors.orange),
                        label: const Text('Assinar Devolução',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          padding:
                          const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Tamanhos
            if (selecionado && temTamanho)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tamanho:',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 6),
                    Obx(() {
                      final tamSel =
                      controller.tamanhosSelecionados[epi];
                      return Wrap(
                        spacing: 7, runSpacing: 6,
                        children: tamanhos.map((t) {
                          final sel = tamSel == t;
                          return GestureDetector(
                            onTap: () =>
                            controller.tamanhosSelecionados[epi] =
                                t,
                            child: AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 150),
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? corTipo
                                    : const Color(0xFF111111),
                                borderRadius:
                                BorderRadius.circular(8),
                                border: Border.all(
                                  color: sel
                                      ? corTipo
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                    color: sel
                                        ? Colors.black
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),

            // Quantidade
            if (selecionado)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    const Text('Quantidade:',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 12),
                    Obx(() {
                      final qtd =
                          controller.quantidadesSelecionadas[epi] ??
                              1;
                      return Row(children: [
                        GestureDetector(
                          onTap: () {
                            if (qtd > 1)
                              controller.quantidadesSelecionadas[epi] =
                                  qtd - 1;
                          },
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.remove_rounded,
                                color: Colors.white54, size: 16),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          child: Text('$qtd',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                        GestureDetector(
                          onTap: () =>
                          controller.quantidadesSelecionadas[epi] =
                              qtd + 1,
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: corTipo
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Color(0xFF00FF88), size: 16),
                          ),
                        ),
                      ]);
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── PASSO 2: RESUMO ──────────────────────────────────────────

  Widget _buildStepEnviar() {
    return Obx(() => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo da Requisição',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // EPIs selecionados
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: corTipo.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.safety_check_rounded,
                        color: Color(0xFF00FF88), size: 16),
                    const SizedBox(width: 8),
                    const Text('EPIs Solicitados',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:corTipo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${controller.episSelecionados.length} item(s)',
                        style: const TextStyle(
                            color: Color(0xFF00FF88), fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...controller.episSelecionados.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: const BoxDecoration(
                            color: Color(0xFF00FF88),
                            shape: BoxShape.circle),
                      ),
                      Expanded(
                          child: Text(e,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text('Próximos passos',
                        style: TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                _passoInfo('1', 'Gestor aprova e envia os equipamentos'),
                _passoInfo('2', 'Você recebe notificação de chegada'),
                _passoInfo('3', 'Confirma o recebimento com foto e assinatura'),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _passoInfo(String num, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18, height: 18,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.15),
              border:
              Border.all(color: Colors.blue.withOpacity(0.35)),
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    color: Colors.blue, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── NAVEGAÇÃO ────────────────────────────────────────────────

  Widget _buildBotaoNavegacao() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final etapa = _tabController.index;
        final isUltima = etapa == 1;

        return SafeArea(
          top: false,
          child: Container(
          padding: const EdgeInsets.only(
            left: 16, right: 16,
            top: 12,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            border: Border(
              top: BorderSide(
                  color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: Row(
            children: [
              if (etapa > 0) ...[
                OutlinedButton(
                  onPressed: () =>
                      _tabController.animateTo(etapa - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 16),
                      SizedBox(width: 4),
                      Text('Voltar'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Obx(() => ElevatedButton(
                  onPressed: controller.isSending.value
                      ? null
                      : () => _avancar(etapa),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUltima
                        ? corTipo
                        : const Color(0xFF1E1E1E),
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: isUltima
                        ? null
                        : BorderSide(color: corTipo),
                  ),
                  child: controller.isSending.value
                      ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2.5))
                      : Text(
                    isUltima
                        ? 'Enviar Requisição'
                        : 'Próximo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isUltima
                          ? Colors.black
                          : corTipo,
                    ),
                  ),
                )),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}