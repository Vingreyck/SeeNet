import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CheckmarkEnviarWidget extends StatelessWidget {
  const CheckmarkEnviarWidget({super.key});

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
        Get.toNamed('/diagnostico');
      },
      child: const Text(
        'Enviar',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      )
    );
  }
}