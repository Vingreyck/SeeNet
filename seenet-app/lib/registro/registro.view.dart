// lib/registro/registro.view.dart - VERSÃO SIMPLIFICADA E SEGURA
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/loginbutton.widget.dart';
import 'registroview.controller.dart';

class RegistrarView extends GetView<RegistroController> {
  RegistrarView({super.key}) {
    _obscurePassword = true.obs;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Criar Conta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B7280),
              Color(0xFF4B5563),
              Color(0xFF374151),
              Color(0xFF1F2937),
              Color(0xFF111827),
              Color(0xFF0F0F0F),
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Logo e título
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      width: 60,
                      height: 60,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'SeeNet',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FF99),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Formulário principal
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00FF99).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '📝 Dados do Novo Usuário',
                        style: TextStyle(
                          color: Color(0xFF00FF99),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Campo Nome
                      _buildTextField(
                        controller: controller.nomeInput,
                        label: 'Nome Completo',
                        hint: 'Digite seu nome completo',
                        icon: Icons.person,
                        textCapitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: 20),

                      // Campo Email
                      _buildTextField(
                        controller: controller.emailInput,
                        label: 'Email',
                        hint: 'Digite seu email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 20),

                      // Campo Senha
                      _buildPasswordField(),

                      const SizedBox(height: 20),

                      // Campo Token da Empresa
                      _buildTokenField(),

                      const SizedBox(height: 20),

                      // Status do Token
                      _buildTokenStatus(),

                      const SizedBox(height: 30),

                      // Botão Registrar
                      _buildRegisterButton(),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Link para login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Já tem uma conta?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const LoginButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para campos de texto padrão
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF00FF99), size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization ?? TextCapitalization.none,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              icon,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00FF99),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  // Campo de senha com toggle de visibilidade
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF00FF99), size: 16),
              SizedBox(width: 6),
              Text(
                'Senha',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // ← MOVIDO O Obx PARA CÁ
        Obx(() => TextFormField(
          controller: controller.senhaInput,
          obscureText: _obscurePassword.value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Mínimo 6 caracteres',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword.value ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.7),
                size: 24,
              ),
              onPressed: () => _obscurePassword.toggle(),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00FF99),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        )),
      ],
    );
  }

  // Campo do token da empresa
  Widget _buildTokenField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.key, color: Color(0xFF00FF99), size: 16),
              SizedBox(width: 6),
              Text(
                'Token da Empresa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: controller.tokenEmpresaController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
            hintText: 'Ex: DEMO2024, TECH2024',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              letterSpacing: 0.5,
            ),
            prefixIcon: Icon(
              Icons.vpn_key,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00FF99),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  // Status do token
  Widget _buildTokenStatus() {
    return Obx(() {
      if (controller.verificandoToken.value) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Verificando token...',
                style: TextStyle(color: Colors.blue, fontSize: 14),
              ),
            ],
          ),
        );
      }

      if (controller.tokenValido.value && controller.empresaInfo.value != null) {
        final empresa = controller.empresaInfo.value!;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF99).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF00FF99), size: 20),
              const SizedBox(width: 12),
              Text(
                'Token válido: ${empresa['nome']}',
                style: const TextStyle(
                  color: Color(0xFF00FF99),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }

      if (controller.tokenEmpresa.isNotEmpty && !controller.tokenValido.value) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text(
                'Token inválido',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return const SizedBox.shrink();
    });
  }

  // Botão de registro
  Widget _buildRegisterButton() {
    return Obx(() {
      bool podeRegistrar= controller.nomeInput.text.trim().isNotEmpty &&
          controller.emailInput.text.trim().isNotEmpty &&
          controller.senhaInput.text.length >= 6 &&
          controller.tokenEmpresaController.text.trim().isNotEmpty &&
          controller.tokenValido.value &&
          !controller.isLoading.value;

      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: podeRegistrar ? controller.tryToRegister : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: controller.podeRegistrar
                ? const Color(0xFF00FF99)
                : const Color(0xFF4B5563), // ← MAIS VISÍVEL

            foregroundColor: controller.podeRegistrar
                ? Colors.black
                : Colors.white70, // ← MAIS VISÍVEL
            elevation: podeRegistrar ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: controller.isLoading.value
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                podeRegistrar ? Icons.person_add : Icons.lock,
                size: 20,
                color: podeRegistrar ? Colors.black : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                _getButtonText(podeRegistrar),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: podeRegistrar ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _getButtonText(bool canRegister) {
    if (controller.nomeInput.text.trim().isEmpty) return 'Digite seu nome';
    if (controller.emailInput.text.trim().isEmpty) return 'Digite seu email';
    if (controller.senhaInput.text.length < 6) return 'Senha muito curta';
    if (controller.tokenEmpresaController.text.trim().isEmpty) return 'Digite o token';
    if (!controller.tokenValido.value) return 'Token inválido';
    return 'CRIAR CONTA';
  }

  // Observable para controlar visibilidade da senha
  late final RxBool _obscurePassword;

  // ← NOVA: Seção de sucesso após registro
  Widget _buildSuccessSection() {
    return Column(
      children: [
        // Ícone de sucesso
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF00FF99).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00FF99),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF00FF99),
            size: 40,
          ),
        ),

        const SizedBox(height: 20),

        // Título de sucesso
        const Text(
          '🎉 Conta Criada!',
          style: TextStyle(
            color: Color(0xFF00FF99),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        // Informações da empresa
        Obx(() {
          final empresa = controller.empresaInfo.value;
          if (empresa != null) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00FF99).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.business,
                        color: Color(0xFF00FF99),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        empresa['nome'] ?? 'Empresa',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sua conta foi criada com sucesso!\nAgora você pode fazer login.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),

        const SizedBox(height: 24),

        // Botão ENTRAR (usando LoginButton existente)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: controller.irParaLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF99),
              foregroundColor: Colors.black,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login, size: 20),
                SizedBox(width: 8),
                Text(
                  'ENTRAR AGORA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botão secundário para criar outra conta
        TextButton(
          onPressed: controller.criarNovaConta,
          child: Text(
            'Criar outra conta',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ← NOVA: Link para login (versão original)
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Já tem uma conta?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 8),
        const LoginButton(),
      ],
    );
  }

  // ← NOVA: Ações após sucesso
  Widget _buildSuccessActions() {
    return Column(
      children: [
        // Dica
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFF00FF99).withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Utilize suas credenciais para acessar o sistema',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}