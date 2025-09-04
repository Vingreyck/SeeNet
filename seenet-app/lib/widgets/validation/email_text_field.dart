// lib/widgets/validation/email_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/validation_service.dart';

/// TextField especializado para email com validação em tempo real
class EmailTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool required;
  final bool allowEmpty;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function(ValidationResult)? onValidationChanged;
  final bool enableSuggestions;
  final EdgeInsetsGeometry? contentPadding;
  final bool filled;
  final Color? fillColor;
  final InputBorder? border;
  final InputBorder? focusedBorder;
  final InputBorder? errorBorder;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;

  const EmailTextField({
    super.key,
    this.controller,
    this.labelText = 'Email',
    this.hintText = 'Digite seu email',
    this.required = true,
    this.allowEmpty = false,
    this.onChanged,
    this.onSubmitted,
    this.onValidationChanged,
    this.enableSuggestions = true,
    this.contentPadding,
    this.filled = true,
    this.fillColor,
    this.border,
    this.focusedBorder,
    this.errorBorder,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  });

  @override
  State<EmailTextField> createState() => _EmailTextFieldState();
}

class _EmailTextFieldState extends State<EmailTextField> {
  late TextEditingController _controller;
  ValidationResult _validationResult = ValidationResult.valid();
  String _suggestion = '';
  bool _showSuggestion = false;

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
    
    // Sanitizar input
    String sanitized = ValidationService.instance.sanitizeEmail(value);
    if (sanitized != value) {
      _controller.value = _controller.value.copyWith(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }

    // Validar
    ValidationResult result = ValidationService.instance.validateEmail(
      sanitized,
      allowEmpty: widget.allowEmpty,
    );

    setState(() {
      _validationResult = result;
      _suggestion = result.suggestion ?? '';
      _showSuggestion = result.suggestion != null && widget.enableSuggestions;
    });

    widget.onChanged?.call(sanitized);
    widget.onValidationChanged?.call(result);
  }

  void _applySuggestion() {
    if (_suggestion.isNotEmpty) {
      _controller.text = _suggestion;
      setState(() {
        _showSuggestion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          onSubmitted: widget.onSubmitted,
          inputFormatters: [
            LengthLimitingTextInputFormatter(254),
            FilteringTextInputFormatter.deny(RegExp(r'\s')), // Sem espaços em email
          ],
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.labelText} *' : widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon ?? const Icon(Icons.email_outlined),
            suffixIcon: _buildSuffixIcon(),
            errorText: _validationResult.isValid ? null : _validationResult.error,
            helperText: _validationResult.isValid && _controller.text.isNotEmpty 
                ? 'Email válido' 
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
        ),
        
        // Sugestão de correção
        if (_showSuggestion)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: GestureDetector(
              onTap: _applySuggestion,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      _suggestion,
                      style: const TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.suffixIcon != null) return widget.suffixIcon;
    
    if (_controller.text.isEmpty) return null;
    
    if (_validationResult.isValid) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else {
      return Icon(
        Icons.error,
        color: _validationResult.severity.color,
      );
    }
  }
}





