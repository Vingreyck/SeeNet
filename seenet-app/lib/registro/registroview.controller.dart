// lib/registro/registroview.controller.dart - VERSÃO HARDCORE FINAL
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ADICIONAR ESTE IMPORT
import '../controllers/usuario_controller.dart';
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

  // ========== REGISTRO VIA API ========== (✅ SOLUÇÃO COM WORKAROUND)
  Future<void> tryToRegister() async {
    // Validações
    if (!_validarCampos()) return;

    try {
      isLoading.value = true;
      
      // Registro via UsuarioController (que usa AuthService internamente)
      bool sucesso = await usuarioController.registrar(
        nomeInput.text.trim(),
        emailInput.text.trim(),
        senhaInput.text,
        tokenEmpresaController.text.trim().toUpperCase(),
      );
      
      if (sucesso) {
        registroSucesso.value = true;
        
        // ✅ WORKAROUND: Mostrar dialog customizado em vez de navegar
        await _mostrarDialogSucesso();
      }
      
    } catch (e) {
      print('❌ Erro no registro: $e');
      _showError('Erro ao conectar com servidor');
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ HARDCORE: Dialog que pede para fechar o app
  Future<void> _mostrarDialogSucesso() async {
    await Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // Impedir fechar com back
        child: AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF00FF99), width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00FF99), size: 40),
              SizedBox(width: 12),
              Text(
                '🎉 Conta Criada!',
                style: TextStyle(
                  color: Color(0xFF00FF99),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seu cadastro foi concluído com sucesso!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Color(0xFF00FF99), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Empresa: ${empresaInfo.value?['nome'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // ✅ INSTRUÇÃO PARA FECHAR O APP
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Para fazer login:',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Feche este aplicativo completamente\n'
                      '2. Abra o app novamente\n'
                      '3. Faça login com suas credenciais',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // ✅ FECHAR O APP
                  Get.back(); // Fechar dialog primeiro
                  
                  // Mostrar snackbar final
                  Get.snackbar(
                    '✅ Tudo Certo!',
                    'Feche o app e abra novamente para fazer login',
                    backgroundColor: const Color(0xFF00FF99),
                    colorText: Colors.black,
                    duration: const Duration(seconds: 8),
                    margin: const EdgeInsets.all(20),
                    borderRadius: 12,
                    icon: const Icon(Icons.info, color: Colors.black),
                    isDismissible: false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF99),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ENTENDI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
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

  @override
  void onClose() {
    nomeInput.dispose();
    emailInput.dispose();
    senhaInput.dispose();
    tokenEmpresaController.dispose();
    super.onClose();
  }
}