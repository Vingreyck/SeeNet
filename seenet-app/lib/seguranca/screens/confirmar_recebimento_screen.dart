// lib/seguranca/screens/confirmar_recebimento_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/seguranca_controller.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/seguranca_service.dart';
import '../../widgets/assinatura_expandida.dart';

class ConfirmarRecebimentoScreen extends StatefulWidget {
  final int requisicaoId;
  final List<String> epis;

  const ConfirmarRecebimentoScreen({
    super.key,
    required this.requisicaoId,
    required this.epis,
  });

  @override
  State<ConfirmarRecebimentoScreen> createState() =>
      _ConfirmarRecebimentoScreenState();
}

class _ConfirmarRecebimentoScreenState
    extends State<ConfirmarRecebimentoScreen> {
  final _service = Get.find<SegurancaService>();

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  String? _fotoBase64;
  bool _isSending = false;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
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
      setState(() =>
      _fotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    }
  }

  Future<void> _confirmar() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Assinatura obrigatória'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_fotoBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Foto obrigatória'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final Uint8List? sigBytes = await _signatureController.toPngBytes();
      if (sigBytes == null) return;
      final assinaturaBase64 =
          'data:image/png;base64,${base64Encode(sigBytes)}';

      final result = await _service.confirmarRecebimento(
        id: widget.requisicaoId,
        assinaturaBase64: assinaturaBase64,
        fotoBase64: _fotoBase64!,
      );

      await Get.find<SegurancaController>().carregarMinhasRequisicoes();

      if (mounted) {
        if (result['success'] == true) {
          await showDialog(
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
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00FF88).withOpacity(0.12),
                      border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.4),
                          width: 2),
                    ),
                    child: const Icon(Icons.verified_rounded,
                        color: Color(0xFF00FF88), size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Recebimento Confirmado!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'O recebimento foi registrado e o PDF foi gerado. Acesse em Minhas Requisições.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Ver Minhas Requisições',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message'] ?? 'Erro ao confirmar'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
              bottom: 16, left: 8, right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D2A1A), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
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
                      Text('Confirmar Recebimento',
                          style: TextStyle(
                              color: Colors.white, fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      Text('Req. #' , // será preenchido abaixo
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Banner informativo ─────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            color: Color(0xFF00FF88), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Os EPIs chegaram! Assine abaixo e tire uma foto com os equipamentos para confirmar o recebimento.',
                            style: TextStyle(
                                color: Color(0xFF00FF88), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── EPIs ───────────────────────────────────
                  _sectionLabel('EPIs a receber'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: widget.epis.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: const BoxDecoration(
                                  color: Color(0xFF00FF88),
                                  shape: BoxShape.circle),
                            ),
                            Expanded(child: Text(e,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Assinatura ─────────────────────────────
                  Row(
                    children: [
                      _sectionLabel('Assinatura Digital'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('obrigatória',
                            style: TextStyle(
                                color: Colors.red, fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      await abrirAssinaturaExpandida(
                        context,
                        _signatureController,
                        titulo: 'Assinatura',
                      );
                      if (mounted) setState(() {});
                    },
                    child: AbsorbPointer(
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _signatureController.isNotEmpty
                                  ? const Color(0xFF00FF88)
                                  : Colors.white24,
                              width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            children: [
                              Signature(
                                controller: _signatureController,
                                backgroundColor: Colors.white,
                              ),
                              if (_signatureController.isEmpty)
                                const Center(
                                  child: Text('Toque para assinar',
                                      style: TextStyle(
                                          color: Colors.black26,
                                          fontSize: 14)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _signatureController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          size: 14, color: Colors.white38),
                      label: const Text('Limpar',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Foto ───────────────────────────────────
                  Row(
                    children: [
                      _sectionLabel('Foto de Confirmação'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('obrigatória',
                            style: TextStyle(
                                color: Colors.red, fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tire uma foto com seu rosto e os EPIs visíveis',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  _buildFotoSection(),
                  const SizedBox(height: 32),

                  // ── Botão confirmar ────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _confirmar,
                      icon: _isSending
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5))
                          : const Icon(Icons.verified_rounded,
                          color: Colors.black, size: 20),
                      label: Text(
                        _isSending
                            ? 'Confirmando...'
                            : 'Confirmar Recebimento',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        disabledBackgroundColor:
                        const Color(0xFF00FF88).withOpacity(0.4),
                        padding:
                        const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4));

  Widget _buildFotoSection() {
    if (_fotoBase64 != null) {
      final bytes = base64Decode(_fotoBase64!.split(',').last);
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(bytes,
                height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _tirarFoto,
            icon: const Icon(Icons.refresh_rounded, size: 16,
                color: Colors.white54),
            label: const Text('Trocar Foto',
                style: TextStyle(color: Colors.white54)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _tirarFoto,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withOpacity(0.08), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.2)),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF00FF88), size: 26),
            ),
            const SizedBox(height: 10),
            const Text('Tirar Foto',
                style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}