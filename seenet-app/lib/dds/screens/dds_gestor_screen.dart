// lib/dds/screens/dds_gestor_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../controllers/dds_controller.dart';
import '../services/dds_service.dart';

class DdsGestorScreen extends StatefulWidget {
  const DdsGestorScreen({super.key});

  @override
  State<DdsGestorScreen> createState() => _DdsGestorScreenState();
}

class _DdsGestorScreenState extends State<DdsGestorScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = Get.find<DdsController>();
  final _service = Get.find<DdsService>();
  String? _linkMeet;
  final _linkMeetCtrl = TextEditingController();
  late TabController _tabCtrl;

  // Formulário
  final _temaCtrl = TextEditingController();
  int _duracaoMinutos = 15;
  String _localDds = 'BBNet Up Provedor';

  // Sessão ativa (timer local)
  Timer? _timerLocal;
  int _segundosRestantes = 0;

  // Config responsável
  Map<String, dynamic>? _config;
  bool _loadingConfig = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _carregarSessaoAtiva();
    _carregarConfig();
  }

  Future<void> _carregarSessaoAtiva() async {
    await _ctrl.verificarSessaoAtiva();
    final sessao = _ctrl.sessaoAtiva.value;
    if (sessao != null) {
      _segundosRestantes = sessao['segundos_restantes'] as int? ?? 0;
      _iniciarTimerLocal();
    }
  }

  Future<void> _carregarConfig() async {
    final c = await _service.buscarConfig();
    if (mounted) setState(() { _config = c; _loadingConfig = false; });
  }

  void _iniciarTimerLocal() {
    _timerLocal?.cancel();
    _timerLocal = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes <= 0) {
        t.cancel();
        _ctrl.verificarSessaoAtiva(); // recarrega para pegar status 'expirado'
        return;
      }
      setState(() => _segundosRestantes--);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _temaCtrl.dispose();
    _linkMeetCtrl.dispose(); // ← mover para antes do super
    _timerLocal?.cancel();
    super.dispose();         // ← super sempre por último
  }

  String get _timerStr {
    final m = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Abrir sessão ───────────────────────────────────────────
  Future<void> _abrirSessao() async {
    if (_temaCtrl.text.trim().isEmpty) {
      Get.snackbar('Atenção', 'Informe o tema do DDS',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    final result = await _ctrl.criarSessao(
      tema: _temaCtrl.text.trim(),
      duracaoMinutos: _duracaoMinutos,
      localDds: _localDds,
      linkMeet: _linkMeetCtrl.text.trim().isEmpty
          ? null
          : _linkMeetCtrl.text.trim(),
    );

    if (result['success'] == true) {
      _temaCtrl.clear();
      _linkMeetCtrl.clear();
      _segundosRestantes = _duracaoMinutos * 60;
      _iniciarTimerLocal();
      Get.snackbar('DDS aberto!', 'Os técnicos já podem assinar a presença.',
          backgroundColor: const Color(0xFF00FF88), colorText: Colors.black);
    } else {
      Get.snackbar('Erro', result['error'] ?? 'Falha ao abrir DDS',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _encerrarSessao() async {
    final sessaoId = _ctrl.sessaoAtiva.value?['id'] as int?;
    if (sessaoId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Encerrar DDS?', style: TextStyle(color: Colors.white)),
        content: const Text('Os técnicos não poderão mais assinar esta sessão.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Encerrar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      _timerLocal?.cancel();
      await _ctrl.encerrarSessao(sessaoId);
      setState(() => _segundosRestantes = 0);
      Get.snackbar('Sessão encerrada', 'DDS finalizado com sucesso.',
          backgroundColor: Colors.orange, colorText: Colors.white);
    }
  }

  // ── Upload assinatura do responsável ───────────────────────
  Future<void> _uploadAssinaturaResponsavel() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final result = await _service.salvarConfig({
      'responsavel_assinatura': base64Str,
    });

    if (result['success'] == true) {
      setState(() => _config = { ...?_config, 'responsavel_assinatura': base64Str });
      Get.snackbar('Salvo!', 'Assinatura do responsável atualizada.',
          backgroundColor: const Color(0xFF00FF88), colorText: Colors.black);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('DDS', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF00FF88),
          labelColor: const Color(0xFF00FF88),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Sessão'),
            Tab(text: 'Configurações'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildAbaSessao(),
          _buildAbaConfig(),
        ],
      ),
    );
  }

  // ── Aba Sessão ─────────────────────────────────────────────
  Widget _buildAbaSessao() {
    return Obx(() {
      final sessaoAtiva = _ctrl.sessaoAtiva.value;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sessaoAtiva != null)
              _buildCardSessaoAtiva(sessaoAtiva)
            else
              _buildFormNovaSessao(),
          ],
        ),
      );
    });
  }

  Widget _buildFormNovaSessao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nova Sessão de DDS',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Preencha os dados e abra a sessão. Os técnicos receberão o popup automaticamente ao fazer login.',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 24),

        // Tema
        const Text('Tema do DDS *', style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _temaCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Ex: Higiene Pessoal, Choque Elétrico...',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counterStyle: const TextStyle(color: Colors.white24),
          ),
        ),

        const SizedBox(height: 16),

        // Local
        const Text('Local', style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          controller: TextEditingController(text: _localDds),
          onChanged: (v) => _localDds = v,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 16),

        const SizedBox(height: 16),
        const Text('Link do Google Meet (opcional)',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _linkMeetCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (v) => _linkMeet = v,
          decoration: InputDecoration(
            hintText: 'https://meet.google.com/xxx-xxxx-xxx',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: const Icon(Icons.video_call, color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // Duração
        const Text('Tempo de assinatura', style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [5, 10, 15, 20, 30, 45, 60].map((m) {
            final sel = _duracaoMinutos == m;
            return GestureDetector(
              onTap: () => setState(() => _duracaoMinutos = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF00FF88).withOpacity(0.15) : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? const Color(0xFF00FF88) : Colors.white12,
                  ),
                ),
                child: Text('${m}min',
                    style: TextStyle(
                      color: sel ? const Color(0xFF00FF88) : Colors.white54,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        Obx(() => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _ctrl.isSending.value ? null : _abrirSessao,
            icon: _ctrl.isSending.value
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded, color: Colors.black),
            label: const Text('Abrir Sessão de DDS',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildCardSessaoAtiva(Map<String, dynamic> sessao) {
    final tema = sessao['tema'] as String? ?? '';
    final timerColor = _segundosRestantes > 120
        ? const Color(0xFF00FF88)
        : _segundosRestantes > 30 ? Colors.orange : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card principal
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFF00FF88), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('AO VIVO',
                            style: TextStyle(color: Color(0xFF00FF88),
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Timer grande
                  Text(_timerStr,
                      style: TextStyle(
                        color: timerColor, fontSize: 28, fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Tema:', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 4),
              Text(tema,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Local: ${sessao['local_dds'] ?? 'BBNet Up Provedor'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Botão encerrar
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _encerrarSessao,
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            label: const Text('Encerrar Sessão',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Dica
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Os técnicos verão o popup de assinatura ao abrir o app. Quando o tempo acabar, a sessão é encerrada automaticamente.',
                  style: TextStyle(color: Colors.blue, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Aba Configurações ──────────────────────────────────────
  Widget _buildAbaConfig() {
    if (_loadingConfig) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Responsável Técnico de Segurança',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Esses dados aparecem no rodapé dos documentos PDF de DDS.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 20),

          _buildConfigField('Nome', _config?['responsavel_nome'] ?? ''),
          _buildConfigField('Cargo', _config?['responsavel_cargo'] ?? ''),
          _buildConfigField('Registro 1', _config?['responsavel_registro1'] ?? ''),
          _buildConfigField('Registro 2', _config?['responsavel_registro2'] ?? ''),

          const SizedBox(height: 16),

          // Assinatura
          const Text('Assinatura do Responsável',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 10),

          if (_config?['responsavel_assinatura'] != null) ...[
            Container(
              height: 80,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: Builder(builder: (_) {
                try {
                  final clean = (_config!['responsavel_assinatura'] as String)
                      .replaceFirst(RegExp(r'^data:image/\w+;base64,'), '');
                  return Image.memory(base64Decode(clean), fit: BoxFit.contain);
                } catch (_) {
                  return const Center(child: Text('Assinatura salva',
                      style: TextStyle(color: Colors.black54)));
                }
              }),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadAssinaturaResponsavel,
              icon: Icon(
                _config?['responsavel_assinatura'] != null
                    ? Icons.refresh : Icons.upload_file,
                color: const Color(0xFF00FF88),
              ),
              label: Text(
                _config?['responsavel_assinatura'] != null
                    ? 'Substituir assinatura' : 'Enviar assinatura (imagem)',
                style: const TextStyle(color: Color(0xFF00FF88)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00FF88)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigField(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value.isNotEmpty ? value : '—',
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}