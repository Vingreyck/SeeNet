// lib/login/loginview.view.dart — REDESIGN PREMIUM
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/logarbutton.widget.dart';
import 'widgets/logintextfield.widget.dart';
import 'widgets/senhatextfield.dart';
import 'widgets/registrarbutton.widget.dart';
import 'widgets/codigoempresa_textfield.dart';
import 'loginview.controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Stack(
          children: [
            // ── Fundo decorativo ──────────────────────────
            const _FundoDecorativo(),

            // ── Conteúdo ──────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),

                        // ── Logo ──────────────────────────
                        Center(child: _buildLogo()),

                        const SizedBox(height: 48),

                        // ── Headline ──────────────────────
                        const Text('Bem-vindo',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        const Text('Acesse sua conta para continuar',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14)),

                        const SizedBox(height: 36),

                        // ── Campos ────────────────────────
                        _wrapField(const LoginTextField()),
                        const SizedBox(height: 14),
                        _wrapField(const SenhaTextField()),
                        const SizedBox(height: 14),
                        _wrapField(const CodigoEmpresaTextField()),

                        const SizedBox(height: 32),

                        // ── Botão entrar ──────────────────
                        const LogarButton(),

                        const SizedBox(height: 36),

                        // ── Divisor ───────────────────────
                        Row(children: [
                          Expanded(child: Divider(
                              color: Colors.white.withOpacity(0.08),
                              thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text('ou',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 12)),
                          ),
                          Expanded(child: Divider(
                              color: Colors.white.withOpacity(0.08),
                              thickness: 1)),
                        ]),

                        const SizedBox(height: 24),

                        // ── Criar conta ───────────────────
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Não tem uma conta? ',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.35),
                                      fontSize: 14)),
                              const RegistrarButton(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // Glow + ícone
        Stack(
          alignment: Alignment.center,
          children: [
            // Halo externo
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF00FF88).withOpacity(0.18),
                  const Color(0xFF00FF88).withOpacity(0.04),
                  Colors.transparent,
                ]),
              ),
            ),
            // Círculo com borda
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FF88).withOpacity(0.08),
                border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.25),
                    width: 1.5),
              ),
              child: Center(
                child: SvgPicture.asset(
                    'assets/images/logo.svg', width: 40, height: 40),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Nome
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFF00FF88)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text('SeeNet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5)),
        ),
        const SizedBox(height: 4),
        Text('Gestão de Campo Inteligente',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }

  Widget _wrapField(Widget field) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF88).withOpacity(0.04),
            blurRadius: 20,
          ),
        ],
      ),
      child: field,
    );
  }
}

// ── Fundo animado ────────────────────────────────────────────────
class _FundoDecorativo extends StatefulWidget {
  const _FundoDecorativo();

  @override
  State<_FundoDecorativo> createState() => _FundoDecorativoState();
}

class _FundoDecorativoState extends State<_FundoDecorativo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _FundoPainter(_ctrl.value),
      ),
    );
  }
}

class _FundoPainter extends CustomPainter {
  final double t;
  _FundoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Blob verde top-right
    final p1 = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.05 + t * 30),
      120, p1,
    );

    // Blob verde bottom-left
    final p2 = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.85 - t * 20),
      100, p2,
    );

    // Grade de pontos
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.025);
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FundoPainter old) => old.t != t;
}