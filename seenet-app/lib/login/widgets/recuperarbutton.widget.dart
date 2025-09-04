import 'package:flutter/material.dart';

class RecuperarButton extends StatelessWidget {
  const RecuperarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          // ação ao tocar no texto
        },
        child: const Text(
          'Recuperar Senha',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
