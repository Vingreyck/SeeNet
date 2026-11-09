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
        // Sem isto, quando a prévia não consegue desenhar o PDF, o pacote só
        // escreve "Unable to display the document" e o usuário fica sem saída.
        // No WEB a prévia depende do pdf.js desenhar num canvas — bloqueador
        // de anúncio/proteção do navegador (Brave) pode impedir. O PDF em si
        // está certo: baixar ou abrir no leitor do navegador funciona.
        onError: (context, erro) => _FalhaPrevia(
          bytes: bytes,
          titulo: titulo,
          erro: erro,
        ),
      ),
    );
  }
}

class _FalhaPrevia extends StatelessWidget {
  final Uint8List bytes;
  final String titulo;
  final Object erro;

  const _FalhaPrevia({
    required this.bytes,
    required this.titulo,
    required this.erro,
  });

  static const _verde = Color(0xFF00FF88);

  @override
  Widget build(BuildContext context) {
    // Vai pro console (F12 no navegador) pra dar pra ver a causa real.
    debugPrint('❌ Prévia do PDF falhou: $erro');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: _verde, size: 48),
              const SizedBox(height: 14),
              const Text(
                'Não deu pra mostrar a prévia aqui',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'O documento está pronto. Abra no leitor de PDF do navegador '
                'ou baixe o arquivo.\nSe usa o Brave, desligar o "Shields" '
                'neste site também resolve a prévia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Printing.layoutPdf(
                    name: titulo,
                    onLayout: (_) async => bytes,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.black),
                  label: const Text('Abrir / imprimir',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Printing.sharePdf(
                    bytes: bytes,
                    filename: '$titulo.pdf',
                  ),
                  icon: const Icon(Icons.download_rounded, color: _verde),
                  label: const Text('Baixar PDF', style: TextStyle(color: _verde)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _verde),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Detalhe técnico: $erro',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
