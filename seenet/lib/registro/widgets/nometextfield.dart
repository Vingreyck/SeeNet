import 'package:flutter/material.dart';

class NomeTextField extends StatelessWidget {
  const NomeTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
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