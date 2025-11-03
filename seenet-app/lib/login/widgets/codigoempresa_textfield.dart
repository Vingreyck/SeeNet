import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../loginview.controller.dart';

class CodigoEmpresaTextField extends GetView<LoginController> {
  const CodigoEmpresaTextField({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label do campo
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Código da Empresa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Campo de texto
          TextFormField(
            controller: controller.codigoEmpresaController,
            focusNode: controller.codigoEmpresaFocusNode,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              controller.codigoEmpresa.value = value.toUpperCase();
              controller.codigoEmpresaController.text = value.toUpperCase();
              controller.codigoEmpresaController.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.codigoEmpresaController.text.length),
              );
              
              // Verificar empresa automaticamente se tiver 4+ caracteres
              if (value.length >= 4) {
                controller.verificarEmpresa(value.toUpperCase());
              } else {
                controller.empresaInfo.value = null;
                controller.empresaValida.value = false;
              }
            },
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.business,
                color: controller.empresaValida.value 
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
                  color: controller.empresaValida.value
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          
          // Informações da empresa
          if (controller.empresaInfo.value != null) _buildEmpresaInfo(),
          
          // Erro de empresa
          if (controller.codigoEmpresa.value.isNotEmpty && 
              controller.empresaInfo.value == null &&
              !controller.verificandoEmpresa.value) _buildEmpresaError(),
        ],
      );
    });
  }

  Widget _buildSuffixIcon() {
    if (controller.verificandoEmpresa.value) {
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

    if (controller.empresaValida.value) {
      return const Icon(
        Icons.check_circle,
        color: Color(0xFF00FF99),
        size: 24,
      );
    }

    if (controller.codigoEmpresa.value.isNotEmpty) {
      return Icon(
        Icons.error,
        color: Colors.red.shade400,
        size: 24,
      );
    }

  return const SizedBox.shrink();
  }

  Widget _buildEmpresaInfo() {
    final empresa = controller.empresaInfo.value!;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF99).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF00FF99).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF00FF99),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empresa['nome'] ?? 'Nome não disponível',
                  style: const TextStyle(
                    color: Color(0xFF00FF99),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (empresa['plano'] != null)
                  Text(
                    'Plano: ${empresa['plano'].toString().capitalize}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpresaError() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: Colors.red.shade400,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Código da empresa não encontrado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}