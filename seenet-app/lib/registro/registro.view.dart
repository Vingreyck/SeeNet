// lib/registro/registro.view.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/loginbutton.widget.dart';
import 'package:flutter/services.dart';
import 'registroview.controller.dart';

class RegistrarView extends GetView<RegistroController> {
  RegistrarView({super.key}) {
    _obscurePassword = true.obs;
    _obscureConfirmPassword = true.obs;
  }

  late final RxBool _obscurePassword;
  late final RxBool _obscureConfirmPassword;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      const Expanded(
                        child: Text(
                          'Criar Conta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
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

                              _buildTextField(
                                controller: controller.nomeInput,
                                label: 'Nome Completo',
                                hint: 'Digite seu nome completo',
                                icon: Icons.person,
                                textCapitalization: TextCapitalization.words,
                              ),

                              const SizedBox(height: 20),

                              _buildPasswordField(
                                controller: controller.senhaInput,
                                label: 'Senha',
                                hint: 'Mínimo 6 caracteres',
                                obscureObs: _obscurePassword,
                                onToggle: () => _obscurePassword.toggle(),
                              ),

                              const SizedBox(height: 20),

                              _buildPasswordField(
                                controller: controller.confirmarSenhaInput,
                                label: 'Confirmar Senha',
                                hint: 'Repita a senha',
                                obscureObs: _obscureConfirmPassword,
                                onToggle: () => _obscureConfirmPassword.toggle(),
                              ),

                              const SizedBox(height: 20),

                              _buildTokenField(),

                              const SizedBox(height: 20),

                              _buildTokenStatus(),

                              const SizedBox(height: 30),

                              _buildRegisterButton(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Já tem uma conta?',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 8),
                            LoginButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required RxBool obscureObs,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.lock, color: Color(0xFF00FF99), size: 16),
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
        Obx(() => TextFormField(
          controller: controller,
          obscureText: obscureObs.value,
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
              Icons.lock_outline,
              color: Colors.white.withOpacity(0.7),
              size: 24,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureObs.value ? Icons.visibility_off : Icons.visibility,
                color: Colors.white.withOpacity(0.7),
                size: 24,
              ),
              onPressed: onToggle,
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
          inputFormatters: [
            UpperCaseTextFormatter(), // ← força maiúsculas
          ],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
          decoration: InputDecoration(
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

  Widget _buildRegisterButton() {
    return Obx(() {
      final bool podeRegistrar = controller.podeRegistrar;

      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: podeRegistrar ? controller.tryToRegister : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: podeRegistrar
                ? const Color(0xFF00FF99)
                : const Color(0xFF4B5563),
            foregroundColor: podeRegistrar ? Colors.black : Colors.white70,
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
                _getButtonText(),
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

  String _getButtonText() {
    if (controller.nomeInput.text.trim().isEmpty) return 'Digite seu nome';
    if (controller.senhaInput.text.length < 6) return 'Senha muito curta';
    if (controller.confirmarSenhaInput.text.isEmpty) return 'Confirme a senha';
    if (controller.senhaInput.text != controller.confirmarSenhaInput.text) {
      return 'Senhas não coincidem';
    }
    if (controller.tokenEmpresaController.text.trim().isEmpty) return 'Digite o token';
    if (!controller.tokenValido.value) return 'Token inválido';
    return 'CRIAR CONTA';
  }
}

// ✅ Fora da classe — força maiúsculas no campo de token
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}