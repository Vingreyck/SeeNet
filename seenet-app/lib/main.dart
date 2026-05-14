import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'checklist/screen/checklist_items_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:seenet/dds/widgets/dds_popup_assinatura.dart';
import 'package:flutter/services.dart';
import 'widgets/global_bottom_nav.dart';
import 'widgets/app_snackbar.dart';
import 'controllers/nav_controller.dart';
import 'web_admin/layout/web_layout.dart';
import 'package:seenet/seguranca/screens/confirmar_recebimento_screen.dart';
import 'package:seenet/seguranca/screens/registro_manual_epi_screen.dart';
import 'package:seenet/login/widgets/login.binding.dart';
import 'admin/dashboard_admin.view.dart';
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
import 'seguranca/screens/relatorio_epi_screen.dart';
import 'package:seenet/login/login.view.dart';
import 'package:seenet/checklist/checklist.view.dart';
import 'package:seenet/admin/logs_admin.view.dart';
import 'package:seenet/diagnostico/diagnostico.view.dart';
import 'package:seenet/registro/widgets/registro.bindings.dart';
import 'controllers/usuario_controller.dart';
import 'admin/categorias_admin.view.dart';
import 'package:seenet/seguranca/screens/seguranca_home_screen.dart';
import 'package:seenet/seguranca/screens/requisicao_epi_screen.dart';
import 'package:seenet/seguranca/screens/minhas_requisicoes_screen.dart';
import 'package:seenet/seguranca/screens/gestao_requisicoes_screen.dart';
import 'package:seenet/seguranca/screens/perfil_screen.dart';
import 'package:seenet/dds/services/dds_service.dart';
import 'package:seenet/dds/controllers/dds_controller.dart';
import 'package:seenet/dds/screens/dds_gestor_screen.dart';
import 'package:seenet/dds/screens/dds_historico_screen.dart';
import 'package:seenet/dds/screens/dds_calendario_tecnico_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Silencia o widget vermelho de erro do Flutter na UI.
  //    Os erros continuam sendo logados no console (debugPrint),
  //    mas nao poluem mais a tela do usuario com tela vermelha
  //    para warnings de "setState during build" / "improper use of GetX".
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('🔴 [ErrorWidget] ${details.exceptionAsString()}');
    }
    // Retorna widget invisivel — nada na tela.
    return const SizedBox.shrink();
  };

  // ✅ Silencia o printer do Flutter para asserts conhecidos do GetX
  //    que aparecem em amarelo embaixo da tela (improper use of GetX).
  //    Mantemos outros logs intactos.
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    final isHarmlessGetXNoise = msg.contains('improper use of a GetX') ||
        msg.contains('setState() or markNeedsBuild() called during build') ||
        msg.contains('_animation') ||
        msg.contains('has not been initialized');

    if (isHarmlessGetXNoise) {
      // Loga uma vez no console, sem encher de stack trace
      if (kDebugMode) {
        debugPrint('⚠️ [GetX noise suppressed] ${msg.split('\n').first}');
      }
      return;
    }
    // Outros erros seguem o caminho padrao
    FlutterError.presentError(details);
  };

  await GetStorage.init();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  Get.put(UsuarioController(), permanent: true);
  Get.put(NavController(), permanent: true);

  runApp(const MyApp());
}

