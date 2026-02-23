// lib/login/widgets/logintextfield.widget.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/login/loginview.controller.dart';

class LoginTextField extends GetView<LoginController> {
  const LoginTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => TextField(
      controller: controller.loginInput,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: 'Nome Completo',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(
            color: Colors.white70,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide(
            color: controller.emailError.value.isEmpty
                ? Colors.white70
                : Colors.red,
            width: controller.emailError.value.isEmpty ? 1.0 : 2.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide(
            color: controller.emailError.value.isEmpty
                ? const Color(0xFF00FF99)
                : Colors.red,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        prefixIcon: const Icon(Icons.person),
        filled: true,
        fillColor: Colors.white70,
        errorText: controller.emailError.value.isEmpty
            ? null
            : controller.emailError.value,
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        errorMaxLines: 2,
      ),
      onChanged: (value) {
        if (controller.emailError.value.isNotEmpty) {
          controller.emailError.value = '';
        }
      },
    ));
  }
}