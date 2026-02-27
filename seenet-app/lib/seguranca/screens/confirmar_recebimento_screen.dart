import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/seguranca_service.dart';

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
    penColor: Colors.white,
    exportBackgroundColor: const Color(0xFF1A1A1A),
  );

  String? _fotoBase64;
  bool _isSending = false;

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Confirmar Recebimento',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      color: Color(0xFF00FF88), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Os EPIs chegaram! Assine abaixo e tire uma foto com os equipamentos para confirmar o recebimento.',
                      style:
                      TextStyle(color: Color(0xFF00FF88), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // EPIs da requisição
            _buildSectionTitle('EPIs a receber'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: widget.epis
                    .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
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
            const SizedBox(height: 24),

            // Assinatura
            _buildSectionTitle('Assinatura Digital *'),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _signatureController.clear(),
                icon: const Icon(Icons.refresh,
                    size: 14, color: Colors.white38),
                label: const Text('Limpar',
                    style:
                    TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 20),

            // Foto
            _buildSectionTitle('Foto de Confirmação *'),
            const SizedBox(height: 4),
            const Text(
              'Tire uma foto com seu rosto e os EPIs recebidos visíveis',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 10),
            _buildFotoSection(),
            const SizedBox(height: 32),

            // Botão confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _confirmar,
                icon: _isSending
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.verified,
                    color: Colors.black, size: 20),
                label: Text(
                  _isSending ? 'Confirmando...' : 'Confirmar Recebimento',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor:
                  const Color(0xFF00FF88).withOpacity(0.4),
                ),
              ),
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }

  Widget _buildFotoSection() {
    if (_fotoBase64 != null) {
      final bytes = base64Decode(_fotoBase64!.split(',').last);
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _tirarFoto,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Trocar Foto'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24)),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _tirarFoto,
        icon: const Icon(Icons.camera_alt, color: Colors.black),
        label: const Text('Tirar Foto',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF88),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
      final Uint8List? sigBytes =
      await _signatureController.toPngBytes();
      if (sigBytes == null) return;
      final assinaturaBase64 =
          'data:image/png;base64,${base64Encode(sigBytes)}';

      final result = await _service.confirmarRecebimento(
        id: widget.requisicaoId,
        assinaturaBase64: assinaturaBase64,
        fotoBase64: _fotoBase64!,
      );

      if (mounted) {
        if (result['success'] == true) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF2A2A2A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified,
                      color: Color(0xFF00FF88), size: 64),
                  const SizedBox(height: 16),
                  const Text('Recebimento Confirmado!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'O recebimento foi registrado e o PDF foi gerado. Você pode acessá-lo em Minhas Requisições.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // fecha dialog
                      Navigator.pop(context); // volta para minhas requisições
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Ver Minhas Requisições',
                        style: TextStyle(color: Colors.black)),
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
}