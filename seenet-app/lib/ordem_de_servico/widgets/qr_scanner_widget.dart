import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerWidget extends StatefulWidget {
  final Function(String serial) onSerialCapturado;

  const QrScannerWidget({super.key, required this.onSerialCapturado});

  @override
  State<QrScannerWidget> createState() => _QrScannerWidgetState();
}

class _QrScannerWidgetState extends State<QrScannerWidget> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _capturado = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_capturado) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final valor = barcode.rawValue!.trim();
    if (valor.isEmpty) return;

    setState(() => _capturado = true);
    _controller.stop();

    // Fechar e retornar o valor
    if (mounted) Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay com moldura
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: const SizedBox.expand(),
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Aponte para o QR code ou código de barras',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Botão de lanterna
                  IconButton(
                    icon: const Icon(Icons.flashlight_on, color: Colors.white),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),

          // Label inferior
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 80),
              child: Text(
                'Serial da ONU será preenchido automaticamente',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Moldura de scanner no centro da tela
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withOpacity(0.55);
    const rectSize = 260.0;
    final left = (size.width - rectSize) / 2;
    final top = (size.height - rectSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, rectSize, rectSize);

    // Fundo escuro com buraco no meio
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12))),
      ),
      overlay,
    );

    // Bordas verdes nos cantos
    final corner = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;

    // Canto superior esquerdo
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), corner);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), corner);

    // Canto superior direito
    canvas.drawLine(Offset(left + rectSize - cornerLen, top), Offset(left + rectSize, top), corner);
    canvas.drawLine(Offset(left + rectSize, top), Offset(left + rectSize, top + cornerLen), corner);

    // Canto inferior esquerdo
    canvas.drawLine(Offset(left, top + rectSize - cornerLen), Offset(left, top + rectSize), corner);
    canvas.drawLine(Offset(left, top + rectSize), Offset(left + cornerLen, top + rectSize), corner);

    // Canto inferior direito
    canvas.drawLine(Offset(left + rectSize - cornerLen, top + rectSize), Offset(left + rectSize, top + rectSize), corner);
    canvas.drawLine(Offset(left + rectSize, top + rectSize - cornerLen), Offset(left + rectSize, top + rectSize), corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}