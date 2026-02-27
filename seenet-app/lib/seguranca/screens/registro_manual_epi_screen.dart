import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../controllers/seguranca_controller.dart';
import '../services/seguranca_service.dart';
import 'package:seenet/services/auth_service.dart';

class RegistroManualEpiScreen extends StatefulWidget {
  const RegistroManualEpiScreen({super.key});

  @override
  State<RegistroManualEpiScreen> createState() =>
      _RegistroManualEpiScreenState();
}

class _RegistroManualEpiScreenState extends State<RegistroManualEpiScreen> {
  final controller = Get.find<SegurancaController>();
  final service = Get.find<SegurancaService>();
  final authService = Get.find<AuthService>();

  List<Map<String, dynamic>> tecnicos = [];
  int? tecnicoSelecionadoId;
  String? tecnicoSelecionadoNome;
  bool isLoadingTecnicos = true;

  final Set<String> episSelecionados = {};
  String? fotoBase64;
  String? assinaturaBase64;
  DateTime dataEntrega = DateTime.now();
  final obsController = TextEditingController();
  bool isSending = false;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.white,
    exportBackgroundColor: const Color(0xFF1A1A1A),
  );

  @override
  void initState() {
    super.initState();
    _carregarTecnicos();
    controller.carregarEpis();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    obsController.dispose();
    super.dispose();
  }

  Future<void> _carregarTecnicos() async {
    try {
      final lista = await service.buscarTecnicos();
      setState(() {
        tecnicos = lista;
        isLoadingTecnicos = false;
      });
    } catch (_) {
      setState(() => isLoadingTecnicos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Registro Manual de EPI',
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
            // Aviso
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Use para registrar entregas de EPIs anteriores ou fora do app. O registro será salvo com status aprovada.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Técnico ──
            _buildSectionTitle('Técnico'),
            const SizedBox(height: 8),
            isLoadingTecnicos
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00FF88), strokeWidth: 2))
                : _buildDropdownTecnico(),
            const SizedBox(height: 20),

            // ── Data de entrega ──
            _buildSectionTitle('Data de Entrega'),
            const SizedBox(height: 8),
            _buildDatePicker(),
            const SizedBox(height: 20),

            // ── EPIs ──
            _buildSectionTitle('EPIs Entregues'),
            const SizedBox(height: 8),
            ...controller.epis.map((epi) => _buildEpiTile(epi)),
            const SizedBox(height: 20),

            // ── Observação ──
            _buildSectionTitle('Observação (opcional)'),
            const SizedBox(height: 8),
            TextField(
              controller: obsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ex: Entregue na sede em 24/02/2026...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF242424),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Foto (opcional) ──
            _buildSectionTitle('Foto de Comprovação (opcional)'),
            const SizedBox(height: 8),
            _buildFotoSection(),
            const SizedBox(height: 20),

            // ── Assinatura (opcional) ──
            _buildSectionTitle('Assinatura Digital (opcional)'),
            const SizedBox(height: 8),
            _buildAssinaturaSection(),
            const SizedBox(height: 32),

            // ── Botão enviar ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSending ? null : _enviar,
                icon: isSending
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.save_alt, color: Colors.black),
                label: Text(
                  isSending ? 'Salvando...' : 'Salvar Registro Manual',
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

  Widget _buildDropdownTecnico() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tecnicoSelecionadoId != null
              ? const Color(0xFF00FF88).withOpacity(0.4)
              : Colors.white12,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: tecnicoSelecionadoId,
          hint: const Text('Selecione o técnico',
              style: TextStyle(color: Colors.white38)),
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          isExpanded: true,
          onChanged: (v) => setState(() {
            tecnicoSelecionadoId = v;
            tecnicoSelecionadoNome =
            tecnicos.firstWhere((t) => t['id'] == v)['nome'];
          }),
          items: tecnicos.map((t) {
            return DropdownMenuItem<int>(
              value: t['id'] as int,
              child: Text(t['nome'] as String),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: dataEntrega,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF00FF88),
                onPrimary: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => dataEntrega = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: Color(0xFF00FF88), size: 18),
            const SizedBox(width: 12),
            Text(
              '${dataEntrega.day.toString().padLeft(2, '0')}/${dataEntrega.month.toString().padLeft(2, '0')}/${dataEntrega.year}',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const Spacer(),
            const Text('Alterar',
                style:
                TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEpiTile(String epi) {
    final sel = episSelecionados.contains(epi);
    return GestureDetector(
      onTap: () => setState(() {
        sel ? episSelecionados.remove(epi) : episSelecionados.add(epi);
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel
              ? const Color(0xFF00FF88).withOpacity(0.08)
              : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel
                ? const Color(0xFF00FF88)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(
              sel ? Icons.check_box : Icons.check_box_outline_blank,
              color: sel ? const Color(0xFF00FF88) : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(epi,
                    style: TextStyle(
                        color: sel ? Colors.white : Colors.white60,
                        fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildFotoSection() {
    if (fotoBase64 != null) {
      final bytes = base64Decode(fotoBase64!.split(',').last);
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes,
                height: 160,
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
    return Row(
      children: [
        Expanded(
          child: _buildBotaoMidia(
            Icons.camera_alt,
            'Câmera',
                () => _tirarFoto(camera: true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildBotaoMidia(
            Icons.photo_library,
            'Galeria',
                () => _tirarFoto(camera: false),
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoMidia(
      IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white54),
      label: Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Colors.white24),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAssinaturaSection() {
    return Column(
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
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
            icon: const Icon(Icons.refresh, size: 14, color: Colors.white38),
            label: const Text('Limpar',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Future<void> _tirarFoto({bool camera = true}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(
              () => fotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    }
  }

  Future<void> _enviar() async {
    if (tecnicoSelecionadoId == null) {
      _snack('Selecione o técnico', Colors.red);
      return;
    }
    if (episSelecionados.isEmpty) {
      _snack('Selecione ao menos um EPI', Colors.red);
      return;
    }

    setState(() => isSending = true);

    try {
      // Exporta assinatura se preenchida
      String? sigBase64;
      if (_signatureController.isNotEmpty) {
        final Uint8List? sigBytes =
        await _signatureController.toPngBytes();
        if (sigBytes != null) {
          sigBase64 = 'data:image/png;base64,${base64Encode(sigBytes)}';
        }
      }

      final result = await service.criarRegistroManual(
        tecnicoId: tecnicoSelecionadoId!,
        episSolicitados: episSelecionados.toList(),
        assinaturaBase64: sigBase64,
        fotoBase64: fotoBase64,
        observacao: obsController.text.trim().isNotEmpty
            ? obsController.text.trim()
            : null,
        dataEntrega: dataEntrega,
      );

      if (result['success'] == true) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF2A2A2A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF00FF88), size: 60),
                  const SizedBox(height: 12),
                  const Text('Registro Salvo!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'O histórico de EPIs de $tecnicoSelecionadoNome foi atualizado. PDF gerado automaticamente.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
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
        _snack(result['message'] ?? 'Erro ao salvar', Colors.red);
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }
}