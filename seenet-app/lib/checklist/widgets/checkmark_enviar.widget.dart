import 'package:flutter/material.dart';

class CheckmarkEnviarWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  
  const CheckmarkEnviarWidget({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF10BC4C),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        minimumSize: const Size(double.infinity, 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
      onPressed: onPressed,
      child: const Text(
        'Enviar',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      ),
    );
  }
}