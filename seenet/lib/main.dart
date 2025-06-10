import 'package:flutter/material.dart';
import 'package:seenet/login/widgets/login.binding.dart';
import 'package:seenet/registro/registro.view.dart';
import 'splash_screen/splash_screen.dart';
import 'package:get/get.dart';
import 'package:seenet/login/login.view.dart';
import 'package:seenet/checklist/checklist.view.dart';
import 'package:seenet/checklist/screen/ChecklistLentidaoScreen.dart';
import 'package:seenet/registro/widgets/registro.bindings.dart';
import 'package:seenet/checklist/screen/ChecklistIptvScreen.dart';
import 'package:seenet/diagnostico/diagnostico.view.dart';
import 'package:seenet/checklist/screen/ChecklistAppsScreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialBinding: LoginBindings(),
      
      debugShowCheckedModeBanner: false,
      title: 'SeeNet',
      theme: ThemeData(
        primarySwatch: Colors.green,
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
        ),
        GetPage(
          name: '/checklist',
          page: () => const ChecklistView(),
        ),
        GetPage(
          name: '/checklist/lentidao',
          page: () => const ChecklistLentidaoScreen(),
        ),
        GetPage(
          name: '/checklist/iptv',
          page: () => const ChecklistIptvScreen(), // Placeholder for IPTV screen
        ),
        GetPage(
          name: '/checklist/apps',
          page: () => const ChecklistAppsScreen(), // Placeholder for Apps screen
        ),
        GetPage(
          name: '/diagnostico',
          page: () => const Diagnosticoview(), // Placeholder for Diagnostico screen
        ),
        GetPage(
          name: '/registro',
          page: () => const RegistrarView(),
          binding: RegistroBindings(),
        ),
      ],
    );
  }
}