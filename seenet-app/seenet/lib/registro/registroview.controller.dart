// lib/registro/registroview.controller.dart - VERSÃO CORRIGIDA
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';

class RegistroController extends GetxController {
  TextEditingController nomeInput = TextEditingController();
  TextEditingController emailInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  
  RxBool isLoading = false.obs;
  
  // Instância do UsuarioController
  final UsuarioController usuarioController = Get.find<UsuarioController>();

  Future<void> tryToRegister() async {
    // Validações básicas
    if (nomeInput.text.trim().isEmpty) {
      Get.snackbar(
        'Erro',
        'Nome não pode ser vazio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (nomeInput.text.trim().length < 2) {
      Get.snackbar(
        'Erro',
        'Nome deve ter pelo menos 2 caracteres',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (emailInput.text.trim().isEmpty) {
      Get.snackbar(
        'Erro',
        'Email não pode ser vazio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Validação de email
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailInput.text.trim())) {
      Get.snackbar(
        'Erro',
        'Email inválido',
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

    if (senhaInput.text.length < 6) {
      Get.snackbar(
        'Erro',
        'Senha deve ter pelo menos 6 caracteres',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      
      // ✅ AQUI É A CORREÇÃO - Usar o UsuarioController para registrar
      bool registroSucesso = await usuarioController.registrar(
        nomeInput.text.trim(),
        emailInput.text.trim(),
        senhaInput.text
      );

      if (registroSucesso) {
        Get.snackbar(
          'Sucesso',
          'Usuário registrado com sucesso!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        // Navegar para checklist (o login é automático)
        Get.offAllNamed('/checklist');
      } else {
        Get.snackbar(
          'Erro',
          'Erro ao registrar usuário. Email pode já estar em uso.',
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
      print('❌ Erro no registro: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void login() {
    Get.toNamed('/login');
  }

  @override
  void onClose() {
    nomeInput.dispose();
    emailInput.dispose();
    senhaInput.dispose();
    super.onClose();
  }
}