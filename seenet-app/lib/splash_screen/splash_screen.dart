import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/ordem_servico_controller.dart';
import '../ordem_de_servico/screens/executar_os_wizard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/environment.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/avaliacao_service.dart';
import '../services/categoria_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/sync_manager.dart';
import '../services/tracking_service.dart';
import '../services/background_location_service.dart'; // ✅ NOVO
import '../controllers/checkmark_controller.dart';
import '../controllers/diagnostico_controller.dart';
import '../seguranca/services/seguranca_service.dart';
import '../seguranca/controllers/seguranca_controller.dart';
import '../dds/services/dds_service.dart';
import '../dds/controllers/dds_controller.dart';
import '../dds/widgets/dds_popup_assinatura.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      await Future.any([
        _doInit(),
        Future.delayed(const Duration(seconds: 12), () {
          throw TimeoutException('Inicialização demorou demais');
        }),
      ]);
    } catch (e) {
      print('❌ Timeout/erro na inicialização: $e');
      Get.offAllNamed('/login');
    }
  }

  Future<void> _doInit() async {
    try {
      try {
        await Environment.load();
        Environment.validateRequiredKeys();
      } catch (e) {
        print('⚠️ Environment não carregado: $e');
      }

      print('📦 1 ApiService...');
      Get.put(ApiService(), permanent: true);
      print('📦 2 AvaliacaoService...');
      Get.put(AvaliacaoService(), permanent: true);
      print('📦 3 CategoriaService...');
      Get.put(CategoriaService(), permanent: true);
      print('📦 4 AuthService...');
      Get.put(AuthService(), permanent: true);
      print('📦 5 CheckmarkController...');
      Get.put(CheckmarkController(), permanent: true);
      print('📦 6 DiagnosticoController...');
      Get.lazyPut<DiagnosticoController>(() => DiagnosticoController(), fenix: true);
      print('📦 8 SegurancaService...');
      Get.put(SegurancaService(), permanent: true);
      print('📦 9 SegurancaController...');
      Get.put(SegurancaController(), permanent: true);
      print('📦 10 DdsService...');
      Get.put(DdsService(), permanent: true);
      print('📦 11 DdsController...');
      Get.put(DdsController(), permanent: true);
      print('📦 12 TrackingService...');
      Get.put(TrackingService(), permanent: true);
      print('📦 13 SyncManager...');
      Get.put(SyncManager(), permanent: true);
      print('📦 14 ConnectivityService...');
      Get.put(ConnectivityService(), permanent: true);
      print('📦 15 NotificationService...');
      Get.put(NotificationService(), permanent: true);
      print('✅ Todos registrados!');

      try {
        await Firebase.initializeApp();
        Get.find<NotificationService>().init().then((_) {
          Get.find<NotificationService>().listenTokenRefresh();
          print('✅ NotificationService pronto');
        });
      } catch (e) {
        print('⚠️ Firebase não iniciado: $e');
      }

      // ✅ NOVO: Inicializar background GPS service
      try {
        await initializeBackgroundService();
        print('✅ Background GPS service configurado');
      } catch (e) {
        print('⚠️ Background GPS service não iniciado: $e');
      }

      print('✅ App inicializado');

      final elapsed = _animController.lastElapsedDuration?.inMilliseconds ?? 0;
      final remaining = 1500 - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      await _decidirRota();
    } catch (e) {
      print('❌ Erro crítico na inicialização: $e');
      Get.offAllNamed('/login');
    }
  }

  Future<void> _decidirRota() async {
    try {
      final authService = Get.find<AuthService>();
      final autoLoginOk = await authService.tryAutoLogin();

      if (autoLoginOk) {
        final usuarioController = Get.find<UsuarioController>();
        final tipo = usuarioController.tipoUsuario;
        final isWeb = kIsWeb;

        if (isWeb && (usuarioController.isAdmin ||
            tipo == 'gestor' ||
            tipo == 'gestor_seguranca')) {
          Get.offAllNamed('/web-admin');
        } else {
          Get.offAllNamed('/checklist');

          // ✅ Retomar tracking + auto-abrir OS em andamento
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future.delayed(const Duration(milliseconds: 600));

            // Auto-abrir a OS em andamento: o técnico cai direto na OS que estava
            // executando (o wizard restaura o passo + os dados já preenchidos).
            try {
              final osCtrl = Get.isRegistered<OrdemServicoController>()
                  ? Get.find<OrdemServicoController>()
                  : Get.put(OrdemServicoController());
              await osCtrl.carregarMinhasOSs();
              final emAndamento = osCtrl.ordensServico.firstWhereOrNull(
                  (o) => o.status == 'em_execucao' ||
                      o.status == 'em_deslocamento');
              if (emAndamento != null) {
                Get.to(() => const ExecutarOSWizardScreen(),
                    arguments: emAndamento);
              }
            } catch (e) {
              print('⚠️ Auto-abrir OS em andamento: $e');
            }

            try {
              final ddsController = Get.find<DdsController>();
              final temSessao = await ddsController.verificarSessaoAtiva();
              if (temSessao &&
                  ddsController.sessaoAtiva.value?['ja_assinou'] != true) {
                DdsPopupAssinatura.mostrar();
              }
            } catch (e) {
              print('❌ [DDS] ERRO: $e');
            }
          });
        }
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
                SvgPicture.asset('assets/images/logo.svg',
                    width: 100, height: 100),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(
                    colors: [Color(0xFF00FF88), Color(0xFFFFFFFF)],
                  ).createShader(bounds),
                  child: const Text(
                    'SeeNet',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gestão de Campo Inteligente',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Color(0xFF00FF88), strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}