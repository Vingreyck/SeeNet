import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/registro/registroview.controller.dart';

class NomeTextField extends GetView<RegistroController> {
  const NomeTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.nomeInput,
      keyboardType: TextInputType.name,
      decoration: InputDecoration(
        hintText: 'Nome Completo',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide(
            color: Colors.white70,
            width: 1.0,
          ),
        ),
        prefixIcon: Icon(Icons.person),
        filled: true,
        fillColor: Colors.white70,
      ),
    );
  }
}