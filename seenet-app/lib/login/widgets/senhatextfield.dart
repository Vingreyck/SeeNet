import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/login/loginview.controller.dart';

class SenhaTextField extends GetView<LoginController> {
  const SenhaTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
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
      ),
    );
  }
}
bool _obscureText = true;
void _toggleVisibility() {
  _obscureText = !_obscureText;
  // Update the state to reflect the change in visibility
  Get.forceAppUpdate();
}