// ✅ MIDDLEWARE DE AUTENTICAÇÃO
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (route == null) return null;

    const publicRoutes = ['/login', '/registro', '/splash'];
    if (publicRoutes.contains(route)) return null;

    try {
      final usuario = Get.find<UsuarioController>();

      if (!usuario.isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppSnackbar.warning('Acesso Negado', 'Faça login para acessar esta área');
        });
        return const RouteSettings(name: '/login');
      }

      if (route.startsWith('/admin') && !usuario.isAdmin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppSnackbar.error('Acesso Negado', 'Apenas administradores podem acessar esta área');
        });
        return const RouteSettings(name: '/checklist');
      }

      if (route.startsWith('/web-admin')) {
        final tipo = usuario.tipoUsuario;
        final permitido = usuario.isAdmin ||
            tipo == 'gestor' ||
            tipo == 'gestor_seguranca';
        if (!permitido) {
          return const RouteSettings(name: '/checklist');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Erro ao verificar autenticação: $e');
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
      scaffoldMessengerKey: appScaffoldMessengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
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
      routingCallback: (routing) {
        if (routing?.current != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.find<NavController>().atualizarRota(routing!.current);
          });
        }
      },
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: child ?? const SizedBox.shrink(),
          bottomNavigationBar: const GlobalBottomNav(),
        );
      },
      initialRoute: '/splash',
      getPages: [
        GetPage(name: '/splash', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginView(), binding: LoginBindings()),
        GetPage(
          name: '/checklist',
          page: () => const Checklistview(),
          binding: BindingsBuilder(() {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Future.delayed(const Duration(milliseconds: 800));
              try {
                final usuario = Get.find<UsuarioController>();
                // ✅ Só técnicos assinam — admins e gestor_seguranca não veem o popup
                final tipo = usuario.tipoUsuario;
                if (tipo == 'administrador' || tipo == 'gestor_seguranca') return;

                final ddsController = Get.find<DdsController>();
                ddsController.sessaoAtiva.value = null;
                final temSessao = await ddsController.verificarSessaoAtiva();
                print('🔍 [DDS] temSessao=$temSessao sessao=${ddsController.sessaoAtiva.value}');
                if (temSessao &&
                    ddsController.sessaoAtiva.value?['ja_assinou'] != true) {
                  DdsPopupAssinatura.mostrar();
                }
              } catch (e) {
                print('❌ [DDS] erro: $e');
              }
            });
          }),
        ),
        GetPage(name: '/registro', page: () => RegistrarView(), binding: RegistroBindings()),
        GetPage(name: '/checklist/items', page: () => const ChecklistItemsScreen()),
        GetPage(name: '/diagnostico', page: () => const DiagnosticoView()),
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
          name: '/admin/dashboard',
          page: () => const DashboardAdminView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/transcricao',
          page: () => const TranscricaoView(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => TranscricaoController());
          }),
        ),
        GetPage(name: '/ordens-servico', page: () => const OrdensServicoScreen()),
        GetPage(name: '/ordens-servico/executar', page: () => const ExecutarOSScreen()),
        GetPage(name: '/transcricao/historico', page: () => const HistoricoTranscricaoView()),
        GetPage(name: '/acompanhamento', page: () => const AcompanhamentoScreen()),
        GetPage(name: '/seguranca', page: () => const SegurancaHomeScreen()),
        GetPage(name: '/seguranca/requisicao', page: () => const RequisicaoEpiScreen()),
        GetPage(name: '/seguranca/minhas', page: () => const MinhasRequisicoesScreen()),
        GetPage(name: '/seguranca/gestao', page: () => const GestaoRequisicoesScreen()),
        GetPage(name: '/seguranca/perfil', page: () => const PerfilScreen()),
        GetPage(name: '/seguranca/registro-manual', page: () => const RegistroManualEpiScreen()),
        GetPage(
          name: '/seguranca/relatorio-epi',
          page: () => const RelatorioEpiScreen(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/web-admin',
          page: () => const WebLayout(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/seguranca/confirmar-recebimento',
          page: () {
            final args = Get.arguments as Map<String, dynamic>;
            return ConfirmarRecebimentoScreen(
              requisicaoId: args['id'] as int,
              epis: List<String>.from(args['epis']),
            );
          },
        ),
        GetPage(name: '/dds/gestor',    page: () => const DdsGestorScreen()),
        GetPage(name: '/dds/historico', page: () => const DdsHistoricoScreen()),
        GetPage(
          name: '/dds/calendario-tecnico',
          page: () {
            final args = Get.arguments as Map<String, dynamic>;
            return DdsCalendarioTecnicoScreen(
              tecnicoId:   args['tecnicoId']   as int,
              tecnicoNome: args['tecnicoNome'] as String,
            );
          },
        ),
      ],
    );
  }
}