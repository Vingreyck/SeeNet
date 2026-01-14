import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';

class AssinaturaWidget extends StatefulWidget {
  final Function(Uint8List?) onAssinaturaSalva;

  const AssinaturaWidget({
    Key? key,
    required this.onAssinaturaSalva,
  }) : super(key: key);

  @override
  State<AssinaturaWidget> createState() => _AssinaturaWidgetState();
}

class _AssinaturaWidgetState extends State<AssinaturaWidget> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.white,
    exportBackgroundColor: const Color(0xFF1A1A1A),
  );

  bool _assinada = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Canvas de assinatura
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _assinada ? const Color(0xFF00FF88) : Colors.white24,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Signature(
              controller: _controller,
              backgroundColor: const Color(0xFF1A1A1A),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Status
        if (_assinada)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 20),
              SizedBox(width: 8),
              Text(
                'Assinatura confirmada ✓',
                style: TextStyle(
                  color: Color(0xFF00FF88),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          )
        else
          const Text(
            'Assine no espaço acima',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),

        const SizedBox(height: 12),

        // Botões
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _assinada = false;
                  });
                  widget.onAssinaturaSalva(null);
                },
                icon: const Icon(Icons.clear),
                label: const Text('Limpar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _salvarAssinatura,
                icon: const Icon(Icons.check),
                label: const Text('Confirmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _salvarAssinatura() async {
    if (_controller.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, assine antes de confirmar'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final Uint8List? assinatura = await _controller.toPngBytes();

    setState(() {
      _assinada = true;
    });

    widget.onAssinaturaSalva(assinatura);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Assinatura confirmada!'),
          backgroundColor: Color(0xFF00FF88),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}