import 'package:flutter/material.dart';

class RelatoWidget extends StatefulWidget {
  final TextEditingController problemaController;
  final TextEditingController solucaoController;

  const RelatoWidget({
    super.key,
    required this.problemaController,
    required this.solucaoController,
  });

  @override
  State<RelatoWidget> createState() => _RelatoWidgetState();
}

class _RelatoWidgetState extends State<RelatoWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTextField(
          controller: widget.problemaController,
          label: 'Problema Relatado',
          hint: 'Descreva o problema encontrado',
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: widget.solucaoController,
          label: 'Solução Aplicada',
          hint: 'Descreva a solução implementada',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2),
        ),
      ),
    );
  }
}