import 'package:flutter/material.dart';
import 'package:seenet/checklist/screen/ChecklistAppsScreen.dart';
import 'package:seenet/checklist/screen/ChecklistIptvScreen.dart';
import 'package:seenet/checklist/screen/ChecklistLentidaoScreen.dart';
import 'package:seenet/login/widgets/login.binding.dart';
import 'package:seenet/registro/registro.view.dart';
import 'package:seenet/admin/usuarios_admin.view.dart'; 
import 'package:seenet/admin/checkmarks_admin.view.dart'; 
import 'splash_screen/splash_screen.dart';
import 'package:seenet/transcricao/transcricao.view.dart';
import 'package:seenet/transcricao/historico_transcricao.view.dart';
import 'controllers/transcricao_controller.dart';
import 'package:get/get.dart';
import 'package:seenet/config/gemini_config.dart'; 
import 'package:seenet/login/login.view.dart';
import 'package:seenet/checklist/checklist.view.dart';
import 'services/avaliacao_service.dart';
import 'package:seenet/admin/logs_admin.view.dart';
import 'package:seenet/diagnostico/diagnostico.view.dart';
import 'package:seenet/registro/widgets/registro.bindings.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'package:seenet/config/environment.dart';
import 'controllers/usuario_controller.dart';
import 'controllers/checkmark_controller.dart';
import 'controllers/diagnostico_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Configurar ambiente
  Environment.printConfiguration();
  GeminiConfig.printStatus();
  
  // ✅ Verificar configuração
  if (Environment.isProduction && !Environment.isConfigured) {
    throw Exception('⚠️ Configuração incompleta para produção');
  }
  
  // ✅ Inicializar SOMENTE controllers de API
  Get.put(ApiService(), permanent: true);
  Get.put(AvaliacaoService(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(UsuarioController(), permanent: true);
  Get.put(CheckmarkController(), permanent: true);
  Get.put(DiagnosticoController(), permanent: true);
  Get.put(TranscricaoController(), permanent: true);

  print('✅ App inicializado - Modo 100% API');
  
  runApp(const MyApp());
}

// ✅ MIDDLEWARE DE AUTENTICAÇÃO MELHORADO
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // Verificar se a rota requer autenticação
    List<String> protectedRoutes = ['/admin'];
    
    bool isProtected = protectedRoutes.any((r) => route?.startsWith(r) ?? false);
    
    if (isProtected) {
      // Verificar se tem usuário logado
      try {
        final usuarioController = Get.find<UsuarioController>();
        
        if (!usuarioController.isLoggedIn) {
          print('❌ Sem autenticação - redirecionando para login');
          Get.snackbar(
            '🔒 Acesso Negado',
            'Faça login para acessar esta área',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 3),
          );
          return const RouteSettings(name: '/login');
        }
        
        print('✅ Usuário autenticado - permitindo acesso a $route');
      } catch (e) {
        print('❌ Erro ao verificar autenticação: $e');
        return const RouteSettings(name: '/login');
      }
    }
    
    return null; // Permitir navegação
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
      ),
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
        // ✅ ROTAS ADMIN PROTEGIDAS
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
          name: '/transcricao/historico',
          page: () => const HistoricoTranscricaoView(),
        )
      ],
    );
  }
}