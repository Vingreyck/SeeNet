import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/environment.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/avaliacao_service.dart';
import '../services/categoria_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/sync_manager.dart';
import '../services/tracking_service.dart';
import '../controllers/checkmark_controller.dart';
import '../controllers/diagnostico_controller.dart';
import '../controllers/transcricao_controller.dart';
import '../seguranca/services/seguranca_service.dart';
import '../seguranca/controllers/seguranca_controller.dart';

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

    // ✅ Roda DEPOIS que o primeiro frame foi pintado na tela
    //    O técnico já vê a splash enquanto isso carrega em background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // ✅ Firebase + Environment em paralelo (antes rodavam um após o outro)
      await Future.wait([
        Firebase.initializeApp(),
        Environment.load(),
      ]);

      Environment.validateRequiredKeys();

      if (Environment.isProduction && !Environment.isConfigured) {
        throw Exception('⚠️ Configuração incompleta para produção');
      }

      // ✅ Get.put() — síncrono, rápido
      Get.put(ApiService(), permanent: true);
      Get.put(AvaliacaoService(), permanent: true);
      Get.put(CategoriaService(), permanent: true);
      Get.put(AuthService(), permanent: true);
      Get.put(CheckmarkController(), permanent: true);
      Get.lazyPut<DiagnosticoController>(() => DiagnosticoController(), fenix: true);
      Get.put(TranscricaoController(), permanent: true);
      Get.put(SegurancaService(), permanent: true);
      Get.put(SegurancaController(), permanent: true);
      Get.put(TrackingService(), permanent: true);
      Get.put(SyncManager(), permanent: true);
      Get.put(ConnectivityService(), permanent: true);

      // ✅ NotificationService dispara sem await — não bloqueia a navegação
      final notificationService = Get.put(NotificationService(), permanent: true);
      notificationService.init().then((_) {
        notificationService.listenTokenRefresh();
        print('✅ NotificationService pronto');
      });

      print('✅ App inicializado em background');

      final elapsed = _animController.lastElapsedDuration?.inMilliseconds ?? 0;
      final remaining = 1500 - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      await _decidirRota();

    } catch (e) {
      print('❌ Erro na inicialização: $e');
      Get.offAllNamed('/login');
    }
  }

  Future<void> _decidirRota() async {
    try {
      final authService = Get.find<AuthService>();
      final autoLoginOk = await authService.tryAutoLogin();

      if (autoLoginOk) {
        Get.offAllNamed('/checklist');
      } else {
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
    // build idêntico ao seu — sem alteração
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
                SvgPicture.asset('assets/images/logo.svg', width: 100, height: 100),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(
                    colors: [Color(0xFF00FF88), Color(0xFFFFFFFF)],
                  ).createShader(bounds),
                  child: const Text(
                    'SeeNet',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gestão de Campo Inteligente',
                  style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1.2),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}