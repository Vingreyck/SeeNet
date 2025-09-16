// lib/registro/registroview.controller.dart - VERSÃO FINAL CORRIGIDA
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';
import '../services/auth_service.dart';

class RegistroController extends GetxController {
  TextEditingController nomeInput = TextEditingController();
  TextEditingController emailInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  TextEditingController tokenEmpresaController = TextEditingController();
  
  RxBool isLoading = false.obs;
  RxString tokenEmpresa = ''.obs;
  RxBool tokenValido = false.obs;
  RxBool verificandoToken = false.obs;
  RxBool registroSucesso = false.obs;
  Rx<Map<String, dynamic>?> empresaInfo = Rx<Map<String, dynamic>?>(null);
  RxString nome = ''.obs;
  RxString email = ''.obs;
  RxString senha = ''.obs;
  
  // Instâncias dos serviços
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  late AuthService authService;

  @override
  void onInit() {
    super.onInit();
    
    try {
      authService = Get.find<AuthService>();
    } catch (e) {
      print('⚠️ AuthService não encontrado, usando fallback');
    }

      // Listeners com debug
  nomeInput.addListener(() {
    print('🔍 Nome mudou: "${nomeInput.text}" (${nomeInput.text.trim().length} chars)');
  });
  
  emailInput.addListener(() {
    print('🔍 Email mudou: "${emailInput.text}"');
  });
  
  senhaInput.addListener(() {
    print('🔍 Senha mudou: ${senhaInput.text.length} chars');
  });
  
  tokenEmpresaController.addListener(() {
    String newValue = tokenEmpresaController.text.toUpperCase();
    print('🔍 Token mudou: "$newValue"');
    if (tokenEmpresa.value != newValue) {
      tokenEmpresa.value = newValue;
      
      if (newValue.length >= 4) {
        verificarToken(newValue);
      } else {
        empresaInfo.value = null;
        tokenValido.value = false;
      }
    }
  });
    
    // Listeners que atualizam observables
    nomeInput.addListener(() {
      nome.value = nomeInput.text;
      print('🔍 Nome mudou: "${nomeInput.text}" (${nomeInput.text.trim().length} chars)');
    });
    
    emailInput.addListener(() {
      email.value = emailInput.text;
      print('🔍 Email mudou: "${emailInput.text}"');
    });
    
    senhaInput.addListener(() {
      senha.value = senhaInput.text;
      print('🔍 Senha mudou: ${senhaInput.text.length} chars');
    });
  }

  // Método para verificar token da empresa
  Future<void> verificarToken(String token) async {
    if (token.length < 4) {
      empresaInfo.value = null;
      tokenValido.value = false;
      return;
    }

    try {
      verificandoToken.value = true;
      
      final empresa = await authService.verificarCodigoEmpresa(token);
      
      if (empresa != null) {
        empresaInfo.value = empresa;
        tokenValido.value = true;
        print('✅ Token válido: ${empresa['nome']}');
      } else {
        empresaInfo.value = null;
        tokenValido.value = false;
        print('❌ Token inválido: $token');
      }
    } catch (e) {
      empresaInfo.value = null;
      tokenValido.value = false;
      print('❌ Erro ao verificar token: $e');
    } finally {
      verificandoToken.value = false;
    }
  }

  // Método de registro
  Future<void> tryToRegister() async {
    // Validações básicas
    if (!_validarCampos()) return;

    try {
      isLoading.value = true;
      
      // Tentar registro via API se disponível
      bool sucesso = await authService.register(
        nomeInput.text.trim(),
        emailInput.text.trim(),
        senhaInput.text,
        tokenEmpresaController.text.trim().toUpperCase(),
      );
      
      if (sucesso) {
      _showSuccess('Conta criada com sucesso!\n\nAgora você pode fazer login com suas credenciais.');
        // Aguardar um pouco para mostrar a mensagem, depois redirecionar
      Future.delayed(const Duration(seconds: 2), () {
        Get.offAllNamed('/login');
      });
    }
          
    } catch (e) {
      _showError('Erro ao conectar com servidor');
      print('❌ Erro no registro: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Validar campos
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
      _showError('Token da empresa é obrigatório');
      return false;
    }

    if (!tokenValido.value) {
      _showError('Token da empresa inválido');
      return false;
    }

    return true;
  }

  // Registro local (fallback)
  Future<void> _registroLocal() async {
    bool sucesso = await usuarioController.registrar(
      nomeInput.text.trim(),
      emailInput.text.trim(),
      senhaInput.text
    );

    if (sucesso) {
      registroSucesso.value = true;
      _showSuccess('✅ Conta criada com sucesso!\n\nAgora você pode fazer login com suas credenciais.');
    } else {
      _showError('Erro ao registrar usuário. Email pode já estar em uso.');
    }
  }

  // Limpar campos
  void _limparCampos() {
    nomeInput.clear();
    emailInput.clear();
    senhaInput.clear();
    tokenEmpresaController.clear();
    
    tokenEmpresa.value = '';
    tokenValido.value = false;
    empresaInfo.value = null;
  }

  // Getter reativo
  bool get podeRegistrar {
    return nome.value.trim().isNotEmpty &&
          email.value.trim().isNotEmpty &&
          senha.value.length >= 6 &&
          tokenEmpresa.isNotEmpty &&
          tokenValido.value &&
          !isLoading.value;
  }
  

  void login() {
    Get.toNamed('/login');
  }

  // Métodos auxiliares para snackbars
  void _showError(String message) {
    Get.snackbar(
      'Erro',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(20),
      borderRadius: 12,
      icon: const Icon(Icons.error, color: Colors.white),
    );
  }

  void irParaLogin() {
    Get.offAllNamed('/login');
  }

  void criarNovaConta() {
    registroSucesso.value = false;
    _limparCampos();
}
  void _showSuccess(String message) {
    Get.snackbar(
      'Sucesso',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF00FF99),
      colorText: Colors.black,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(20),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle, color: Colors.black),
    );
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