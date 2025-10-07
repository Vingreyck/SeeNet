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
import 'package:seenet/admin/logs_admin.view.dart';
import 'package:seenet/diagnostico/diagnostico.view.dart';
import 'package:seenet/registro/widgets/registro.bindings.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

// Configuração de ambiente
import 'package:seenet/config/environment.dart';

// Controllers (SÓ API - SEM SQLite)
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
  Get.put(AuthService(), permanent: true);
  Get.put(UsuarioController(), permanent: true);
  Get.put(CheckmarkController(), permanent: true);
  Get.put(DiagnosticoController(), permanent: true);
  Get.put(TranscricaoController(), permanent: true);
  await Get.find<ApiService>().debugEndpoints();


  _testarEndpoints();

  print('✅ App inicializado - Modo 100% API');
  
  runApp(const MyApp());
}
void _testarEndpoints() {
  print('\n🧪 === TESTE DE RESOLUÇÃO DE ENDPOINTS ===');
  
  final apiService = Get.find<ApiService>();
  
  // Testar diferentes tipos de endpoints
  final testes = [
    'categorias',
    'checkmarksPorCategoria/1',
    'criarAvaliacao',
    'salvarRespostas/123',
    '/checkmark/categorias',
    '/avaliacoes',
  ];
  
  for (var endpoint in testes) {
    try {
      // Chamar o método privado indiretamente via reflection ou fazer público
      print('📍 "$endpoint" -> [resultado depende do código]');
    } catch (e) {
      print('❌ Erro ao resolver "$endpoint": $e');
    }
  }
  
  print('================================\n');
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
        GetPage(
          name: '/admin/usuarios',
          page: () => const UsuariosAdminView(),
        ),
        GetPage(
          name: '/admin/checkmarks',
          page: () => const CheckmarksAdminView(),
        ),
        GetPage(
          name: '/admin/logs',
          page: () => const LogsAdminView(),
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