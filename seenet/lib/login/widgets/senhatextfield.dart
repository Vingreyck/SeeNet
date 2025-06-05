import 'package:flutter/material.dart';

class SenhaTextField extends StatefulWidget {
  const SenhaTextField({super.key});

  @override
  State<SenhaTextField> createState() => _SenhaTextFieldState();
}

class _SenhaTextFieldState extends State<SenhaTextField> {
  bool _obscureText = true;

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
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