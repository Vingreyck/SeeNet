import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart' show ResultadoEmpresa;
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
              // Só ajusta o texto (maiúsculas) — quem dispara a verificação da
              // empresa é o listener do controller (tem debounce + proteção
              // contra resposta de rede fora de ordem). Chamar aqui TAMBÉM
              // duplicava toda verificação, e em rede instável (iPhone/celular)
              // uma resposta atrasada podia travar o botão de entrar pra sempre.
              controller.codigoEmpresaController.text = value.toUpperCase();
              controller.codigoEmpresaController.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.codigoEmpresaController.text.length),
              );
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

          // Empresa NÃO existe (servidor respondeu) → erro vermelho, bloqueia.
          if (!controller.verificandoEmpresa.value &&
              controller.statusEmpresa.value == ResultadoEmpresa.naoEncontrada)
            _buildEmpresaError(),

          // Não deu pra checar (rede) → aviso amarelo, NÃO bloqueia: o login
          // valida a empresa de novo no servidor.
          if (!controller.verificandoEmpresa.value &&
              controller.statusEmpresa.value == ResultadoEmpresa.erroRede)
            _buildEmpresaSemChecagem(),
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

    // Vermelho SÓ quando o servidor confirmou que não existe.
    if (controller.statusEmpresa.value == ResultadoEmpresa.naoEncontrada) {
      return Icon(
        Icons.error,
        color: Colors.red.shade400,
        size: 24,
      );
    }

    // Não deu pra checar (rede): aviso discreto, dá pra entrar mesmo assim.
    if (controller.statusEmpresa.value == ResultadoEmpresa.erroRede) {
      return Icon(
        Icons.cloud_off_rounded,
        color: Colors.amber.shade600,
        size: 22,
      );
    }

  return const SizedBox.shrink();
  }

  /// Aviso (não é erro): não conseguimos confirmar a empresa, mas o técnico
  /// pode tentar entrar — o servidor confere de novo no login.
  Widget _buildEmpresaSemChecagem() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.35), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.amber.shade600, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Não deu pra confirmar a empresa agora (sinal fraco). '
              'Você pode tentar entrar mesmo assim.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
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