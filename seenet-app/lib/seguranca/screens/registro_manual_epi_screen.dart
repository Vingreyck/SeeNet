// lib/seguranca/screens/registro_manual_epi_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../controllers/seguranca_controller.dart';
import '../services/seguranca_service.dart';
import 'package:seenet/services/auth_service.dart';
import '../../widgets/assinatura_expandida.dart';

class RegistroManualEpiScreen extends StatefulWidget {
  final int? tecnicoIdFixo;
  final String? tecnicoNomeFixo;

  const RegistroManualEpiScreen({
    super.key,
    this.tecnicoIdFixo,
    this.tecnicoNomeFixo,
  });

  @override
  State<RegistroManualEpiScreen> createState() =>
      _RegistroManualEpiScreenState();
}

class _RegistroManualEpiScreenState
    extends State<RegistroManualEpiScreen> {
  String? fotoDocumentoBase64;
  bool ehFichario = false;
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
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _carregarTecnicos();
    controller.carregarEpis();
    if (widget.tecnicoIdFixo != null) {
      tecnicoSelecionadoId = widget.tecnicoIdFixo;
      tecnicoSelecionadoNome = widget.tecnicoNomeFixo;
    }
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

  Future<void> _tirarFotoDocumento({bool camera = true}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70, maxWidth: 1200,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() =>
      fotoDocumentoBase64 =
      'data:image/jpeg;base64,${base64Encode(bytes)}');
    }
  }

  Future<void> _tirarFoto({bool camera = true}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70, maxWidth: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() =>
      fotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
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
      String? sigBase64;
      if (_signatureController.isNotEmpty) {
        final Uint8List? sigBytes =
        await _signatureController.toPngBytes();
        if (sigBytes != null) {
          sigBase64 =
          'data:image/png;base64,${base64Encode(sigBytes)}';
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
        fotoDocumentoBase64: fotoDocumentoBase64,
        ehFichario: ehFichario,
      );
      if (result['success'] == true) {
        if (mounted) {
          await showDialog(
            context: context,
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
                      color: const Color(0xFF00FF88).withOpacity(0.1),
                      border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.4),
                          width: 2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Color(0xFF00FF88), size: 32),
                  ),
                  const SizedBox(height: 14),
                  const Text('Registro Salvo!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'O histórico de EPIs de $tecnicoSelecionadoNome foi atualizado.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
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
                        backgroundColor: const Color(0xFF00FF88),
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
        _snack(result['message'] ?? 'Erro ao salvar', Colors.red);
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
                colors: [Color(0xFF1A2A1A), Color(0xFF111111)],
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.save_alt_rounded,
                      color: Color(0xFF00FF88), size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registro Manual de EPI',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      Text('Entrega fora do fluxo padrão',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Formulário ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              // Folga extra embaixo = altura da barra do celular, pro botão de
              // salvar não encostar/ficar atrás da navegação ao rolar até o fim.
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.blue, size: 16),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Use para registrar entregas anteriores ou fora do app. O registro será salvo como aprovado.',
                            style: TextStyle(
                                color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Técnico ──────────────────────────────────
                  _sectionLabel('Técnico'),
                  const SizedBox(height: 8),
                  isLoadingTecnicos
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00FF88), strokeWidth: 2))
                      : IgnorePointer(
                    ignoring: widget.tecnicoIdFixo != null,
                    child: Opacity(
                      opacity:
                      widget.tecnicoIdFixo != null ? 0.6 : 1.0,
                      child: _buildDropdownTecnico(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Data de entrega ──────────────────────────
                  _sectionLabel('Data de Entrega'),
                  const SizedBox(height: 8),
                  _buildDatePicker(),
                  const SizedBox(height: 18),

                  // ── EPIs ─────────────────────────────────────
                  _sectionLabel('EPIs Entregues'),
                  const SizedBox(height: 8),
                  ...controller.epis.map((epi) => _buildEpiTile(epi)),
                  const SizedBox(height: 18),

                  // ── Observação ───────────────────────────────
                  _sectionLabel('Observação (opcional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: obsController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ex: Entregue na sede em 24/02/2026...',
                      hintStyle:
                      const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF181818),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF00FF88), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Foto ─────────────────────────────────────
                  _sectionLabel('Foto de Comprovação (opcional)'),
                  const SizedBox(height: 8),
                  _buildFotoSection(),
                  const SizedBox(height: 18),

                  // ── Assinatura ───────────────────────────────
                  _sectionLabel('Assinatura Digital (opcional)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      await abrirAssinaturaExpandida(
                        context,
                        _signatureController,
                        titulo: 'Assinatura Digital',
                      );
                      if (mounted) setState(() {});
                    },
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
                          size: 13, color: Colors.white38),
                      label: const Text('Limpar',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ),
                  ),

                  // ── Tipo de registro ─────────────────────────
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.purple.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Switch(
                          value: ehFichario,
                          activeColor: Colors.purple,
                          onChanged: (v) =>
                              setState(() => ehFichario = v),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ficha antiga (Fichário)',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  'Arquiva como registro histórico',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Foto do documento (fichário)
                  if (ehFichario) ...[
                    const SizedBox(height: 16),
                    _sectionLabel('Foto do Documento Físico'),
                    const SizedBox(height: 8),
                    _buildFotoDocumentoSection(),
                  ],

                  const SizedBox(height: 24),

                  // ── Botão salvar ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSending ? null : _enviar,
                      icon: isSending
                          ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5))
                          : const Icon(Icons.save_alt_rounded,
                          color: Colors.black),
                      label: Text(
                        isSending ? 'Salvando...' : 'Salvar Registro Manual',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        disabledBackgroundColor:
                        const Color(0xFF00FF88).withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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

  // ── Widgets helpers ──────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4));

  Widget _buildDropdownTecnico() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
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
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          isExpanded: true,
          onChanged: (v) => setState(() {
            tecnicoSelecionadoId = v;
            tecnicoSelecionadoNome =
            tecnicos.firstWhere((t) => t['id'] == v)['nome'];
          }),
          items: tecnicos.map((t) => DropdownMenuItem<int>(
            value: t['id'] as int,
            child: Text(t['nome'] as String),
          )).toList(),
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
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: Color(0xFF00FF88), size: 18),
            const SizedBox(width: 12),
            Text(
              '${dataEntrega.day.toString().padLeft(2, '0')}/${dataEntrega.month.toString().padLeft(2, '0')}/${dataEntrega.year}',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const Spacer(),
            const Text('Alterar',
                style: TextStyle(
                    color: Color(0xFF00FF88), fontSize: 12)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: sel
              ? const Color(0xFF00FF88).withOpacity(0.07)
              : const Color(0xFF181818),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel
                ? const Color(0xFF00FF88)
                : Colors.white.withOpacity(0.07),
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel
                    ? const Color(0xFF00FF88)
                    : Colors.transparent,
                border: Border.all(
                  color: sel
                      ? const Color(0xFF00FF88)
                      : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: sel
                  ? const Icon(Icons.check, color: Colors.black, size: 12)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(epi,
                  style: TextStyle(
                      color: sel ? Colors.white : Colors.white60,
                      fontSize: 13)),
            ),
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
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes,
                height: 150, width: double.infinity,
                fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _tirarFoto,
            icon: const Icon(Icons.refresh_rounded, size: 15,
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
    return Row(
      children: [
        Expanded(child: _botaoMidia(
            Icons.camera_alt_outlined, 'Câmera',
                () => _tirarFoto(camera: true))),
        const SizedBox(width: 10),
        Expanded(child: _botaoMidia(
            Icons.photo_library_outlined, 'Galeria',
                () => _tirarFoto(camera: false))),
      ],
    );
  }

  Widget _buildFotoDocumentoSection() {
    if (fotoDocumentoBase64 != null) {
      final bytes = base64Decode(fotoDocumentoBase64!.split(',').last);
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes,
                height: 150, width: double.infinity,
                fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _tirarFotoDocumento,
            icon: const Icon(Icons.refresh_rounded, size: 15,
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
    return Row(
      children: [
        Expanded(child: _botaoMidia(
            Icons.camera_alt_outlined, 'Câmera',
                () => _tirarFotoDocumento(camera: true))),
        const SizedBox(width: 10),
        Expanded(child: _botaoMidia(
            Icons.photo_library_outlined, 'Galeria',
                () => _tirarFotoDocumento(camera: false))),
      ],
    );
  }

  Widget _botaoMidia(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: Colors.white54),
      label: Text(label,
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}