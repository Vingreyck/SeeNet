import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/logarbutton.widget.dart';
import 'widgets/logintextfield.widget.dart';
import 'widgets/senhatextfield.dart';
import 'widgets/registrarbutton.widget.dart';
import 'loginview.controller.dart';
import '../services/api_service.dart'; // ← NOVO IMPORT

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
            Expanded(child: _body()), // Usa o método abaixo
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
          const SizedBox(height: 60), // ← ESPAÇAMENTO AUMENTADO (era 50)
          const LogarButton(),
          const SizedBox(height: 30), // ← ESPAÇAMENTO AUMENTADO (era 20)
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
          const SizedBox(height: 30), // ← ESPAÇAMENTO AUMENTADO (era 20)
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
          
          // ========== BOTÃO DE TESTE (TEMPORÁRIO) ==========
          const SizedBox(height: 40),
          _buildTestButton(), // ← NOVO BOTÃO
        ],
      ),
    );
  }

  // ========== BOTÃO DE TESTE BACKEND ==========
  Widget _buildTestButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _testBackend,
        icon: const Icon(Icons.wifi_protected_setup, size: 20),
        label: const Text(
          'Testar Backend',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF374151), // Cinza escuro
          foregroundColor: const Color(0xFF00FF99), // Verde do logo
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: Color(0xFF00FF99), // Borda verde
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  // ========== FUNÇÃO DE TESTE ==========
  void _testBackend() async {
    try {
      // Mostrar loading
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF99)),
          ),
        ),
        barrierDismissible: false,
      );

      // Testar conexão
      final apiService = Get.find<ApiService>();
      bool conectado = await apiService.checkConnectivity();

      // Fechar loading
      Get.back();

      // Mostrar resultado
      Get.snackbar(
        conectado ? 'Backend Online' : 'Backend Offline',
        conectado 
            ? '✅ Servidor conectado em http://localhost:3000'
            : '❌ Não foi possível conectar ao servidor',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: conectado 
            ? const Color(0xFF00FF99) 
            : Colors.red,
        colorText: conectado 
            ? Colors.black 
            : Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        borderRadius: 12,
        icon: Icon(
          conectado ? Icons.check_circle : Icons.error,
          color: conectado ? Colors.black : Colors.white,
        ),
      );

      // Debug adicional
      if (conectado) {
        print('🎉 Teste bem-sucedido!');
        await apiService.debugEndpoints();
      } else {
        print('❌ Falha no teste - verifique se o backend está rodando em http://localhost:3000');
      }

    } catch (e) {
      // Fechar loading se ainda estiver aberto
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print('❌ Erro no teste: $e');
      
      Get.snackbar(
        'Erro no Teste',
        '❌ Erro: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(20),
        borderRadius: 12,
      );
    }
  }
}