// lib/modules/login/widgets/logarbutton.widget.dart - ATUALIZADO
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../loginview.controller.dart';

class LogarButton extends GetView<LoginController> {
  const LogarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: controller.podeLogar ? controller.tryToLogin : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.podeLogar 
                ? const Color(0xFF00FF99) 
                : Colors.grey.withOpacity(0.5),
            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            foregroundColor: controller.podeLogar 
                ? Colors.black 
                : Colors.grey,
            elevation: controller.podeLogar ? 4 : 0,
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
                      controller.empresaValida.value 
                          ? Icons.login 
                          : Icons.lock,
                      size: 20,
                      color: controller.podeLogar ? Colors.black : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getButtonText(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: controller.podeLogar ? Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  String _getButtonText() {
    if (controller.email.isEmpty || controller.senha.isEmpty) {
      return 'Preencha os campos';
    }
    
    if (controller.codigoEmpresa.isEmpty) {
      return 'Digite código da empresa';
    }
    
    if (controller.verificandoEmpresa.value) {
      return 'Verificando empresa...';
    }
    
    if (!controller.empresaValida.value) {
      return 'Empresa inválida';
    }
    
    return 'ENTRAR';
  }
}