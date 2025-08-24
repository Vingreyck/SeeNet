// lib/login/loginview.controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';

class LoginController extends GetxController {
  TextEditingController loginInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  
  RxBool isLoading = false.obs;
  
  // Instância do UsuarioController
  final UsuarioController usuarioController = Get.find<UsuarioController>();

  Future<void> tryToLogin() async {
    // Validações
    if (loginInput.text.isEmpty) {
      Get.snackbar(
        'Erro',
        'Email não pode ser vazio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (senhaInput.text.isEmpty) {
      Get.snackbar(
        'Erro',
        'Senha não pode ser vazia',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      
      // Tentar fazer login no banco
      bool loginSucesso = await usuarioController.login(
        loginInput.text.trim(),
        senhaInput.text
      );

      if (loginSucesso) {
        Get.snackbar(
          'Sucesso',
          'Login realizado com sucesso!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        // Navegar para checklist
        Get.offAllNamed('/checklist');
      } else {
        Get.snackbar(
          'Erro',
          'Email ou senha incorretos',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Erro ao conectar com servidor',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print('❌ Erro no login: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void registrar() {
    Get.toNamed('/registro');
  }

  @override
  void onClose() {
    loginInput.dispose();
    senhaInput.dispose();
    super.onClose();
  }
}