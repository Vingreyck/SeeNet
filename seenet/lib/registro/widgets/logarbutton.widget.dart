import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/registro/registroview.controller.dart';

class LogarButton extends GetView<RegistroController>{
  const LogarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10BC4C),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        minimumSize: const Size(double.infinity, 80), // largura total
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      onPressed: () {
        controller.tryToRegister();
      },
      child: const Text('Entrar',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 32,
        )
      )
    );
  }
}