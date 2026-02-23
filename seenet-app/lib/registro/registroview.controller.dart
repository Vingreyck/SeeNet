// lib/registro/registroview.controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';
import '../utils/error_handler.dart';
import '../services/auth_service.dart';

class RegistroController extends GetxController {
  // ========== TEXT CONTROLLERS ==========
  TextEditingController nomeInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  TextEditingController confirmarSenhaInput = TextEditingController(); // ← NOVO
  TextEditingController tokenEmpresaController = TextEditingController();

  // ========== OBSERVÁVEIS ==========
  RxBool isLoading = false.obs;
  RxString nome = ''.obs;
  RxString senha = ''.obs;
  RxString confirmarSenha = ''.obs; // ← NOVO
  RxString tokenEmpresa = ''.obs;
  RxBool tokenValido = false.obs;
  RxBool verificandoToken = false.obs;
  RxBool registroSucesso = false.obs;
  Rx<Map<String, dynamic>?> empresaInfo = Rx<Map<String, dynamic>?>(null);

  // ========== DEPENDÊNCIAS ==========
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final AuthService authService = Get.find<AuthService>();

  @override
  void onInit() {
    super.onInit();

    nomeInput.addListener(() {
      nome.value = nomeInput.text;
    });

    senhaInput.addListener(() {
      senha.value = senhaInput.text;
    });

    confirmarSenhaInput.addListener(() { // ← NOVO
      confirmarSenha.value = confirmarSenhaInput.text;
    });

    tokenEmpresaController.addListener(() {
      String codigo = tokenEmpresaController.text.toUpperCase();
      if (codigo != tokenEmpresa.value) {
        tokenEmpresa.value = codigo;
        if (codigo.length >= 4) {
          verificarCodigo(codigo);
        } else {
          empresaInfo.value = null;
          tokenValido.value = false;
        }
      }
    });
  }

  // ========== VERIFICAR CÓDIGO DA EMPRESA ==========
  Future<void> verificarCodigo(String codigo) async {
    if (codigo.length < 4) {
      empresaInfo.value = null;
      tokenValido.value = false;
      return;
    }

    try {
      verificandoToken.value = true;

      final empresa = await authService.verificarCodigoEmpresa(codigo);

      if (empresa != null) {
        empresaInfo.value = empresa;
        tokenValido.value = true;

        _showInfo(
          '🏢 Empresa Encontrada',
          '${empresa['nome']}\nPlano: ${empresa['plano']}\n\nVocê será cadastrado nesta empresa.',
        );
      } else {
        empresaInfo.value = null;
        tokenValido.value = false;
      }
    } catch (e) {
      empresaInfo.value = null;
      tokenValido.value = false;
    } finally {
      verificandoToken.value = false;
    }
  }

  // ========== REGISTRO COM AUTO-LOGIN ==========
  Future<void> tryToRegister() async {
    if (!_validarCampos()) return;

    try {
      isLoading.value = true;

      bool sucesso = await usuarioController.registrarComAutoLogin(
        nomeInput.text.trim(),
        senhaInput.text,
        tokenEmpresaController.text.trim().toUpperCase(),
      );

      if (sucesso) {
        registroSucesso.value = true;
        limparCampos();

        await Future.delayed(const Duration(milliseconds: 150));
        Get.offAllNamed('/checklist');

        Future.delayed(const Duration(milliseconds: 400), () {
          if (Get.context != null) {
            Get.snackbar(
              '🎉 Bem-vindo!',
              'Conta criada e login realizado com sucesso',
              snackPosition: SnackPosition.TOP,
              backgroundColor: const Color(0xFF00FF99),
              colorText: Colors.black,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(16),
              borderRadius: 12,
              icon: const Icon(Icons.check_circle, color: Colors.black),
            );
          }
        });
      } else {
        _showError('Não foi possível criar a conta. Tente novamente.');
      }
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 100));
      _showError('Erro ao conectar com servidor: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== VALIDAÇÕES ==========
  bool _validarCampos() {
    if (nomeInput.text.trim().length < 2) {
      _showError('Nome deve ter pelo menos 2 caracteres');
      return false;
    }

    if (senhaInput.text.length < 6) {
      _showError('Senha deve ter pelo menos 6 caracteres');
      return false;
    }

    // ← VALIDAÇÃO DAS SENHAS
    if (confirmarSenhaInput.text.isEmpty) {
      _showError('Confirme sua senha');
      return false;
    }

    if (senhaInput.text != confirmarSenhaInput.text) {
      _showError('As senhas não coincidem');
      return false;
    }

    if (tokenEmpresaController.text.trim().isEmpty) {
      _showError('Código da empresa é obrigatório');
      return false;
    }

    if (!tokenValido.value) {
      _showError('Código da empresa inválido ou não verificado');
      return false;
    }

    return true;
  }

  bool get podeRegistrar {
    return nome.value.trim().length >= 2 &&
        senha.value.length >= 6 &&
        confirmarSenha.value.isNotEmpty && // ← NOVO
        senha.value == confirmarSenha.value && // ← NOVO
        tokenEmpresa.value.length >= 4 &&
        tokenValido.value &&
        !isLoading.value;
  }

  // ========== MÉTODOS AUXILIARES ==========
  void limparCampos() {
    nomeInput.clear();
    senhaInput.clear();
    confirmarSenhaInput.clear(); // ← NOVO
    tokenEmpresaController.clear();

    nome.value = '';
    senha.value = '';
    confirmarSenha.value = ''; // ← NOVO
    tokenEmpresa.value = '';
    empresaInfo.value = null;
    tokenValido.value = false;
    registroSucesso.value = false;
  }

  void irParaLogin() => Get.offAllNamed('/login');
  void login() => Get.offAllNamed('/login');
  void criarNovaConta() {
    registroSucesso.value = false;
    limparCampos();
  }

  void _showError(String message) => ErrorHandler.handleValidationError(message);
  void _showSuccess(String message) => ErrorHandler.showSuccess(message);
  void _showInfo(String title, String message) =>
      ErrorHandler.showInfo(message, title: title);

  @override
  void onClose() {
    nomeInput.dispose();
    senhaInput.dispose();
    confirmarSenhaInput.dispose(); // ← NOVO
    tokenEmpresaController.dispose();
    super.onClose();
  }
}