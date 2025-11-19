import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/usuario_controller.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class LoginController extends GetxController {
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

  // ✅ VARIÁVEIS DE ERRO PARA OS CAMPOS
  RxString emailError = ''.obs;
  RxString senhaError = ''.obs;
  RxString empresaError = ''.obs;
  
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final AuthService authService = Get.find<AuthService>();
  final ApiService apiService = Get.find<ApiService>();

  @override
  void onInit() {
    super.onInit();
    
    loginInput = TextEditingController();
    senhaInput = TextEditingController();
    codigoEmpresaController = TextEditingController();
    codigoEmpresaFocusNode = FocusNode();
    
    loginInput.addListener(() => email.value = loginInput.text);
    senhaInput.addListener(() => senha.value = senhaInput.text);
    
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
      } else {
        empresaInfo.value = null;
        empresaValida.value = false;
      }
    } catch (e) {
      empresaInfo.value = null;
      empresaValida.value = false;
    } finally {
      verificandoEmpresa.value = false;
    }
  }

  Future<void> tryToLogin() async {
    // ✅ LIMPAR ERROS ANTERIORES
    emailError.value = '';
    senhaError.value = '';
    empresaError.value = '';
    
    // ✅ VALIDAÇÕES LOCAIS
    bool hasError = false;
    
    if (loginInput.text.trim().isEmpty) {
      emailError.value = 'Email é obrigatório';
      hasError = true;
    } else if (!_isValidEmail(loginInput.text.trim())) {
      emailError.value = 'Email inválido';
      hasError = true;
    }

    if (senhaInput.text.isEmpty) {
      senhaError.value = 'Senha é obrigatória';
      hasError = true;
    }

    if (codigoEmpresaController.text.trim().isEmpty) {
      empresaError.value = 'Código é obrigatório';
      hasError = true;
    } else if (!empresaValida.value) {
      empresaError.value = 'Código inválido';
      hasError = true;
    }
    
    if (hasError) return;

    try {
      isLoading.value = true;
      
      bool loginSucesso = await usuarioController.login(
        loginInput.text.trim(),
        senhaInput.text,
        codigoEmpresaController.text.trim().toUpperCase(),
      );

      if (loginSucesso) {
        Get.offAllNamed('/checklist');
      }
      // ✅ Erros de login já são setados pelo AuthService nos campos
      
    } catch (e) {
      emailError.value = 'Erro de conexão';
      print('❌ Erro no login: $e');
    } finally {
      isLoading.value = false;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
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
    
    emailError.value = '';
    senhaError.value = '';
    empresaError.value = '';
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

  @override
  void onClose() {
    loginInput.dispose();
    senhaInput.dispose();
    codigoEmpresaController.dispose();
    codigoEmpresaFocusNode.dispose();
    super.onClose();
  }
}