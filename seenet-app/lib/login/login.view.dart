import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'widgets/logarbutton.widget.dart';
import 'widgets/logintextfield.widget.dart';
import 'widgets/senhatextfield.dart';
import 'widgets/registrarbutton.widget.dart';
import 'widgets/codigoempresa_textfield.dart';
import 'loginview.controller.dart';

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
          
          // ========== TESTES DE API ==========
          const SizedBox(height: 40),
          _buildTestSection(),
          
          // ========== NOVO: TESTE DETALHADO FLUTTER ==========
          const SizedBox(height: 20),
          _buildAdvancedTestSection(),
        ],
      ),
    );
  }

  // ========== SEÇÃO DE TESTES BÁSICOS ==========
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
            '🧪 Testes Rápidos',
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

  // ========== NOVA SEÇÃO: TESTE DETALHADO ==========
  Widget _buildAdvancedTestSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Text(
            '🔬 Teste Detalhado Flutter',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'IP: 10.0.2.167:3000',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          
          // Botão para teste completo
          _buildAdvancedTestButton(),
          
          const SizedBox(height: 16),
          
          // Área de resultados
          _buildTestResults(),
        ],
      ),
    );
  }

  Widget _buildAdvancedTestButton() {
    return Obx(() {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: controller.isLoading.value ? null : _executarTesteCompleto,
          icon: controller.isLoading.value 
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.play_arrow, size: 18),
          label: Text(
            controller.isLoading.value ? 'EXECUTANDO...' : 'EXECUTAR TESTE COMPLETO',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.isLoading.value 
                ? Colors.blue.withOpacity(0.5)
                : Colors.blue,
            foregroundColor: Colors.white,
            elevation: controller.isLoading.value ? 0 : 3,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTestResults() {
    return Obx(() {
      if (controller.testResults.isEmpty) {
        return Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: const Center(
            child: Text(
              'Clique no botão acima para executar os testes',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      
      return Container(
        height: 200,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 Resultados:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  controller.testResults.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
  Future<void> _testeHTTPDireto() async {
  try {
    print('🧪 Teste direto HTTP...');
    
    final response = await http.get(
      Uri.parse('http://10.0.2.167:3000/health'),
      headers: {'Content-Type': 'application/json'},
    );
    
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
    
    if (response.statusCode == 200) {
      Get.snackbar('Sucesso', 'HTTP Direto funcionando!');
    } else {
      Get.snackbar('Erro', 'Status: ${response.statusCode}');
    }
  } catch (e) {
    print('Erro HTTP direto: $e');
    Get.snackbar('Erro', 'Erro: $e');
  }
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

  // ========== MÉTODO DO TESTE COMPLETO ==========
  Future<void> _executarTesteCompleto() async {
    controller.isLoading.value = true;
    controller.testResults.value = '🚀 Iniciando teste completo...\n\n';
    
    const String baseUrl = 'http://10.0.2.167:3000';
    
    try {
      // Teste 1: Health Check
      await _testeHealth(baseUrl);
      
      // Teste 2: Verificar Empresa
      await _testeEmpresa(baseUrl);
      
      // Teste 3: Login
      await _testeLogin(baseUrl);
      
      controller.testResults.value += '\n🎯 TODOS OS TESTES CONCLUÍDOS!';
      
    } catch (e) {
      controller.testResults.value += '\n❌ ERRO GERAL: $e';
    } finally {
      controller.isLoading.value = false;
    }
  }

  Future<void> _testeHealth(String baseUrl) async {
    try {
      controller.testResults.value += '1️⃣ Testando Health Check...\n';
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        controller.testResults.value += '✅ Health Check: OK (${response.statusCode})\n\n';
      } else {
        controller.testResults.value += '❌ Health Check: FALHA (${response.statusCode})\n';
        controller.testResults.value += 'Response: ${response.body}\n\n';
      }
      
    } catch (e) {
      controller.testResults.value += '❌ Health Check: ERRO\n';
      controller.testResults.value += 'Detalhes: $e\n\n';
    }
  }

  Future<void> _testeEmpresa(String baseUrl) async {
    try {
      controller.testResults.value += '2️⃣ Testando verificação de empresa...\n';
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/tenant/verify/DEMO2024'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        controller.testResults.value += '✅ Empresa encontrada: ${data['empresa']['nome']}\n';
        controller.testResults.value += 'Plano: ${data['empresa']['plano']}\n\n';
      } else {
        controller.testResults.value += '❌ Empresa: FALHA (${response.statusCode})\n';
        controller.testResults.value += 'Response: ${response.body}\n\n';
      }
      
    } catch (e) {
      controller.testResults.value += '❌ Empresa: ERRO\n';
      controller.testResults.value += 'Detalhes: $e\n\n';
    }
  }

  Future<void> _testeLogin(String baseUrl) async {
    try {
      controller.testResults.value += '3️⃣ Testando login...\n';
      
      final loginData = {
        'email': 'admin@seenet.com',
        'senha': 'admin123',
        'codigoEmpresa': 'DEMO2024',
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        controller.testResults.value += '✅ LOGIN SUCESSO!\n';
        controller.testResults.value += 'Usuário: ${data['user']['nome']}\n';
        controller.testResults.value += 'Tipo: ${data['user']['tipo_usuario']}\n';
        controller.testResults.value += 'Empresa: ${data['user']['tenant']['nome']}\n';
        controller.testResults.value += 'Token recebido: ${data['token'].substring(0, 30)}...\n\n';
      } else {
        controller.testResults.value += '❌ Login: FALHA (${response.statusCode})\n';
        controller.testResults.value += 'Response: ${response.body}\n\n';
      }
      
    } catch (e) {
      controller.testResults.value += '❌ Login: ERRO\n';
      controller.testResults.value += 'Detalhes: $e\n\n';
    }
  }
}