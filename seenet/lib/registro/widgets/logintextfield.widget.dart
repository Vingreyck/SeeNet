import 'package:flutter/material.dart';

class LoginTextField extends StatelessWidget {
  const LoginTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Usuário ou Email',
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