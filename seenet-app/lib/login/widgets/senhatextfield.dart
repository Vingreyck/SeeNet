import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/login/loginview.controller.dart';

class SenhaTextField extends GetView<LoginController> {
  const SenhaTextField({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ ENVOLVER COM Obx()
    return Obx(() => TextField(
      controller: controller.senhaInput,
      obscureText: _obscureText,
      decoration: InputDecoration(
        hintText: 'Senha',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(
            color: Colors.white70,
            width: 1.0,
          ),
        ),
        // ✅ ADICIONAR enabledBorder
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide(
            color: controller.senhaError.value.isEmpty 
                ? Colors.white70 
                : Colors.red,
            width: controller.senhaError.value.isEmpty ? 1.0 : 2.0,
          ),
        ),
        // ✅ ADICIONAR focusedBorder
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide(
            color: controller.senhaError.value.isEmpty 
                ? const Color(0xFF00FF99) 
                : Colors.red,
            width: 2.0,
          ),
        ),
        // ✅ ADICIONAR errorBorder
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        prefixIcon: const Icon(Icons.lock_outline, color: Color.fromARGB(179, 0, 0, 0)),
        filled: true,
        fillColor: Colors.white70,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: const Color.fromARGB(179, 0, 0, 0),
          ),
          onPressed: _toggleVisibility,
        ),
        // ✅ ADICIONAR errorText
        errorText: controller.senhaError.value.isEmpty 
            ? null 
            : controller.senhaError.value,
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      // ✅ ADICIONAR onChanged
      onChanged: (value) {
        if (controller.senhaError.value.isNotEmpty) {
          controller.senhaError.value = '';
        }
      },
    )); // ✅ Fechar Obx()
  }
}

// ✅ MANTER ESTAS FUNÇÕES COMO ESTÃO:
bool _obscureText = true;
void _toggleVisibility() {
  _obscureText = !_obscureText;
  Get.forceAppUpdate();
}