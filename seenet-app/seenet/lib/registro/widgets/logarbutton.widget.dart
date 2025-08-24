// lib/registro/widgets/logarbutton.widget.dart - VERSÃO CORRIGIDA
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/registro/registroview.controller.dart';

class LogarButton extends GetView<RegistroController> {
  const LogarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10BC4C),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        minimumSize: const Size(double.infinity, 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      onPressed: controller.isLoading.value ? null : () {
        controller.tryToRegister();
      },
      child: controller.isLoading.value
          ? const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            )
          : const Text(
              'Registrar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
    ));
  }
}