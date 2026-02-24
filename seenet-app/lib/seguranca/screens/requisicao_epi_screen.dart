import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
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

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.white,
    exportBackgroundColor: const Color(0xFF1A1A1A),
  );

  String? _fotoBase64;
  bool _assinaturaConcluida = false;

  final List<String> _passos = ['Selecionar EPIs', 'Assinatura', 'Foto', 'Enviar'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    controller.limparSelecao();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signatureController.dispose();
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
                _buildStepAssinatura(),
                _buildStepFoto(),
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
        final progress = (_tabController.index + 1) / 4;
        return LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF3A3A3A),
          valueColor:
          const AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
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
                      width: 30,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  // ===================== PASSO 2: ASSINATURA =====================
  Widget _buildStepAssinatura() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assine abaixo para confirmar a requisição:',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _assinaturaConcluida
                      ? const Color(0xFF00FF88)
                      : Colors.white24,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _signatureController.clear();
                    setState(() => _assinaturaConcluida = false);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Limpar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_signatureController.isNotEmpty) {
                      setState(() => _assinaturaConcluida = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Assinatura registrada!'),
                          backgroundColor: Color(0xFF00C853),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 18, color: Colors.black),
                  label: const Text('Confirmar',
                      style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== PASSO 3: FOTO =====================
  Widget _buildStepFoto() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Tire uma foto com seu rosto e os equipamentos recebidos visíveis:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _fotoBase64 == null
                ? _buildFotoVazia()
                : _buildFotoPreview(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _tirarFoto,
              icon: const Icon(Icons.camera_alt, color: Colors.black),
              label: Text(
                _fotoBase64 == null ? 'Tirar Foto' : 'Refazer Foto',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFotoVazia() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_outlined, size: 60, color: Colors.white24),
          SizedBox(height: 12),
          Text('Nenhuma foto tirada',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 6),
          Text('Inclua rosto + material na mesma foto',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFotoPreview() {
    final bytes = base64Decode(_fotoBase64!.split(',').last);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00FF88), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _fotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  // ===================== PASSO 4: CONFIRMAÇÃO =====================
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
          _buildResumoCard(
            icon: Icons.safety_check,
            title: 'EPIs Solicitados',
            color: const Color(0xFF00FF88),
            child: Column(
              children: controller.episSelecionados
                  .map((e) => Padding(
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
              ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Status assinatura
          _buildStatusItem(
            icon: Icons.draw,
            label: 'Assinatura',
            ok: _assinaturaConcluida,
          ),
          const SizedBox(height: 8),

          // Status foto
          _buildStatusItem(
            icon: Icons.camera_alt,
            label: 'Foto de confirmação',
            ok: _fotoBase64 != null,
          ),
          const SizedBox(height: 8),

          // Aviso
          if (!_assinaturaConcluida || _fotoBase64 == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Volte aos passos anteriores para completar assinatura e foto.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ));
  }

  Widget _buildResumoCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required bool ok,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? const Color(0xFF00FF88).withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: ok ? const Color(0xFF00FF88) : Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? const Color(0xFF00FF88) : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ===================== BOTÃO DE NAVEGAÇÃO =====================
  Widget _buildBotaoNavegacao() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final etapa = _tabController.index;
        final isUltima = etapa == 3;

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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: isUltima
                        ? null
                        : const BorderSide(color: Color(0xFF00FF88)),
                  ),
                  child: controller.isSending.value
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2),
                  )
                      : Text(
                    isUltima ? 'Enviar Requisição' : 'Próximo',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
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
    // Validações por etapa
    if (etapa == 0 && controller.episSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos um EPI'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (etapa == 1 && _signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça a assinatura antes de continuar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (etapa == 2 && _fotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tire a foto antes de continuar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Última etapa: enviar
    if (etapa == 3) {
      if (!_assinaturaConcluida || _fotoBase64 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete todos os passos antes de enviar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Exportar assinatura
      final Uint8List? sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) return;
      final assinaturaBase64 =
          'data:image/png;base64,${base64Encode(sigBytes)}';

      final result = await controller.enviarRequisicao(
        assinaturaBase64: assinaturaBase64,
        fotoBase64: _fotoBase64!,
      );

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
                    'Sua requisição foi enviada e aguarda aprovação do gestor.',
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

    // Salvar assinatura ao sair do passo 1
    if (etapa == 1 && _signatureController.isNotEmpty) {
      setState(() => _assinaturaConcluida = true);
    }

    _tabController.animateTo(etapa + 1);
  }
}