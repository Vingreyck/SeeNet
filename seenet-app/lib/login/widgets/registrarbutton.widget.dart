import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/login/loginview.controller.dart';

class RegistrarButton extends GetView<LoginController> {
  const RegistrarButton({super.key});

  @override
  Widget build (BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          controller.registrar(); // Chama o método de registro do controller
        },
        child: const Text(
          'Registre-se',
          style: TextStyle(
            color: Color.fromARGB(255, 30, 194, 46),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}