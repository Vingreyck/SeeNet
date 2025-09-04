// lib/login/loginview.controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';
import '../services/auth_service.dart'; // ← NOVO IMPORT
import 'package:seenet/services/api_service.dart'; // ← NOVO IMPORT

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
  
  // Instância do UsuarioController
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  
  // ← NOVO: Instância do AuthService
  late AuthService authService;

  @override
  void onInit() {
    super.onInit();
    // Inicializar AuthService
    authService = Get.find<AuthService>();
    
    // Listener para o campo de email
    loginInput.addListener(() {
      email.value = loginInput.text;
    });
    
    // Listener para o campo de senha
    senhaInput.addListener(() {
      senha.value = senhaInput.text;
    });
    
    // Listener para o campo de código da empresa
    codigoEmpresaController.addListener(() {
      codigoEmpresa.value = codigoEmpresaController.text.toUpperCase();
    });
  }

  // ← NOVO: Método para verificar empresa
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

  // ← ATUALIZADO: Método de login com multi-tenant
  Future<void> tryToLogin() async {
    // Validações
    if (loginInput.text.isEmpty) {
      _showError('Email não pode ser vazio');
      return;
    }

    if (senhaInput.text.isEmpty) {
      _showError('Senha não pode ser vazia');
      return;
    }

    // ← NOVA VALIDAÇÃO: Código da empresa
    if (codigoEmpresaController.text.isEmpty) {
      _showError('Código da empresa é obrigatório');
      return;
    }

    if (!empresaValida.value) {
      _showError('Código da empresa inválido');
      return;
    }

    try {
      isLoading.value = true;
      
      // ← NOVO: Login via API multi-tenant
      bool loginSucesso = await authService.login(
        loginInput.text.trim(),
        senhaInput.text,
        codigoEmpresaController.text.trim().toUpperCase(),
      );

      if (loginSucesso) {
        _showSuccess('Login realizado com sucesso!');
        
        // Navegar para checklist
        Get.offAllNamed('/checklist');
      }
      // Não precisa do else pois o AuthService já mostra o erro
      
    } catch (e) {
      _showError('Erro ao conectar com servidor');
      print('❌ Erro no login: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ← NOVO: Método de login para testes (mantém o sistema antigo como fallback)
  Future<void> tryToLoginLocal() async {
    // Validações básicas
    if (loginInput.text.isEmpty) {
      _showError('Email não pode ser vazio');
      return;
    }

    if (senhaInput.text.isEmpty) {
      _showError('Senha não pode ser vazia');
      return;
    }

    try {
      isLoading.value = true;
      
      // Login no sistema local (SQLite)
      bool loginSucesso = await usuarioController.login(
        loginInput.text.trim(),
        senhaInput.text
      );

      if (loginSucesso) {
        _showSuccess('Login local realizado com sucesso!');
        Get.offAllNamed('/checklist');
      } else {
        _showError('Email ou senha incorretos');
      }
    } catch (e) {
      _showError('Erro ao conectar com banco local');
      print('❌ Erro no login local: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ← NOVO: Método para preencher campos de teste
  void preencherTeste({
    required String email,
    required String senha,
    required String codigo,
  }) {
    loginInput.text = email;
    senhaInput.text = senha;
    codigoEmpresaController.text = codigo;
    
    // Atualizar observables
    this.email.value = email;
    this.senha.value = senha;
    codigoEmpresa.value = codigo;
    
    // Verificar empresa automaticamente
    verificarEmpresa(codigo);
  }

  // ← NOVO: Limpar todos os campos
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

  // ← NOVOS: Métodos auxiliares para snackbars
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
      duration: const Duration(seconds: 3),
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

  // ← NOVOS: Métodos de teste para os botões
  Future<void> testarBackend() async {
    try {
      isLoading.value = true;
      
      final apiService = Get.find<ApiService>();
      bool conectado = await apiService.checkConnectivity();
      
      if (conectado) {
        _showSuccess('Backend conectado via hotspot!');
        await apiService.debugEndpoints();
      } else {
        _showError('Backend offline - verifique se está rodando');
      }
    } catch (e) {
      _showError('Erro ao testar backend: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> testarLoginAdmin() async {
    // Preencher campos automaticamente
    preencherTeste(
      email: 'admin@demo.seenet.com',
      senha: 'admin123',
      codigo: 'DEMO2024',
    );

    // Aguardar um pouco para verificação da empresa
    await Future.delayed(const Duration(seconds: 1));

    // Fazer login
    await tryToLogin();
  }

  Future<void> testarLoginTecnico() async {
    // Preencher campos automaticamente
    preencherTeste(
      email: 'tecnico@demo.seenet.com',
      senha: '123456',
      codigo: 'DEMO2024',
    );

    // Aguardar um pouco para verificação da empresa
    await Future.delayed(const Duration(seconds: 1));

    // Fazer login
    await tryToLogin();
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
      }
      if (tech != null) {
        message += '✅ TECH2024: ${tech['nome']}\n';
      }
      message += '❌ INVALID: Não encontrada';

      _showInfo('🏢 Verificação de Empresas', message);

      // Debug
      print('📊 DEMO2024: $demo');
      print('📊 TECH2024: $tech');
      print('📊 INVALID: $invalid');

    } catch (e) {
      _showError('Erro na verificação: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ← NOVO: Getter para verificar se pode fazer login
  bool get podeLogar {
    return email.isNotEmpty && 
           senha.isNotEmpty && 
           codigoEmpresa.isNotEmpty && 
           empresaValida.value &&
           !isLoading.value;
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