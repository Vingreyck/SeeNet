// lib/registro/registro.view.dart — REDESIGN PREMIUM
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/loginbutton.widget.dart';
import 'registroview.controller.dart';

class RegistrarView extends GetView<RegistroController> {
  RegistrarView({super.key}) {
    _obscurePassword = true.obs;
    _obscureConfirmPassword = true.obs;
  }

  late final RxBool _obscurePassword;
  late final RxBool _obscureConfirmPassword;

  static const List<Map<String, dynamic>> _almoxarifados = [
    {'id': 1, 'nome': 'ITABAIANA'},
    {'id': 91,  'nome': 'CAPELA'},
    {'id': 71,  'nome': 'CAMPO DO BRITO'},
    {'id': 69,  'nome': 'MACAMBIRA'},
    {'id': 68,  'nome': 'AREIA BRANCA'},
    {'id': 22,  'nome': 'MOITA BONITA'},
    {'id': 17,  'nome': 'SÃO DOMINGOS'},
    {'id': 16,  'nome': 'RIBEIRÓPOLIS'},
    {'id': 14,  'nome': 'N. SRA. DA GLÓRIA'},
    {'id': 13,  'nome': 'FREI PAULO'},
    {'id': 9,   'nome': 'N. SRA. DE APARECIDA'},
    {'id': 8,   'nome': 'FEIRA NOVA'},
    {'id': 7,   'nome': 'N. SRA. DAS DORES'},
    {'id': 6,   'nome': 'MALHADOR'},
    {'id': 5,   'nome': 'PINHÃO'},
  ];

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

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

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Stack(
          children: [
            // Fundo
            Positioned.fill(child: _buildFundo()),

            SafeArea(
              child: Column(
                children: [
                  // ── Top bar ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Get.back(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Criar Conta',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        // Logo pequena
                        SvgPicture.asset('assets/images/logo.svg',
                            width: 28, height: 28),
                      ],
                    ),
                  ),

                  // ── Formulário ────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Headline
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                                  colors: [Colors.white, Color(0xFF00FF88)],
                                ).createShader(bounds),
                            child: const Text('Nova conta',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8)),
                          ),
                          const SizedBox(height: 4),
                          Text('Preencha os dados abaixo para começar',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 13)),

                          const SizedBox(height: 28),

                          // ── Seção: Dados pessoais ──────────
                          _secaoLabel('IDENTIFICAÇÃO',
                              Icons.person_outline_rounded),
                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: controller.nomeInput,
                            label: 'Nome Completo',
                            hint: 'Ex: João Silva',
                            icon: Icons.badge_outlined,
                            textCapitalization: TextCapitalization.words,
                          ),

                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: controller.telefoneInput,
                            label: 'Telefone (usado no login)',
                            hint: 'Ex: (79) 99999-9999',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 12),

                          _buildPasswordField(
                            controller: controller.senhaInput,
                            label: 'Senha',
                            hint: 'Mínimo 6 caracteres',
                            obscureObs: _obscurePassword,
                            onToggle: () => _obscurePassword.toggle(),
                          ),

                          const SizedBox(height: 12),

                          _buildPasswordField(
                            controller: controller.confirmarSenhaInput,
                            label: 'Confirmar Senha',
                            hint: 'Repita a senha',
                            obscureObs: _obscureConfirmPassword,
                            onToggle: () => _obscureConfirmPassword.toggle(),
                          ),

                          const SizedBox(height: 24),

                          // ── Seção: Empresa ─────────────────
                          _secaoLabel('EMPRESA', Icons.business_outlined),
                          const SizedBox(height: 12),

                          _buildTokenField(),
                          const SizedBox(height: 8),
                          _buildTokenStatus(),

                          const SizedBox(height: 12),
                          _buildCidadeField(),

                          const SizedBox(height: 32),

                          // ── Botão criar ────────────────────
                          _buildRegisterButton(),

                          const SizedBox(height: 24),

                          // ── Já tem conta ───────────────────
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Já tem uma conta? ',
                                    style: TextStyle(
                                        color:
                                        Colors.white.withOpacity(0.35),
                                        fontSize: 14)),
                                const LoginButton(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundo() {
    return CustomPaint(
      painter: _RegistroFundoPainter(),
    );
  }

  Widget _secaoLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00FF88), size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.08)),
        ),
      ],
    );
  }

  // ── Campos ────────────────────────────────────────────────────

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
        _fieldLabel(label, icon),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization ?? TextCapitalization.none,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(hint: hint, prefixIcon: icon),
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
        _fieldLabel(label, Icons.lock_outline_rounded),
        const SizedBox(height: 6),
        Obx(() => TextFormField(
          controller: controller,
          obscureText: obscureObs.value,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(
            hint: hint,
            prefixIcon: Icons.lock_outline_rounded,
            suffix: GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  obscureObs.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white38, size: 18,
                ),
              ),
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
        _fieldLabel('Token da Empresa', Icons.vpn_key_outlined),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller.tokenEmpresaController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          style: const TextStyle(
              color: Colors.white, fontSize: 15, letterSpacing: 1.5),
          decoration: _inputDecoration(
              hint: 'Ex: BBNET123',
              prefixIcon: Icons.vpn_key_outlined),
        ),
      ],
    );
  }

  Widget _buildCidadeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Cidade / Loja', Icons.location_city_outlined),
        const SizedBox(height: 6),
        Obx(() => DropdownButtonFormField<int>(
          value: controller.almoxarifadoSelecionado.value == 0
              ? null
              : controller.almoxarifadoSelecionado.value,
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white38),
          decoration: _inputDecoration(
              hint: 'Selecione sua cidade',
              prefixIcon: Icons.location_city_outlined),
          items: _almoxarifados.map((a) => DropdownMenuItem<int>(
            value: a['id'] as int,
            child: Text(a['nome'] as String,
                style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: (val) {
            if (val != null) {
              controller.almoxarifadoSelecionado.value = val;
              controller.almoxarifadoNome.value = _almoxarifados
                  .firstWhere((a) => a['id'] == val)['nome'] as String;
            }
          },
        )),
      ],
    );
  }

  Widget _buildTokenStatus() {
    return Obx(() {
      if (controller.verificandoToken.value) {
        return _statusBanner(
          icon: const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: Colors.blue)),
          texto: 'Verificando token...',
          cor: Colors.blue,
        );
      }
      if (controller.tokenValido.value &&
          controller.empresaInfo.value != null) {
        return _statusBanner(
          icon: const Icon(Icons.verified_rounded,
              color: Color(0xFF00FF88), size: 15),
          texto: 'Token válido: ${controller.empresaInfo.value!['nome']}',
          cor: const Color(0xFF00FF88),
        );
      }
      if (controller.tokenEmpresa.isNotEmpty &&
          !controller.tokenValido.value) {
        return _statusBanner(
          icon: const Icon(Icons.error_outline_rounded,
              color: Colors.red, size: 15),
          texto: 'Token inválido',
          cor: Colors.red,
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _statusBanner({
    required Widget icon,
    required String texto,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Text(texto,
              style: TextStyle(
                  color: cor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Obx(() {
      final bool podeRegistrar = controller.podeRegistrar;

      return GestureDetector(
        onTap: podeRegistrar ? controller.tryToRegister : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: podeRegistrar
                ? const LinearGradient(
              colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : const LinearGradient(colors: [
              Color(0xFF1E1E1E), Color(0xFF1E1E1E)]),
            borderRadius: BorderRadius.circular(16),
            border: podeRegistrar
                ? null
                : Border.all(color: Colors.white12),
            boxShadow: podeRegistrar
                ? [
              BoxShadow(
                color: const Color(0xFF00FF88).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              )
            ]
                : null,
          ),
          child: Center(
            child: controller.isLoading.value
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.black))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  podeRegistrar
                      ? Icons.person_add_rounded
                      : Icons.lock_rounded,
                  color: podeRegistrar
                      ? Colors.black
                      : Colors.white24,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(_getButtonText(),
                    style: TextStyle(
                        color: podeRegistrar
                            ? Colors.black
                            : Colors.white24,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _fieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00FF88), size: 12),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(width: 3),
        const Text('*',
            style: TextStyle(
                color: Color(0xFF00FF88), fontSize: 11)),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: Colors.white24, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF141414),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withOpacity(0.07))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF00FF88), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14),
    );
  }
}

// ── Fundo do registro ────────────────────────────────────────────
class _RegistroFundoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    canvas.drawCircle(Offset(size.width, 0), 150, p1);

    final p2 = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(Offset(0, size.height), 120, p2);

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.02);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Formatter ────────────────────────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}