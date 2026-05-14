// lib/dds/widgets/dds_popup_assinatura.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dds_controller.dart';
import 'package:url_launcher/url_launcher.dart';

// ──────────────────────────────────────────────────────────────
// Chamada externa: DdsPopupAssinatura.mostrar()
// ──────────────────────────────────────────────────────────────
class DdsPopupAssinatura {
  static void mostrar() {
    final ctrl = Get.find<DdsController>();
    if (ctrl.sessaoAtiva.value == null) return;

    Get.dialog(
      const _DdsPopupDialog(),
      barrierDismissible: false,
      barrierColor: Colors.black87,
      useSafeArea: false,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Dialog principal — detecta toque fora e "balança" o card
// ──────────────────────────────────────────────────────────────
class _DdsPopupDialog extends StatefulWidget {
  const _DdsPopupDialog();

  @override
  State<_DdsPopupDialog> createState() => _DdsPopupDialogState();
}

class _DdsPopupDialogState extends State<_DdsPopupDialog>
    with TickerProviderStateMixin {
  // Shake animation
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // Timer
  late Timer _timer;
  int _segundosRestantes = 0;

  final DdsController _ctrl = Get.find<DdsController>();

  // Estado
  bool _assinado = false;
  bool _enviando = false;
  String? _erro;

  // Pad de assinatura
  final List<Offset?> _pontos = [];
  bool _padVazio = true;

  @override
  void initState() {
    super.initState();

    // Shake — bate de um lado pro outro
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -14), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14, end: 14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    // Timer countdown
    final sessao = _ctrl.sessaoAtiva.value;
    _segundosRestantes = (sessao?['segundos_restantes'] as int?) ?? 900;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer t) {
    if (_segundosRestantes <= 0) {
      t.cancel();
      if (mounted && Get.isDialogOpen == true) {
        Get.back(); // fecha o popup quando expirar
      }
      return;
    }
    setState(() => _segundosRestantes--);
  }

  void _shake() {
    _shakeCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _timer.cancel();
    super.dispose();
  }

  // ── Formatação do timer ────────────────────────────────────
  String get _timerStr {
    final m = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_segundosRestantes > 120) return const Color(0xFF00FF88);
    if (_segundosRestantes > 30) return Colors.orange;
    return Colors.red;
  }

  // ── Enviar assinatura ──────────────────────────────────────
  Future<void> _enviar() async {
    if (_padVazio) {
      setState(() => _erro = 'Assine antes de confirmar');
      return;
    }

    setState(() { _enviando = true; _erro = null; });

    final base64 = await _capturarAssinaturaBase64();
    final sessaoId = _ctrl.sessaoAtiva.value?['id'] as int?;
    if (sessaoId == null) return;

    final result = await _ctrl.assinar(
      sessaoId: sessaoId,
      assinaturaBase64: base64,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() { _assinado = true; _enviando = false; });
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted && Get.isDialogOpen == true) Get.back();
    } else {
      setState(() {
        _enviando = false;
        _erro = result['error'] ?? result['message'] ?? 'Erro ao enviar';
      });
    }
  }

  // ── Captura canvas como base64 ─────────────────────────────
  Future<String> _capturarAssinaturaBase64() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 130));

    // Fundo branco
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 300, 130),
      Paint()..color = Colors.white,
    );

    // Traços
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < _pontos.length - 1; i++) {
      if (_pontos[i] != null && _pontos[i + 1] != null) {
        canvas.drawLine(_pontos[i]!, _pontos[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(300, 130);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Toque no fundo escuro → shake
      onTap: _shake,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: GestureDetector(
              // Evita que toque no card feche
              onTap: () {},
              child: _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final sessao = _ctrl.sessaoAtiva.value;
    final tema = sessao?['tema'] as String? ?? '';

    if (_assinado) {
      return _buildSucesso();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.health_and_safety, color: Color(0xFF00FF88), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DDS em andamento',
                        style: TextStyle(color: Color(0xFF00FF88), fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text('Diálogo Diário de Segurança',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              // Timer
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _timerColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _timerColor.withOpacity(0.4)),
                ),
                child: Text(
                  _timerStr,
                  style: TextStyle(
                    color: _timerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Tema
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tema de hoje:', style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Text(tema,
                    style: const TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Link do Meet
          Builder(builder: (_) {
            final link = _ctrl.sessaoAtiva.value?['link_meet'] as String?;
            if (link == null || link.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(link);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A73E8).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_call, color: Color(0xFF1A73E8), size: 20),
                      SizedBox(width: 8),
                      Text('Entrar no Google Meet',
                          style: TextStyle(
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Pad de assinatura
          const Text('Sua assinatura:', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),

          Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _padVazio ? Colors.white24 : const Color(0xFF00FF88),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  // Linha de base (visual)
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: Container(height: 0.8, color: Colors.black12),
                  ),
                  // Canvas de desenho
                  GestureDetector(
                    onPanStart: (d) {
                      setState(() {
                        _pontos.add(d.localPosition);
                        _padVazio = false;
                      });
                    },
                    onPanUpdate: (d) {
                      setState(() => _pontos.add(d.localPosition));
                    },
                    onPanEnd: (_) {
                      setState(() => _pontos.add(null));
                    },
                    child: CustomPaint(
                      painter: _AssinaturaPainter(_pontos),
                      size: const Size(double.infinity, double.infinity),
                    ),
                  ),
                  // Hint
                  if (_padVazio)
                    const Center(
                      child: Text('Assine aqui',
                          style: TextStyle(color: Colors.black26, fontSize: 14)),
                    ),
                  // Botão limpar
                  if (!_padVazio)
                    Positioned(
                      top: 6,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _pontos.clear();
                          _padVazio = true;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.refresh,
                              color: Colors.black38, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 18),

          // Botão confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: const Color(0xFF00FF88).withOpacity(0.4),
              ),
              child: _enviando
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : const Text('Confirmar Presença',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),

          const SizedBox(height: 8),
          const Center(
            child: Text('Este DDS é obrigatório. A assinatura fecha automaticamente\nquando o tempo expirar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSucesso() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 60),
          SizedBox(height: 16),
          Text('Presença registrada!',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Sua assinatura foi salva com sucesso.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Painter para o pad de assinatura
// ──────────────────────────────────────────────────────────────
class _AssinaturaPainter extends CustomPainter {
  final List<Offset?> pontos;

  _AssinaturaPainter(this.pontos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < pontos.length - 1; i++) {
      if (pontos[i] != null && pontos[i + 1] != null) {
        canvas.drawLine(pontos[i]!, pontos[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_AssinaturaPainter old) => old.pontos != pontos;
}