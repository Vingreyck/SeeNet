import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/logarbutton.widget.dart';
import 'widgets/logintextfield.widget.dart';
import 'widgets/senhatextfield.dart';
import 'package:flutter/services.dart'; // ✅ ADICIONAR
import 'widgets/registrarbutton.widget.dart';
import 'widgets/codigoempresa_textfield.dart';
import 'loginview.controller.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart'; // ← NOVO IMPORT

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF6B7280),
                Color(0xFF4B5563),
                Color(0xFF374151),
                Color(0xFF1F2937),
                Color(0xFF111827),
                Color(0xFF0F0F0F),
              ],
              stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/logo.svg',
                        width: 100,
                        height: 100,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'SeeNet',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00FF99),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _body() {
  return Center(
    child: ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const LoginTextField(),
        const SizedBox(height: 30),
        const SenhaTextField(),
        const SizedBox(height: 30),
        const CodigoEmpresaTextField(),
        const SizedBox(height: 60),
        const LogarButton(),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => controller.testarSnackbar(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '🧪 Testar Snackbar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        
        const SizedBox(height: 30),
        const Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.white,
                thickness: 1,
                endIndent: 10,
              ),
            ),
            Text(
              'ou',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white,
                thickness: 1,
                indent: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ainda não tem uma conta?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 5),
            RegistrarButton(),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildTestButton(String title, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: Obx(() {
        return ElevatedButton.icon(
          onPressed: controller.isLoading.value ? null : onPressed,
          icon: controller.isLoading.value
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Icon(icon, size: 18),
          label: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.isLoading.value
                ? const Color(0xFF4B5563).withOpacity(0.5)
                : const Color(0xFF4B5563),
            foregroundColor: Colors.white,
            elevation: controller.isLoading.value ? 0 : 2,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: const Color(0xFF00FF99).withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
        );
      }),
    );
  }


  // ========== MÉTODOS AUXILIARES ==========
  void _showLoading() {
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF99)),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _closeLoadingIfOpen() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  void _showSnackbar(String title, String message, bool isSuccess) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isSuccess
          ? const Color(0xFF00FF99)
          : Colors.red,
      colorText: isSuccess
          ? Colors.black
          : Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(20),
      borderRadius: 12,
      icon: Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        color: isSuccess ? Colors.black : Colors.white,
      ),
    );
  }
}