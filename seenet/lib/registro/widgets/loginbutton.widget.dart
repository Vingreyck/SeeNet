import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build (BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          // ação ao tocar no texto
          Get.toNamed('/login');
        },
        child: const Text(
          'Entrar',
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