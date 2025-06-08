import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:seenet/checklist/checklist.view.dart';

class RegistroController extends GetxController {
  TextEditingController nomeInput = TextEditingController();
  TextEditingController emailInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  String email = 'admin@admin.com';
  String password = 'admin123';

  void tryToRegister() {
    if (nomeInput.text.isEmpty) {
      Get.snackbar(
        'Erro',
        'Nome não pode ser vazio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    if (emailInput.text.isEmpty) {
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
    // aqui é adicao de api
    Get.offAllNamed('/checklist');
  }

  void entrar() {
    Get.to(const Checklistview());
  }

  void login() {
    Get.toNamed('/login');
  }
}

