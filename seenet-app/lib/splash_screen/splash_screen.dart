// lib/splash_screen/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();

    // ✅ Após a animação, decidir rota
    _decidirRota();
  }

  Future<void> _decidirRota() async {
    // Espera mínima da splash (1.5s pra animação ficar bonita)
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final authService = Get.find<AuthService>();
      final autoLoginOk = await authService.tryAutoLogin();

      if (autoLoginOk) {
        // Token válido → direto pro checklist
        Get.offAllNamed('/checklist');
      } else {
        // Sem sessão salva ou token expirado → login
        Get.offAllNamed('/login');
      }
    } catch (e) {
      print('❌ Erro na splash: $e');
      Get.offAllNamed('/login');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                // Nome do app
                ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(
                    colors: [Color(0xFF00FF88), Color(0xFFFFFFFF)],
                  ).createShader(bounds),
                  child: const Text(
                    'SeeNet',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gestão de Campo Inteligente',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                // Loading indicator
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00FF88),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}