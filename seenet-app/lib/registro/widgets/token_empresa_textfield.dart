import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../registroview.controller.dart';

class TokenEmpresaTextField extends GetView<RegistroController> {
  const TokenEmpresaTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label do campo
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.key,
                  color: Color(0xFF00FF99),
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Token da Empresa',
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
          TextFormField(
            controller: controller.tokenEmpresaController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) {
              controller.tokenEmpresa.value = value.toUpperCase();
              controller.tokenEmpresaController.text = value.toUpperCase();
              controller.tokenEmpresaController.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.tokenEmpresaController.text.length),
              );
              
              // Verificar token automaticamente se tiver 4+ caracteres
              if (value.length >= 4) {
                controller.verificarToken(value.toUpperCase());
              } else {
                controller.empresaInfo.value = null;
                controller.tokenValido.value = false;
              }
            },
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              hintText: 'Ex: DEMO2024, TECH2024',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                letterSpacing: 0.5,
              ),
              prefixIcon: Icon(
                Icons.vpn_key,
                color: controller.tokenValido.value 
                    ? const Color(0xFF00FF99)
                    : Colors.white.withOpacity(0.7),
                size: 24,
              ),
              suffixIcon: _buildSuffixIcon(),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: controller.tokenValido.value
                      ? const Color(0xFF00FF99)
                      : Colors.white.withOpacity(0.3),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red.shade400,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          
          // Dica de ajuda
          if (controller.tokenEmpresa.isEmpty) _buildHelpText(),
        ],
      );
    });
  }

  Widget _buildSuffixIcon() {
    if (controller.verificandoToken.value) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF99)),
          ),
        ),
      );
    }

    if (controller.tokenValido.value && controller.empresaInfo.value != null) {
      return const Icon(
        Icons.verified,
        color: Color(0xFF00FF99),
        size: 24,
      );
    }

    if (controller.tokenEmpresa.value.isNotEmpty && 
        controller.empresaInfo.value == null &&
        !controller.verificandoToken.value) {
      return Icon(
        Icons.error,
        color: Colors.red.shade400,
        size: 24,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHelpText() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: const Color(0xFF00FF99).withOpacity(0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Digite o token fornecido pelo administrador da sua empresa',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}