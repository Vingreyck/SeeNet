// lib/widgets/validation/email_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/validation_service.dart';

// lib/widgets/validation/password_text_field.dart
/// TextField especializado para senha com validação em tempo real
class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool required;
  final PasswordRules rules;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function(ValidationResult)? onValidationChanged;
  final Function(PasswordStrength)? onStrengthChanged;
  final bool showStrengthIndicator;
  final bool showToggleVisibility;
  final bool showPasswordRules;
  final String? confirmPassword;
  final EdgeInsetsGeometry? contentPadding;
  final bool filled;
  final Color? fillColor;
  final InputBorder? border;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;
  final Widget? prefixIcon;
  final bool enabled;

  const PasswordTextField({
    super.key,
    this.controller,
    this.labelText = 'Senha',
    this.hintText = 'Digite sua senha',
    this.required = true,
    this.rules = PasswordRules.basic,
    this.onChanged,
    this.onSubmitted,
    this.onValidationChanged,
    this.onStrengthChanged,
    this.showStrengthIndicator = true,
    this.showToggleVisibility = true,
    this.showPasswordRules = false,
    this.confirmPassword,
    this.contentPadding,
    this.filled = true,
    this.fillColor,
    this.border,
    this.focusedBorder,
    this.errorBorder,
    this.prefixIcon,
    this.enabled = true,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  late TextEditingController _controller;
  ValidationResult _validationResult = ValidationResult.valid();
  PasswordStrength _strength = PasswordStrength.veryWeak;
  bool _obscureText = true;
  bool _showRules = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _showRules = widget.showPasswordRules;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    String value = _controller.text;

    // Validar senha
    ValidationResult result = ValidationService.instance.validatePassword(
      value,
      rules: widget.rules,
      confirmPassword: widget.confirmPassword,
    );

    // Calcular força da senha
    PasswordStrength strength = ValidationService.instance.calculatePasswordStrength(value);

    setState(() {
      _validationResult = result;
      _strength = strength;
    });

    widget.onChanged?.call(value);
    widget.onValidationChanged?.call(result);
    widget.onStrengthChanged?.call(strength);
  }

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  void _toggleRules() {
    setState(() {
      _showRules = !_showRules;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          obscureText: _obscureText,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: widget.onSubmitted,
          inputFormatters: [
            LengthLimitingTextInputFormatter(widget.rules.maxLength),
            if (!widget.rules.allowSpaces)
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
          ],
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.labelText} *' : widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon ?? const Icon(Icons.lock_outlined),
            suffixIcon: _buildSuffixIcon(),
            errorText: _validationResult.isValid ? null : _validationResult.error,
            contentPadding: widget.contentPadding,
            filled: widget.filled,
            fillColor: widget.fillColor ?? Colors.white70,
            border: widget.border ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: widget.focusedBorder ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2),
            ),
            errorBorder: widget.errorBorder ?? OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),

        // Indicador de força da senha
        if (widget.showStrengthIndicator && _controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Força da senha: ${_strength.label}',
                  style: TextStyle(
                    color: _strength.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: (_strength.level + 1) / 5,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(_strength.color),
                  minHeight: 4,
                ),
              ],
            ),
          ),

        // Regras da senha
        if (_showRules || (widget.showPasswordRules && _controller.text.isNotEmpty))
          _buildPasswordRules(),
      ],
    );
  }

  Widget _buildSuffixIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showPasswordRules)
          IconButton(
            icon: Icon(
              _showRules ? Icons.visibility_off : Icons.info_outline,
              size: 20,
            ),
            onPressed: _toggleRules,
            tooltip: _showRules ? 'Ocultar regras' : 'Mostrar regras',
          ),
        if (widget.showToggleVisibility)
          IconButton(
            icon: Icon(
              _obscureText ? Icons.visibility : Icons.visibility_off,
              size: 20,
            ),
            onPressed: _toggleVisibility,
            tooltip: _obscureText ? 'Mostrar senha' : 'Ocultar senha',
          ),
      ],
    );
  }

  Widget _buildPasswordRules() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Requisitos da senha:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _buildRule(
              'Pelo menos ${widget.rules.minLength} caracteres',
              _controller.text.length >= widget.rules.minLength,
            ),
            if (widget.rules.requireUppercase)
              _buildRule(
                'Uma letra maiúscula',
                _controller.text.contains(RegExp(r'[A-Z]')),
              ),
            if (widget.rules.requireLowercase)
              _buildRule(
                'Uma letra minúscula',
                _controller.text.contains(RegExp(r'[a-z]')),
              ),
            if (widget.rules.requireDigits)
              _buildRule(
                'Um número',
                _controller.text.contains(RegExp(r'\d')),
              ),
            if (widget.rules.requireSpecialChars)
              _buildRule(
                'Um caractere especial',
                ValidationService.instance.containsSpecialChar(_controller.text),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRule(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}