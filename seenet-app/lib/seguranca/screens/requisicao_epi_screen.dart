import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../controllers/seguranca_controller.dart';
import '../services/seguranca_service.dart';

class RequisicaoEpiScreen extends StatefulWidget {
  const RequisicaoEpiScreen({super.key});

  @override
  State<RequisicaoEpiScreen> createState() => _RequisicaoEpiScreenState();
}

class _RequisicaoEpiScreenState extends State<RequisicaoEpiScreen>
    with SingleTickerProviderStateMixin {
  final controller = Get.find<SegurancaController>();
  final _service = Get.find<SegurancaService>();
  late TabController _tabController;

  final List<String> _passos = ['Selecionar EPIs', 'Enviar'];

  Map<String, dynamic> _episDuplicados = {};
  bool _carregouDuplicados = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    controller.limparSelecao();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Nova Requisição de EPI',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _buildProgressBar(),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
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
          _buildBotaoNavegacao(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final progress = (_tabController.index + 1) / 2;
        return LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF3A3A3A),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
          minHeight: 4,
        );
      },
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: const Color(0xFF242424),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_passos.length, (i) {
              final isAtivo = i == _tabController.index;
              final isConcluido = i < _tabController.index;
              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConcluido
                              ? const Color(0xFF00FF88)
                              : isAtivo
                              ? const Color(0xFF00FF88).withOpacity(0.2)
                              : const Color(0xFF3A3A3A),
                          border: isAtivo
                              ? Border.all(color: const Color(0xFF00FF88), width: 2)
                              : null,
                        ),
                        child: Center(
                          child: isConcluido
                              ? const Icon(Icons.check, color: Colors.black, size: 14)
                              : Text('${i + 1}',
                              style: TextStyle(
                                color: isAtivo ? const Color(0xFF00FF88) : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _passos[i],
                        style: TextStyle(
                          color: isAtivo ? const Color(0xFF00FF88) : Colors.white38,
                          fontSize: 9,
                          fontWeight: isAtivo ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (i < _passos.length - 1)
                    Container(
                      width: 40,
                      height: 1,
                      color: isConcluido ? const Color(0xFF00FF88) : const Color(0xFF3A3A3A),
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                ],
              );
            }),
          );
        },
      ),
    );
  }

  // ===================== PASSO 1: EPIs =====================
  Widget _buildStepEpis() {
    return Obx(() => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Selecione os EPIs necessários:',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('${controller.episSelecionados.length} selecionado(s)',
            style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13)),
        const SizedBox(height: 12),
        ...controller.epis.map((epi) {
          final selecionado = controller.episSelecionados.contains(epi);
          return _buildEpiTile(epi, selecionado);
        }),
      ],
    ));
  }

  static const Map<String, List<String>> _tamanhosPorEpi = {
    'Bota de Segurança': ['39', '40', '41'],
    'Calça Operacional': ['36', '38', '40', '41', '42', '46', '48'],
    'Camisa Manga Longa': ['P', 'M', 'G', 'GG'],
  };

  Widget _buildEpiTile(String epi, bool selecionado) {
    final tamanhos = _tamanhosPorEpi[epi];
    final temTamanho = tamanhos != null;
    final temDuplicado = _episDuplicados.containsKey(epi);

    return GestureDetector(
      onTap: () => controller.toggleEpi(epi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFF00FF88).withOpacity(0.1)
              : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado
                ? (temDuplicado ? Colors.orange : const Color(0xFF00FF88))
                : Colors.white.withOpacity(0.08),
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selecionado ? Icons.check_box : Icons.check_box_outline_blank,
                  color: selecionado ? const Color(0xFF00FF88) : Colors.white38,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(epi,
                      style: TextStyle(
                        color: selecionado ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
                // Indicador de duplicado
                if (temDuplicado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.orange, size: 12),
                        SizedBox(width: 2),
                        Text('TROCA', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),

            // ALERTA DEVOLUÇÃO
            if (selecionado && temDuplicado) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text('Você já possui este EPI!',
                                style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Assine a devolução do anterior para prosseguir sem pendências.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _abrirAssinaturaDevolucao(epi, _episDuplicados[epi]),
                          icon: const Icon(Icons.draw, size: 14, color: Colors.orange),
                          label: const Text('Assinar Devolução',
                              style: TextStyle(color: Colors.orange, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // TAMANHOS
            if (selecionado && temTamanho) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selecione o tamanho:',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 6),
                    Obx(() {
                      final tamSel = controller.tamanhosSelecionados[epi];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: tamanhos.map((t) {
                          final sel = tamSel == t;
                          return GestureDetector(
                            onTap: () => controller.tamanhosSelecionados[epi] = t,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFF00FF88) : const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sel ? const Color(0xFF00FF88) : Colors.white24,
                                ),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                    color: sel ? Colors.black : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                  )),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // QUANTIDADE
            if (selecionado) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Row(
                  children: [
                    const Text('Quantidade:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 10),
                    Obx(() {
                      final qtd = controller.quantidadesSelecionadas[epi] ?? 1;
                      return Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (qtd > 1) controller.quantidadesSelecionadas[epi] = qtd - 1;
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(child: Icon(Icons.remove, color: Colors.white54, size: 18)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('$qtd',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => controller.quantidadesSelecionadas[epi] = qtd + 1,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(child: Icon(Icons.add, color: Color(0xFF00FF88), size: 18)),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===================== ASSINATURA DEVOLUÇÃO =====================
  void _abrirAssinaturaDevolucao(String epiNome, Map<String, dynamic> info) {
    final sigController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.white,
      exportBackgroundColor: const Color(0xFF1A1A1A),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Assinatura de Devolução',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Devolvendo: $epiNome',
                  style: const TextStyle(color: Colors.orange, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'Ao assinar, você confirma a devolução deste EPI ao gestor.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Signature(
                    controller: sigController,
                    backgroundColor: const Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => sigController.clear(),
                  icon: const Icon(Icons.refresh, size: 14, color: Colors.white38),
                  label: const Text('Limpar', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (sigController.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Assine antes de enviar'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final Uint8List? bytes = await sigController.toPngBytes();
                    if (bytes == null) return;
                    final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Enviando devolução...'),
                          backgroundColor: Color(0xFF00FF88),
                          duration: Duration(seconds: 1)),
                    );

                    final result = await _service.registrarDevolucao(
                      requisicaoOriginalId: info['requisicao_id'] as int,
                      epiNome: info['epi_completo'] as String,
                      assinaturaBase64: base64Str,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result['message'] ?? ''),
                        backgroundColor: result['success'] == true ? const Color(0xFF00C853) : Colors.red,
                      ));
                      if (result['success'] == true) {
                        setState(() {
                          _episDuplicados.remove(epiNome);
                        });
                      }
                    }

                    sigController.dispose();
                  },
                  icon: const Icon(Icons.send, size: 16, color: Colors.black),
                  label: const Text('Enviar Devolução',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== PASSO 2: RESUMO E ENVIO =====================
  Widget _buildStepEnviar() {
    return Obx(() => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo da Requisição',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.safety_check, color: Color(0xFF00FF88), size: 18),
                    SizedBox(width: 8),
                    Text('EPIs Solicitados',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                ...controller.episSelecionados.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF00FF88), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e,
                              style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.25)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('Próximos passos',
                        style: TextStyle(
                            color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 10),
                _PassoInfo(numero: '1', texto: 'Sua requisição será enviada ao gestor para aprovação'),
                SizedBox(height: 6),
                _PassoInfo(
                    numero: '2', texto: 'O gestor aprovará e enviará os equipamentos fisicamente'),
                SizedBox(height: 6),
                _PassoInfo(
                    numero: '3',
                    texto: 'Ao receber, você confirma o recebimento com assinatura e foto'),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  // ===================== BOTÃO DE NAVEGAÇÃO =====================
  Widget _buildBotaoNavegacao() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final etapa = _tabController.index;
        final isUltima = etapa == 1;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          color: const Color(0xFF1A1A1A),
          child: Row(
            children: [
              if (etapa > 0) ...[
                OutlinedButton(
                  onPressed: () => _tabController.animateTo(etapa - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back, size: 16),
                      SizedBox(width: 4),
                      Text('Voltar'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Obx(() => ElevatedButton(
                  onPressed: controller.isSending.value ? null : () => _avancar(etapa),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUltima ? const Color(0xFF00FF88) : const Color(0xFF2A2A2A),
                    foregroundColor: isUltima ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: isUltima ? null : const BorderSide(color: Color(0xFF00FF88)),
                  ),
                  child: controller.isSending.value
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text(
                    isUltima ? 'Enviar Requisição' : 'Próximo',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _avancar(int etapa) async {
    if (etapa == 0 && controller.episSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos um EPI'), backgroundColor: Colors.red),
      );
      return;
    }

    for (final epi in controller.episSelecionados) {
      if (_tamanhosPorEpi.containsKey(epi) && controller.tamanhosSelecionados[epi] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selecione o tamanho de: $epi'), backgroundColor: Colors.red),
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
              backgroundColor: const Color(0xFF2A2A2A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 64),
                  const SizedBox(height: 16),
                  const Text('Requisição Enviada!',
                      style:
                      TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Sua requisição foi enviada e aguarda aprovação do gestor. Quando os EPIs chegarem, você será notificado para confirmar o recebimento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fechar', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Erro ao enviar'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    _tabController.animateTo(etapa + 1);
  }
}

class _PassoInfo extends StatelessWidget {
  final String numero;
  final String texto;

  const _PassoInfo({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.2),
            border: Border.all(color: Colors.blue.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(numero,
                style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, style: const TextStyle(color: Colors.blue, fontSize: 12)),
        ),
      ],
    );
  }
}