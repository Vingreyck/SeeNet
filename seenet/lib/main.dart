// lib/main.dart - VERSÃO ATUALIZADA
import 'package:flutter/material.dart';
import 'package:seenet/checklist/screen/ChecklistAppsScreen.dart';
import 'package:seenet/checklist/screen/ChecklistIptvScreen.dart';
import 'package:seenet/checklist/screen/ChecklistLentidaoScreen.dart';
import 'package:seenet/login/widgets/login.binding.dart';
import 'package:seenet/registro/registro.view.dart';
import 'splash_screen/splash_screen.dart';
import 'package:get/get.dart';
import 'package:seenet/login/login.view.dart';
import 'package:seenet/checklist/checklist.view.dart';
import 'package:seenet/diagnostico/diagnostico.view.dart';
import 'package:seenet/registro/widgets/registro.bindings.dart';

// Importar controllers
import 'controllers/usuario_controller.dart';
import 'controllers/checkmark_controller.dart';
import 'controllers/diagnostico_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar controllers globais
  Get.put(UsuarioController(), permanent: true);
  Get.put(CheckmarkController(), permanent: true);
  Get.put(DiagnosticoController(), permanent: true);
  
  runApp(const MyApp());
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
          page: () => const RegistrarView(),
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
          page: () => const Diagnosticoview(),
        ),
      ],
    );
  }
}