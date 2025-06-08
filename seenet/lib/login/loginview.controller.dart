import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:seenet/checklist/checklist.view.dart';

class LoginController extends GetxController {
  TextEditingController loginInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  String login = 'admin@admin.com';
  String password = 'admin123';

  void tryToLogin() {
    if (loginInput.text == login) {
      checkPassoword();
    } else if (loginInput.text == '') {
      Get.snackbar(
        'Erro',
        'Usuário não pode ser vazio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Erro',
        'Usuário incorreto',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  void checkPassoword() {
    if (senhaInput.text == password) {
      Get.offAllNamed('/checklist'); // impede voltar para login
    } else {
      Get.snackbar(
        'Erro',
        'Senha incorreta',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void entrar(){
    Get.to(const Checklistview());
  }

  void registrar(){
    Get.toNamed('/registro');
  }
}