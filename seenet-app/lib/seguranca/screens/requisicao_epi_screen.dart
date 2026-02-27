import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/seguranca_controller.dart';

class RequisicaoEpiScreen extends StatefulWidget {
  const RequisicaoEpiScreen({super.key});

  @override
  State<RequisicaoEpiScreen> createState() => _RequisicaoEpiScreenState();
}

class _RequisicaoEpiScreenState extends State<RequisicaoEpiScreen>
    with SingleTickerProviderStateMixin {
  final controller = Get.find<SegurancaController>();
  late TabController _tabController;

  final List<String> _passos = ['Selecionar EPIs', 'Enviar'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    controller.limparSelecao();
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
                              ? Border.all(
                              color: const Color(0xFF00FF88), width: 2)
                              : null,
                        ),
                        child: Center(
                          child: isConcluido
                              ? const Icon(Icons.check,
                              color: Colors.black, size: 14)
                              : Text('${i + 1}',
                              style: TextStyle(
                                color: isAtivo
                                    ? const Color(0xFF00FF88)
                                    : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _passos[i],
                        style: TextStyle(
                          color: isAtivo
                              ? const Color(0xFF00FF88)
                              : Colors.white38,
                          fontSize: 9,
                          fontWeight: isAtivo
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (i < _passos.length - 1)
                    Container(
                      width: 40,
                      height: 1,
                      color: isConcluido
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF3A3A3A),
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
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('${controller.episSelecionados.length} selecionado(s)',
            style: const TextStyle(
                color: Color(0xFF00FF88), fontSize: 13)),
        const SizedBox(height: 12),
        ...controller.epis.map((epi) {
          final selecionado = controller.episSelecionados.contains(epi);
          return _buildEpiTile(epi, selecionado);
        }),
      ],
    ));
  }

  Widget _buildEpiTile(String epi, bool selecionado) {
    return GestureDetector(
      onTap: () => controller.toggleEpi(epi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFF00FF88).withOpacity(0.1)
              : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado
                ? const Color(0xFF00FF88)
                : Colors.white.withOpacity(0.08),
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selecionado
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: selecionado
                  ? const Color(0xFF00FF88)
                  : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(epi,
                  style: TextStyle(
                    color: selecionado ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: selecionado
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
            ),
          ],
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
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // EPIs selecionados
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00FF88).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.safety_check,
                        color: Color(0xFF00FF88), size: 18),
                    SizedBox(width: 8),
                    Text('EPIs Solicitados',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
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
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13))),
                    ],
                  ),
                )),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Informativo sobre o fluxo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: Colors.blue.withOpacity(0.25)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('Próximos passos',
                        style: TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 10),
                _PassoInfo(
                    numero: '1',
                    texto:
                    'Sua requisição será enviada ao gestor para aprovação'),
                SizedBox(height: 6),
                _PassoInfo(
                    numero: '2',
                    texto:
                    'O gestor aprovará e enviará os equipamentos fisicamente'),
                SizedBox(height: 6),
                _PassoInfo(
                    numero: '3',
                    texto:
                    'Ao receber, você confirma o recebimento com assinatura e foto'),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                  onPressed: controller.isSending.value
                      ? null
                      : () => _avancar(etapa),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUltima
                        ? const Color(0xFF00FF88)
                        : const Color(0xFF2A2A2A),
                    foregroundColor:
                    isUltima ? Colors.black : Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: isUltima
                        ? null
                        : const BorderSide(
                        color: Color(0xFF00FF88)),
                  ),
                  child: controller.isSending.value
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2),
                  )
                      : Text(
                    isUltima
                        ? 'Enviar Requisição'
                        : 'Próximo',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
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
        const SnackBar(
          content: Text('Selecione ao menos um EPI'),
          backgroundColor: Colors.red,
        ),
      );
      return;
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF00FF88), size: 64),
                  const SizedBox(height: 16),
                  const Text('Requisição Enviada!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Sua requisição foi enviada e aguarda aprovação do gestor. Quando os EPIs chegarem, você será notificado para confirmar o recebimento.',
                    textAlign: TextAlign.center,
                    style:
                    TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Fechar',
                        style: TextStyle(color: Colors.black)),
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
              content: Text(result['message'] ?? 'Erro ao enviar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    _tabController.animateTo(etapa + 1);
  }
}

// Widget auxiliar para os passos informativos
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
                style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto,
              style:
              const TextStyle(color: Colors.blue, fontSize: 12)),
        ),
      ],
    );
  }
}