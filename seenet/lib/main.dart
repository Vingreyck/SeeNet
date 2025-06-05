import 'package:flutter/material.dart';
import 'package:seenet/checklist/screen/ChecklistAppsScreen.dart';
import 'package:seenet/checklist/screen/ChecklistIptvScreen.dart';
import 'package:seenet/checklist/screen/ChecklistLentidaoScreen.dart';
import 'package:seenet/registro/registro.view.dart';
import 'splash_screen/splash_screen.dart';
import 'package:get/get.dart';
import 'package:seenet/login/login.view.dart';
import 'package:seenet/checklist/checklist.view.dart';

void main() {
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
      ),
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen()),
        GetPage(name: '/login', page: () => const LoginView()),
        GetPage(name: '/registro', page: () => const RegistrarView()),
        GetPage(name: '/checklist', page: () => const Checklistview()),
        GetPage(name: '/checklist/lentidao', page: () => const ChecklistLentidaoScreen()),
        GetPage(name: '/checklist/iptv', page: () => const ChecklistIptvScreen()),
        GetPage(name: '/checklist/apps', page: () => const ChecklistAppsScreen()),
      ],
    );
  }
}