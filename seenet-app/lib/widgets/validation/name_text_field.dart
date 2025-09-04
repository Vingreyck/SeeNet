
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/validation_service.dart';

/// lib/widgets/validation/email_text_field.dart
/// TextField especializado para nome com validação
class NameTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool required;
  final bool allowEmpty;
  final int minLength;
  final int maxLength;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function(ValidationResult)? onValidationChanged;
  final EdgeInsetsGeometry? contentPadding;
  final bool filled;
  final Color? fillColor;
  final InputBorder? border;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;
  final Widget? prefixIcon;
  final bool enabled;

  const NameTextField({
    super.key,
    this.controller,
    this.labelText = 'Nome',
    this.hintText = 'Digite seu nome completo',
    this.required = true,
    this.allowEmpty = false,
    this.minLength = 2,
    this.maxLength = 100,
    this.onChanged,
    this.onSubmitted,
    this.onValidationChanged,
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
  State<NameTextField> createState() => _NameTextFieldState();
}

class _NameTextFieldState extends State<NameTextField> {
  late TextEditingController _controller;
  ValidationResult _validationResult = ValidationResult.valid();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
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
    
    // Sanitizar nome
    String sanitized = ValidationService.instance.sanitizeName(value);
    if (sanitized != value) {
      _controller.value = _controller.value.copyWith(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }

    // Validar
    ValidationResult result = ValidationService.instance.validateName(
      sanitized,
      allowEmpty: widget.allowEmpty,
      minLength: widget.minLength,
      maxLength: widget.maxLength,
    );

    setState(() {
      _validationResult = result;
    });

    widget.onChanged?.call(sanitized);
    widget.onValidationChanged?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      onSubmitted: widget.onSubmitted,
      inputFormatters: [
        LengthLimitingTextInputFormatter(widget.maxLength),
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZÀ-ÿ\s]')),
      ],
      decoration: InputDecoration(
        labelText: widget.required ? '${widget.labelText} *' : widget.labelText,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon ?? const Icon(Icons.person_outlined),
        suffixIcon: _buildSuffixIcon(),
        errorText: _validationResult.isValid ? null : _validationResult.error,
        helperText: _validationResult.isValid && _controller.text.isNotEmpty 
            ? 'Nome válido' 
            : null,
        helperStyle: const TextStyle(color: Colors.green),
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
    );
  }

  Widget? _buildSuffixIcon() {
    if (_controller.text.isEmpty) return null;
    
    if (_validationResult.isValid) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else {
      return Icon(Icons.error, color: _validationResult.severity.color);
    }
  }
}