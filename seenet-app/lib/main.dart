import 'package:flutter/material.dart';
import 'package:seenet/checklist/screen/ChecklistAppsScreen.dart';
import 'package:seenet/checklist/screen/ChecklistIptvScreen.dart';
import 'package:seenet/checklist/screen/ChecklistLentidaoScreen.dart';
import 'package:flutter/services.dart';
import 'package:seenet/seguranca/screens/confirmar_recebimento_screen.dart';
import 'package:seenet/seguranca/screens/registro_manual_epi_screen.dart';
import 'package:seenet/login/widgets/login.binding.dart';
import 'services/tracking_service.dart';
import 'ordem_de_servico/screens/acompanhamento_screen.dart';
import 'package:seenet/registro/registro.view.dart';
import 'package:seenet/admin/usuarios_admin.view.dart';
import 'ordem_de_servico/screens/ordens_servico_screen.dart';
import 'ordem_de_servico/screens/executar_os_screen.dart';
import 'package:seenet/admin/checkmarks_admin.view.dart';
import 'splash_screen/splash_screen.dart';
import 'package:seenet/transcricao/transcricao.view.dart';
import 'package:seenet/transcricao/historico_transcricao.view.dart';
import 'controllers/transcricao_controller.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ NOVO
import 'package:seenet/login/login.view.dart';
import 'package:seenet/checklist/checklist.view.dart';
import 'services/avaliacao_service.dart';
import 'services/categoria_service.dart';
import 'package:seenet/admin/logs_admin.view.dart';
import 'package:seenet/diagnostico/diagnostico.view.dart';
import 'package:seenet/registro/widgets/registro.bindings.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart'; // ✅ NOVO
import 'package:seenet/config/environment.dart';
import 'controllers/usuario_controller.dart';
import 'admin/categorias_admin.view.dart';
import 'controllers/checkmark_controller.dart';
import 'controllers/diagnostico_controller.dart';
import 'package:seenet/seguranca/services/seguranca_service.dart';
import 'package:seenet/seguranca/controllers/seguranca_controller.dart';
import 'package:seenet/seguranca/screens/seguranca_home_screen.dart';
import 'package:seenet/seguranca/screens/requisicao_epi_screen.dart';
import 'package:seenet/seguranca/screens/minhas_requisicoes_screen.dart';
import 'package:seenet/seguranca/screens/gestao_requisicoes_screen.dart';
import 'package:seenet/seguranca/screens/perfil_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INICIALIZAR GETSTORAGE
  await GetStorage.init();

  // ✅ INICIALIZAR FIREBASE
  await Firebase.initializeApp();

  // ✅ CONFIGURAR TELA CHEIA (Edge-to-edge)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // ✅ CONFIGURAR COR DA STATUS BAR
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Environment.load();

  Environment.printConfiguration();
  Environment.validateRequiredKeys();

  if (Environment.isProduction && !Environment.isConfigured) {
    throw Exception('⚠️ Configuração incompleta para produção');
  }

  // ✅ Inicializar controllers/services
  Get.put(ApiService(), permanent: true);
  Get.put(AvaliacaoService(), permanent: true);
  Get.put(CategoriaService(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(UsuarioController(), permanent: true);
  Get.put(CheckmarkController(), permanent: true);
  Get.lazyPut<DiagnosticoController>(() => DiagnosticoController(), fenix: true);
  Get.put(TranscricaoController(), permanent: true);
  Get.put(SegurancaService(), permanent: true);
  Get.put(SegurancaController(), permanent: true);
  Get.put(TrackingService(), permanent: true);


  // ✅ NOVO: Inicializar NotificationService
  final notificationService = Get.put(NotificationService(), permanent: true);
  await notificationService.init();
  notificationService.listenTokenRefresh();

  print('✅ App inicializado - Modo 100% API + Firebase');

  runApp(const MyApp());
}

// ✅ MIDDLEWARE DE AUTENTICAÇÃO
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (route == null) return null;

    List<String> publicRoutes = ['/login', '/registro', '/splash'];
    if (publicRoutes.contains(route)) {
      return null;
    }

    try {
      final usuarioController = Get.find<UsuarioController>();

      if (!usuarioController.isLoggedIn) {
        print('Acesso negado: usuário não autenticado');
        Get.snackbar(
          'Acesso Negado',
          'Faça login para acessar esta área',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
        return const RouteSettings(name: '/login');
      }

      if (route.startsWith('/admin')) {
        if (!usuarioController.isAdmin) {
          print('Acesso negado: usuário não é administrador');
          Get.snackbar(
            'Acesso Negado',
            'Apenas administradores podem acessar esta área',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
          );
          return const RouteSettings(name: '/checklist');
        }
      }

      print('Acesso permitido a: $route');
      return null;
    } catch (e) {
      print('Erro ao verificar autenticação: $e');
      return const RouteSettings(name: '/login');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SeeNet',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      builder: (context, child) {
        return SafeArea(
          top: false,
          bottom: true,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/splash',
      getPages: [
        GetPage(
          name: '/splash',
          page: () => const SplashScreen(),
        ),
        GetPage(
          name: '/login',
          page: () => const LoginView(),
          binding: LoginBindings(),
        ),
        GetPage(
          name: '/checklist',
          page: () => const Checklistview(),
        ),
        GetPage(
          name: '/registro',
          page: () => RegistrarView(),
          binding: RegistroBindings(),
        ),
        GetPage(
          name: '/checklist/apps',
          page: () => const ChecklistAppsScreen(),
        ),
        GetPage(
          name: '/checklist/iptv',
          page: () => const ChecklistIptvScreen(),
        ),
        GetPage(
          name: '/checklist/lentidao',
          page: () => const ChecklistLentidaoScreen(),
        ),
        GetPage(
          name: '/diagnostico',
          page: () => const DiagnosticoView(),
        ),
        GetPage(
          name: '/admin/usuarios',
          page: () => const UsuariosAdminView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/admin/checkmarks',
          page: () => const CheckmarksAdminView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/admin/categorias',
          page: () => const CategoriasAdminView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/admin/logs',
          page: () => const LogsAdminView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/transcricao',
          page: () => const TranscricaoView(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => TranscricaoController());
          }),
        ),
        GetPage(
          name: '/ordens-servico',
          page: () => const OrdensServicoScreen(),
        ),
        GetPage(
          name: '/ordens-servico/executar',
          page: () => const ExecutarOSScreen(),
        ),
        GetPage(
          name: '/transcricao/historico',
          page: () => const HistoricoTranscricaoView(),
        ),
        GetPage(
            name: '/acompanhamento',
            page: () => const AcompanhamentoScreen()
        ),
        GetPage(
          name: '/seguranca',
          page: () => const SegurancaHomeScreen(),
        ),
        GetPage(
          name: '/seguranca/requisicao',
          page: () => const RequisicaoEpiScreen(),
        ),
        GetPage(
          name: '/seguranca/minhas',
          page: () => const MinhasRequisicoesScreen(),
        ),
        GetPage(
          name: '/seguranca/gestao',
          page: () => const GestaoRequisicoesScreen(),
        ),
        GetPage(
          name: '/seguranca/perfil',
          page: () => const PerfilScreen(),
        ),
        GetPage(
          name: '/seguranca/registro-manual',
          page: () => const RegistroManualEpiScreen(),
        ),
        GetPage(
            name: '/seguranca/confirmar-recebimento',
            page: () {
              final args = Get.arguments as Map<String, dynamic>;
              return ConfirmarRecebimentoScreen(
                requisicaoId: args['id'] as int,
                epis: List<String>.from(args['epis']),
              );
            }),
      ],
    );
  }
}