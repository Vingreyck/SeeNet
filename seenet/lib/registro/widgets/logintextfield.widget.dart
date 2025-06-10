import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/registro/registroview.controller.dart';

class LoginTextField extends GetView<RegistroController> {
  const LoginTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.emailInput,
      decoration: InputDecoration(
        hintText: 'Usuário ou Email',
        border: OutlineInputBorder( 
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(
            color: Colors.white70,
            width: 1.0,
          ),
        ),
        prefixIcon: const Icon(Icons.person),
        filled: true,
        fillColor: Colors.white70,

      ),
    );
  }
}