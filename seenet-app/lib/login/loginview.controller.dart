// lib/login/loginview.controller.dart - VERSÃO FINAL (API)
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class LoginController extends GetxController {
  TextEditingController loginInput = TextEditingController();
  TextEditingController senhaInput = TextEditingController();
  TextEditingController codigoEmpresaController = TextEditingController();
  FocusNode codigoEmpresaFocusNode = FocusNode();
  
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
        
        // Debug
        print('✅ Usuário logado: ${usuarioController.nomeUsuario}');
        print('🏢 Empresa: ${empresaInfo.value?['nome']}');
        
        // Navegar para checklist
        Get.offAllNamed('/checklist');
      }
      // AuthService já mostra erros
      
    } catch (e) {
      _showError('Erro ao conectar com servidor');
      print('❌ Erro no login: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== MÉTODOS DE TESTE ==========
  
  Future<void> testarBackend() async {
    try {
      isLoading.value = true;
      
      bool conectado = await apiService.checkConnectivity();
      
      if (conectado) {
        _showSuccess('✅ Backend conectado!\n\nAPI respondendo corretamente.');
        await apiService.debugEndpoints();
      } else {
        _showError('❌ Backend offline\n\nVerifique se a API está rodando.');
      }
    } catch (e) {
      _showError('Erro ao testar: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> testarLoginAdmin() async {
    preencherTeste(
      email: 'admin@seenet.com',
      senha: 'admin123',
      codigo: 'DEMO2024',
    );

    await Future.delayed(const Duration(milliseconds: 500));
    
    if (empresaValida.value) {
      await tryToLogin();
    } else {
      _showError('Aguarde verificação da empresa...');
    }
  }

  Future<void> testarLoginTecnico() async {
    preencherTeste(
      email: 'tecnico@seenet.com',
      senha: '123456',
      codigo: 'DEMO2024',
    );

    await Future.delayed(const Duration(milliseconds: 500));
    
    if (empresaValida.value) {
      await tryToLogin();
    } else {
      _showError('Aguarde verificação da empresa...');
    }
  }

  Future<void> testarEmpresas() async {
    try {
      isLoading.value = true;
      
      var demo = await authService.verificarCodigoEmpresa('DEMO2024');
      var tech = await authService.verificarCodigoEmpresa('TECH2024');
      var invalid = await authService.verificarCodigoEmpresa('INVALID');

      String message = '';
      if (demo != null) {
        message += '✅ DEMO2024: ${demo['nome']}\n';
        message += '   Plano: ${demo['plano']}\n\n';
      } else {
        message += '❌ DEMO2024: Não encontrada\n\n';
      }
      
      if (tech != null) {
        message += '✅ TECH2024: ${tech['nome']}\n';
        message += '   Plano: ${tech['plano']}\n\n';
      } else {
        message += '❌ TECH2024: Não encontrada\n\n';
      }
      
      message += '❌ INVALID: Não encontrada (esperado)';

      _showInfo('🏢 Teste de Empresas', message);

      print('📊 Resultados dos testes:');
      print('DEMO2024: $demo');
      print('TECH2024: $tech');
      print('INVALID: $invalid');

    } catch (e) {
      _showError('Erro na verificação: $e');
    } finally {
      isLoading.value = false;
    }
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
    Get.snackbar(
      'Erro',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(20),
      borderRadius: 12,
      icon: const Icon(Icons.error, color: Colors.white),
    );
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Sucesso',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF00FF99),
      colorText: Colors.black,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(20),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle, color: Colors.black),
    );
  }

  void _showInfo(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(20),
      borderRadius: 12,
      icon: const Icon(Icons.info, color: Colors.white),
    );
  }

  @override
  void onClose() {
    loginInput.dispose();
    senhaInput.dispose();
    codigoEmpresaController.dispose();
    codigoEmpresaFocusNode.dispose();
    super.onClose();
  }
}