// lib/login/loginview.controller.dart - VERSÃO CORRIGIDA
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';
import '../config/environment.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';

class LoginController extends GetxController {
  // ✅ CORREÇÃO: Usar late para inicialização lazy
  late TextEditingController loginInput;
  late TextEditingController senhaInput;
  late TextEditingController codigoEmpresaController;
  late FocusNode codigoEmpresaFocusNode;
  
  RxBool isLoading = false.obs;
  RxString email = ''.obs;
  RxString senha = ''.obs;
  RxString codigoEmpresa = ''.obs;
  RxBool empresaValida = false.obs;
  RxBool verificandoEmpresa = false.obs;
  Rx<Map<String, dynamic>?> empresaInfo = Rx<Map<String, dynamic>?>(null);
  
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final AuthService authService = Get.find<AuthService>();
  final ApiService apiService = Get.find<ApiService>();

  @override
  void onInit() {
    super.onInit();
    
    // ✅ CORREÇÃO: Inicializar controllers e focus nodes no onInit
    loginInput = TextEditingController();
    senhaInput = TextEditingController();
    codigoEmpresaController = TextEditingController();
    codigoEmpresaFocusNode = FocusNode();
    
    // Listeners
    loginInput.addListener(() {
      email.value = loginInput.text;
    });
    
    senhaInput.addListener(() {
      senha.value = senhaInput.text;
    });
    
    codigoEmpresaController.addListener(() {
      String codigo = codigoEmpresaController.text.toUpperCase();
      if (codigo != codigoEmpresa.value) {
        codigoEmpresa.value = codigo;
        if (codigo.length >= 4) {
          verificarEmpresa(codigo);
        } else {
          empresaInfo.value = null;
          empresaValida.value = false;
        }
      }
    });
  }

  // ========== VERIFICAR EMPRESA VIA API ==========
  Future<void> verificarEmpresa(String codigo) async {
    if (codigo.length < 4) {
      empresaInfo.value = null;
      empresaValida.value = false;
      return;
    }

    try {
      verificandoEmpresa.value = true;
      
      final empresa = await authService.verificarCodigoEmpresa(codigo);
      
      if (empresa != null) {
        empresaInfo.value = empresa;
        empresaValida.value = true;
        print('✅ Empresa encontrada: ${empresa['nome']}');
        
        _showInfo(
          '🏢 Empresa Encontrada',
          '${empresa['nome']}\nPlano: ${empresa['plano']}',
        );
      } else {
        empresaInfo.value = null;
        empresaValida.value = false;
        print('❌ Empresa não encontrada: $codigo');
      }
    } catch (e) {
      empresaInfo.value = null;
      empresaValida.value = false;
      print('❌ Erro ao verificar empresa: $e');
    } finally {
      verificandoEmpresa.value = false;
    }
  }

  // ========== LOGIN VIA API ==========
  Future<void> tryToLogin() async {
    // Validações
    if (loginInput.text.trim().isEmpty) {
      _showError('Email não pode ser vazio');
      return;
    }

    if (senhaInput.text.isEmpty) {
      _showError('Senha não pode ser vazia');
      return;
    }

    if (codigoEmpresaController.text.trim().isEmpty) {
      _showError('Código da empresa é obrigatório');
      return;
    }

    if (!empresaValida.value) {
      _showError('Código da empresa inválido');
      return;
    }

    try {
      isLoading.value = true;
      
      // Login via AuthService (que usa UsuarioController internamente)
      bool loginSucesso = await usuarioController.login(
        loginInput.text.trim(),
        senhaInput.text,
        codigoEmpresaController.text.trim().toUpperCase(),
      );

      if (loginSucesso) {
        _showSuccess('Login realizado com sucesso!');

        print('✅ Usuário logado: ${usuarioController.nomeUsuario}');
        
        // Navegar para checklist
        Get.offAllNamed('/checklist');
      }
      
    } catch (e) {
      _showError('Erro ao conectar com servidor');
      print('❌ Erro no login: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== MÉTODOS DE TESTE ==========
void testarSnackbar() {
  print('🧪 Testando snackbar...');
  
  Get.snackbar(
    'Teste',
    'Se você está vendo isso, o snackbar funciona!',
    backgroundColor: Colors.green,
    colorText: Colors.white,
    duration: const Duration(seconds: 3),
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(20),
    borderRadius: 12,
  );
  
  print('✅ Snackbar chamado');
}

  // ========== MÉTODOS AUXILIARES ==========
  
  void preencherTeste({
    required String email,
    required String senha,
    required String codigo,
  }) {
    loginInput.text = email;
    senhaInput.text = senha;
    codigoEmpresaController.text = codigo;
    
    this.email.value = email;
    this.senha.value = senha;
    codigoEmpresa.value = codigo;
    
    verificarEmpresa(codigo);
  }

  void limparCampos() {
    loginInput.clear();
    senhaInput.clear();
    codigoEmpresaController.clear();
    
    email.value = '';
    senha.value = '';
    codigoEmpresa.value = '';
    empresaInfo.value = null;
    empresaValida.value = false;
  }

  void registrar() {
    Get.toNamed('/registro');
  }

  bool get podeLogar {
    return email.value.trim().isNotEmpty && 
           senha.value.isNotEmpty && 
           codigoEmpresa.value.isNotEmpty && 
           empresaValida.value &&
           !isLoading.value;
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
    // ✅ CORREÇÃO: Garantir que dispose só seja chamado se inicializados
    loginInput.dispose();
    senhaInput.dispose();
    codigoEmpresaController.dispose();
    codigoEmpresaFocusNode.dispose();
    super.onClose();
  }
}