// lib/widgets/pdf_viewer_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

// Abre o PDF NUM VISUALIZADOR (zoom, páginas) antes de baixar/compartilhar —
// os botões de compartilhar/imprimir ficam na própria tela, quem decide se
// quer baixar é o usuário depois de ver o documento.
Future<void> abrirVisualizadorPdf(
  BuildContext context,
  Uint8List bytes, {
  String titulo = 'Documento',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PdfViewerScreen(bytes: bytes, titulo: titulo),
    ),
  );
}

class _PdfViewerScreen extends StatelessWidget {
  final Uint8List bytes;
  final String titulo;

  const _PdfViewerScreen({required this.bytes, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(titulo,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis),
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '$titulo.pdf',
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00FF88)),
        ),
      ),
    );
  }
}
