import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:seenet/checklist/checklist.view.dart';
import 'package:seenet/models/user.model.dart';

class LoginController extends GetxController {
  TextEditingController loginInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();

  final RxList<User> userList = RxList();

  @override
  void onInit() {
    super.onInit();
  
  userList.add(User('teste@gmail.com', 'senha123'));
  userList.add(User('admin@admin.com', 'admin123'));
  }

  void tryToLogin() {
    if (loginInput.text.isEmpty) {
      Get.snackbar(
        'Erro',
        'Usuário não pode ser vazio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    for (var user in userList) {
      if (user.email == loginInput.text && user.password == senhaInput.text) {
        Get.offAllNamed('/checklist');
        return;
      }
    }

    Get.snackbar(
      'Erro',
      'Usuário ou senha incorretos',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  void entrar(){
    Get.to(const ChecklistView());
  }

  void registrar(){
    Get.toNamed('/registro');
  }
}