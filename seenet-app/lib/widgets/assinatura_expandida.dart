// lib/widgets/assinatura_expandida.dart
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

// Abre um quadro grande (tela cheia) pra assinar, usando o MESMO controller
// do campo pequeno de origem — o traço desenhado aqui já é o dado que o
// botão de confirmar/enviar de cada tela lê depois (nada muda no fluxo de
// salvar/enviar assinatura).
Future<void> abrirAssinaturaExpandida(
  BuildContext context,
  SignatureController controller, {
  String titulo = 'Assinatura',
  Color corFundo = Colors.white,
  Color corDestaque = const Color(0xFF00FF88),
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AssinaturaExpandidaScreen(
        controller: controller,
        titulo: titulo,
        corFundo: corFundo,
        corDestaque: corDestaque,
      ),
    ),
  );
}

class _AssinaturaExpandidaScreen extends StatefulWidget {
  final SignatureController controller;
  final String titulo;
  final Color corFundo;
  final Color corDestaque;

  const _AssinaturaExpandidaScreen({
    required this.controller,
    required this.titulo,
    required this.corFundo,
    required this.corDestaque,
  });

  @override
  State<_AssinaturaExpandidaScreen> createState() =>
      _AssinaturaExpandidaScreenState();
}

class _AssinaturaExpandidaScreenState
    extends State<_AssinaturaExpandidaScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.titulo,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: () => widget.controller.clear(),
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white54, size: 18),
            label: const Text('Limpar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.corFundo,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.controller.isNotEmpty
                    ? widget.corDestaque
                    : Colors.white24,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Signature(
                controller: widget.controller,
                backgroundColor: widget.corFundo,
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check, color: Colors.black),
            label: const Text('Concluir',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.corDestaque,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}
