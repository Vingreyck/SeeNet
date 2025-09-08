import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/registro/registroview.controller.dart';

class SenhaTextField extends GetView<RegistroController> {
  SenhaTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label do campo
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.lock,
                color: Color(0xFF00FF99),
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'Senha',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Campo de texto
        Obx(() => TextFormField(
          controller: controller.senhaInput,
          obscureText: _obscureText.value,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Mínimo 6 caracteres',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText.value ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.7),
                size: 24,
              ),
              onPressed: _toggleVisibility,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00FF99),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        )),
        
        // Indicador de força da senha
        const SizedBox(height: 8),
        _buildPasswordStrength(),
      ],
    );
  }

  // Observable para controlar visibilidade da senha
  final RxBool _obscureText = true.obs;

  void _toggleVisibility() {
    _obscureText.value = !_obscureText.value;
  }

  // Widget para mostrar força da senha
  Widget _buildPasswordStrength() {
    return Obx(() {
      String senha = controller.senhaInput.text;
      if (senha.isEmpty) return const SizedBox.shrink();

      int strength = _calculatePasswordStrength(senha);
      Color strengthColor;
      String strengthText;

      switch (strength) {
        case 0:
          strengthColor = Colors.red;
          strengthText = 'Muito fraca';
          break;
        case 1:
          strengthColor = Colors.orange;
          strengthText = 'Fraca';
          break;
        case 2:
          strengthColor = Colors.yellow;
          strengthText = 'Média';
          break;
        case 3:
          strengthColor = const Color(0xFF4CAF50);
          strengthText = 'Forte';
          break;
        default:
          strengthColor = const Color(0xFF00FF99);
          strengthText = 'Muito forte';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: strengthColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: strengthColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Barra de força
            Expanded(
              child: LinearProgressIndicator(
                value: (strength + 1) / 5,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(width: 12),
            // Texto da força
            Text(
              strengthText,
              style: TextStyle(
                color: strengthColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
  }

  // Calcular força da senha
  int _calculatePasswordStrength(String password) {
    int strength = 0;
    
    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    return strength > 4 ? 4 : strength;
  }
}