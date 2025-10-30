// lib/registro/registroview.controller.dart - VERSÃO COM AUTO-LOGIN
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/usuario_controller.dart';
import '../utils/error_handler.dart';
import '../services/auth_service.dart';

class RegistroController extends GetxController {
  // ========== TEXT CONTROLLERS ==========
  TextEditingController nomeInput = TextEditingController();
  TextEditingController emailInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  TextEditingController tokenEmpresaController = TextEditingController();
  
  // ========== OBSERVÁVEIS ==========
  RxBool isLoading = false.obs;
  RxString nome = ''.obs;
  RxString email = ''.obs;
  RxString senha = ''.obs;
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
    
    // Listeners para sincronizar os campos
    nomeInput.addListener(() {
      nome.value = nomeInput.text;
    });
    
    emailInput.addListener(() {
      email.value = emailInput.text;
    });
    
    senhaInput.addListener(() {
      senha.value = senhaInput.text;
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
        print('✅ Código válido: ${empresa['nome']}');
        
        _showInfo(
          '🏢 Empresa Encontrada',
          '${empresa['nome']}\nPlano: ${empresa['plano']}\n\nVocê será cadastrado nesta empresa.',
        );
      } else {
        empresaInfo.value = null;
        tokenValido.value = false;
        print('❌ Código inválido: $codigo');
      }
    } catch (e) {
      empresaInfo.value = null;
      tokenValido.value = false;
      print('❌ Erro ao verificar código: $e');
    } finally {
      verificandoToken.value = false;
    }
  }

  // ========== REGISTRO COM AUTO-LOGIN ==========
  Future<void> tryToRegister() async {
    // Validações
    if (!_validarCampos()) return;

    try {
      isLoading.value = true;
      
      print('📝 Iniciando registro + auto-login');
      print('   Email: ${emailInput.text.trim()}');
      print('   Empresa: ${tokenEmpresaController.text.trim()}');
      
      // Usar o método registrarComAutoLogin do UsuarioController
      bool sucesso = await usuarioController.registrarComAutoLogin(
        nomeInput.text.trim(),
        emailInput.text.trim(),
        senhaInput.text,
        tokenEmpresaController.text.trim().toUpperCase(),
      );
      
      if (sucesso) {
        print('✅ Registro + Auto-login bem-sucedido');
        registroSucesso.value = true;
        limparCampos();
        
        // Aguardar frame antes de navegar
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Navegar para checklist
        Get.offAllNamed('/checklist');
        
        // Mostrar snackbar de boas-vindas DEPOIS da navegação
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
        print('❌ Registro ou auto-login falhou');
        _showError('Não foi possível criar a conta. Tente novamente.');
      }
      
    } catch (e, stackTrace) {
      print('❌ Erro no registro: $e');
      print('Stack trace: $stackTrace');
      
      // Aguardar antes de mostrar erro
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

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailInput.text.trim())) {
      _showError('Email inválido');
      return false;
    }

    if (senhaInput.text.length < 6) {
      _showError('Senha deve ter pelo menos 6 caracteres');
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
           email.value.trim().isNotEmpty &&
           senha.value.length >= 6 &&
           tokenEmpresa.value.length >= 4 &&
           tokenValido.value &&
           !isLoading.value;
  }

  // ========== MÉTODOS AUXILIARES ==========
  
  void limparCampos() {
    nomeInput.clear();
    emailInput.clear();
    senhaInput.clear();
    tokenEmpresaController.clear();
    
    nome.value = '';
    email.value = '';
    senha.value = '';
    tokenEmpresa.value = '';
    empresaInfo.value = null;
    tokenValido.value = false;
    registroSucesso.value = false;
  }

  void irParaLogin() {
    Get.offAllNamed('/login');
  }

  void login() {
    Get.offAllNamed('/login');
  }

  void criarNovaConta() {
    registroSucesso.value = false;
    limparCampos();
  }

  // ========== TESTES ==========
  
  void preencherTeste() {
    nomeInput.text = 'Técnico Teste';
    emailInput.text = 'teste@empresa.com';
    senhaInput.text = '123456';
    tokenEmpresaController.text = 'DEMO2024';
    
    nome.value = 'Técnico Teste';
    email.value = 'teste@empresa.com';
    senha.value = '123456';
    tokenEmpresa.value = 'DEMO2024';
    
    verificarCodigo('DEMO2024');
  }

  // ========== SNACKBARS ==========
  
  void _showError(String message) {
  ErrorHandler.handleValidationError(message);
}

  void _showSuccess(String message) {
  ErrorHandler.showSuccess(message);
}

  void _showInfo(String title, String message) {
  ErrorHandler.showInfo(message, title: title);
}

  @override
  void onClose() {
    nomeInput.dispose();
    emailInput.dispose();
    senhaInput.dispose();
    tokenEmpresaController.dispose();
    super.onClose();
  }
}