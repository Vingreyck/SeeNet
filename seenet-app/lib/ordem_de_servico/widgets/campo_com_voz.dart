// ================================================================
// ARQUIVO: import '../widgets/campo_com_voz.dart';
// Widget reutilizável: TextField + botão de transcrição por voz
// ================================================================
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CampoComVoz extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool appendMode; // true = acumula; false = substitui

  const CampoComVoz({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.appendMode = false,
  });

  @override
  State<CampoComVoz> createState() => _CampoComVozState();
}

class _CampoComVozState extends State<CampoComVoz>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ouvindo = false;
  bool _disponivel = false;
  String _parcial = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _inicializarSpeech();
  }

  Future<void> _inicializarSpeech() async {
    _disponivel = await _speech.initialize(
      onError: (_) => _pararOuvir(),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _pararOuvir();
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleVoz() async {
    if (_ouvindo) { _pararOuvir(); return; }

    if (!_disponivel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microfone não disponível'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final textoAnterior = widget.controller.text;

    setState(() { _ouvindo = true; _parcial = ''; });

    await _speech.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        setState(() { _parcial = result.recognizedWords; });

        if (result.finalResult) {
          final transcrito = result.recognizedWords.trim();
          if (transcrito.isNotEmpty) {
            if (widget.appendMode && textoAnterior.isNotEmpty) {
              widget.controller.text = '$textoAnterior $transcrito';
            } else {
              widget.controller.text = transcrito;
            }
            // Mover cursor para o final
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );
          }
          _pararOuvir();
        }
      },
    );
  }

  void _pararOuvir() {
    _speech.stop();
    if (mounted) setState(() { _ouvindo = false; _parcial = ''; });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Campo de texto principal
            TextField(
              controller: widget.controller,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: _ouvindo ? 'Ouvindo...' : widget.hint,
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: TextStyle(
                  color: _ouvindo
                      ? const Color(0xFF00FF88).withOpacity(0.6)
                      : Colors.white30,
                  fontStyle: _ouvindo ? FontStyle.italic : FontStyle.normal,
                ),
                filled: true,
                fillColor: _ouvindo
                    ? const Color(0xFF00FF88).withOpacity(0.05)
                    : const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _ouvindo
                        ? const Color(0xFF00FF88)
                        : Colors.white12,
                    width: _ouvindo ? 1.5 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF00FF88), width: 2),
                ),
                // Espaço para o botão não sobrepor o texto
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                suffixIcon: _buildBotaoMic(),
              ),
            ),
          ],
        ),

        // Preview do que está sendo ouvido
        if (_ouvindo && _parcial.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq,
                    color: Color(0xFF00FF88), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _parcial,
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBotaoMic() {
    if (!_disponivel) {
      return const Padding(
        padding: EdgeInsets.only(right: 8),
        child: Icon(Icons.mic_off, color: Colors.white24, size: 22),
      );
    }

    if (_ouvindo) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: _pararOuvir,
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 1.5),
              ),
              child: const Text('🎙️', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: _toggleVoz,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF88).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Text('🎤', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}