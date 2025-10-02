import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/logarbutton.widget.dart';
import 'widgets/logintextfield.widget.dart';
import 'widgets/senhatextfield.dart';
import 'widgets/registrarbutton.widget.dart';
import 'widgets/codigoempresa_textfield.dart';
import 'loginview.controller.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart'; // ← NOVO IMPORT

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(0, 0, 0, 0),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B7280), // Cinza médio no topo
              Color(0xFF4B5563), // Cinza médio-escuro
              Color(0xFF374151), // Cinza escuro
              Color(0xFF1F2937), // Cinza muito escuro
              Color(0xFF111827), // Quase preto
              Color(0xFF0F0F0F), // Preto profundo
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'SeeNet',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00FF99),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return Center(
      child: ListView(
        padding: const EdgeInsets.all(40),
        children: [
          const LoginTextField(),
          const SizedBox(height: 30),
          const SenhaTextField(),
          const SizedBox(height: 30),
          const CodigoEmpresaTextField(),
          const SizedBox(height: 60),
          const LogarButton(),
          const SizedBox(height: 30),
          const Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white,
                  thickness: 1,
                  endIndent: 10,
                ),
              ),
              Text(
                'ou',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white,
                  thickness: 1,
                  indent: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ainda não tem uma conta?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 5),
              RegistrarButton(),
            ],
          ),

          // ========== TESTES DE API (TEMPORÁRIOS) ==========
          const SizedBox(height: 40),
          _buildTestSection(), // ← SEÇÃO DE TESTES ATUALIZADA
        ],
      ),
    );
  }

  // ========== SEÇÃO DE TESTES ==========
  Widget _buildTestSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00FF99).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Text(
            '🧪 Testes de API',
            style: TextStyle(
              color: Color(0xFF00FF99),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Botão 1: Teste de conectividade
          _buildTestButton(
            'Testar Backend',
            Icons.wifi_protected_setup,
            controller.testarBackend,
          ),

          const SizedBox(height: 12),

          // Botão 2: Login Demo Admin (preenche campos + faz login)
          _buildTestButton(
            'Login Demo (Admin)',
            Icons.admin_panel_settings,
            controller.testarLoginAdmin,
          ),

          const SizedBox(height: 12),

          // Botão 3: Login Demo Técnico (preenche campos + faz login)
          _buildTestButton(
            'Login Demo (Técnico)',
            Icons.engineering,
            controller.testarLoginTecnico,
          ),

          const SizedBox(height: 12),

          // Botão 4: Verificar empresas
          _buildTestButton(
            'Verificar Empresas',
            Icons.business,
            controller.testarEmpresas,
          ),

          const SizedBox(height: 12),

          // Botão 5: Limpar campos
          _buildTestButton(
            'Limpar Campos',
            Icons.clear_all,
            controller.limparCampos,
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String title, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: Obx(() {
        return ElevatedButton.icon(
          onPressed: controller.isLoading.value ? null : onPressed,
          icon: controller.isLoading.value
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Icon(icon, size: 18),
          label: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.isLoading.value
                ? const Color(0xFF4B5563).withOpacity(0.5)
                : const Color(0xFF4B5563),
            foregroundColor: Colors.white,
            elevation: controller.isLoading.value ? 0 : 2,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: const Color(0xFF00FF99).withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ========== TESTE DE CONECTIVIDADE ==========
  void _testBackend() async {
    try {
      _showLoading();

      final apiService = Get.find<ApiService>();
      bool conectado = await apiService.checkConnectivity();

      Get.back(); // Fechar loading

      _showSnackbar(
        conectado ? 'Backend Online' : 'Backend Offline',
        conectado
            ? '✅ Servidor conectado via hotspot!'
            : '❌ Não foi possível conectar ao servidor',
        conectado,
      );

    } catch (e) {
      _closeLoadingIfOpen();
      _showSnackbar('Erro no Teste', '❌ Erro: $e', false);
    }
  }

  // ========== TESTE DE LOGIN ADMIN ==========
  void _testLoginAdmin() async {
    try {
      _showLoading();

      final authService = Get.find<AuthService>();
      bool success = await authService.login(
          'admin@seenet.com',
          'admin123',
          'DEMO2024'
      );

      Get.back(); // Fechar loading

      _showSnackbar(
        success ? '✅ Login Admin OK' : '❌ Login Admin Falhou',
        success
            ? 'Logado como admin@seenet.com!\nEmpresa:SeeNet'
            : 'Erro ao fazer login com credenciais do admin',
        success,
      );

      if (success) {
        print('🎉 Login admin bem-sucedido!');
        // Aqui você pode navegar para a tela principal se quiser
        // Get.offAllNamed('/home');
      }

    } catch (e) {
      _closeLoadingIfOpen();
      _showSnackbar('Erro no Login Admin', '❌ Erro: $e', false);
    }
  }

  // ========== TESTE DE LOGIN TÉCNICO ==========
  void _testLoginTecnico() async {
    try {
      _showLoading();

      final authService = Get.find<AuthService>();
      bool success = await authService.login(
          'tecnico@seenet.com',
          '123456',
          'DEMO2024'
      );

      Get.back(); // Fechar loading

      _showSnackbar(
        success ? '✅ Login Técnico OK' : '❌ Login Técnico Falhou',
        success
            ? 'Logado como tecnico@demo.seenet.com!\nEmpresa: SeeNet Demo'
            : 'Erro ao fazer login com credenciais do técnico',
        success,
      );

      if (success) {
        print('🎉 Login técnico bem-sucedido!');
      }

    } catch (e) {
      _closeLoadingIfOpen();
      _showSnackbar('Erro no Login Técnico', '❌ Erro: $e', false);
    }
  }

  // ========== TESTE DE VERIFICAÇÃO DE EMPRESAS ==========
  void _testCompanies() async {
    try {
      _showLoading();

      final authService = Get.find<AuthService>();

      var demo = await authService.verificarCodigoEmpresa('DEMO2024');
      var tech = await authService.verificarCodigoEmpresa('TECH2024');
      var invalid = await authService.verificarCodigoEmpresa('INVALID');

      Get.back(); // Fechar loading

      String message = '';
      if (demo != null) {
        message += '✅ DEMO2024: ${demo['nome']}\n';
      }
      if (tech != null) {
        message += '✅ TECH2024: ${tech['nome']}\n';
      }
      message += '❌ INVALID: Não encontrada';

      _showSnackbar(
        '🏢 Verificação de Empresas',
        message,
        demo != null || tech != null,
      );

      // Debug
      print('📊 DEMO2024: $demo');
      print('📊 TECH2024: $tech');
      print('📊 INVALID: $invalid');

    } catch (e) {
      _closeLoadingIfOpen();
      _showSnackbar('Erro na Verificação', '❌ Erro: $e', false);
    }
  }

  // ========== MÉTODOS AUXILIARES ==========
  void _showLoading() {
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF99)),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _closeLoadingIfOpen() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  void _showSnackbar(String title, String message, bool isSuccess) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isSuccess
          ? const Color(0xFF00FF99)
          : Colors.red,
      colorText: isSuccess
          ? Colors.black
          : Colors.white,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(20),
      borderRadius: 12,
      icon: Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        color: isSuccess ? Colors.black : Colors.white,
      ),
    );
  }
}