// lib/registro/widgets/logarbutton.widget.dart - VERSÃO ATUALIZADA COM TOKEN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/registro/registroview.controller.dart';

class LogarButton extends GetView<RegistroController> {
  const LogarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: controller.podeRegistrar ? controller.tryToRegister : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.podeRegistrar
                ? const Color(0xFF00FF99)
                : Colors.grey.withOpacity(0.5),
            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            foregroundColor: controller.podeRegistrar
                ? Colors.black
                : Colors.grey,
            elevation: controller.podeRegistrar ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: controller.isLoading.value
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getButtonIcon(),
                size: 20,
                color: controller.podeRegistrar ? Colors.black : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                _getButtonText(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: controller.podeRegistrar ? Colors.black : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _getButtonText() {
    if (controller.nomeInput.text.trim().isEmpty) {
      return 'Digite seu nome';
    }

    if (controller.emailInput.text.trim().isEmpty) {
      return 'Digite seu email';
    }

    if (controller.senhaInput.text.isEmpty) {
      return 'Digite sua senha';
    }

    if (controller.senhaInput.text.length < 6) {
      return 'Senha muito curta';
    }

    if (controller.tokenEmpresa.isEmpty) {
      return 'Digite o token da empresa';
    }

    if (controller.verificandoToken.value) {
      return 'Verificando token...';
    }

    if (!controller.tokenValido.value) {
      return 'Token inválido';
    }

    return 'CRIAR CONTA';
  }

  IconData _getButtonIcon() {
    if (controller.nomeInput.text.trim().isEmpty ||
        controller.emailInput.text.trim().isEmpty ||
        controller.senhaInput.text.isEmpty ||
        controller.senhaInput.text.length < 6) {
      return Icons.edit;
    }

    if (controller.tokenEmpresa.isEmpty) {
      return Icons.vpn_key;
    }

    if (controller.verificandoToken.value) {
      return Icons.hourglass_empty;
    }

    if (!controller.tokenValido.value) {
      return Icons.error;
    }

    return Icons.person_add;
  }
}