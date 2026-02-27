
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../services/seguranca_service.dart';
import 'package:get/get.dart';

class BotaoPDF extends StatefulWidget {
  final int requisicaoId;
  final String? pdfBase64Cached; // se já tiver o base64 em cache

  const BotaoPDF({
    super.key,
    required this.requisicaoId,
    this.pdfBase64Cached,
  });

  @override
  State<BotaoPDF> createState() => _BotaoPDFState();
}

class _BotaoPDFState extends State<BotaoPDF> {
  bool _loading = false;
  final _service = Get.find<SegurancaService>();

  Future<void> _compartilharPDF() async {
    setState(() => _loading = true);
    try {
      String? pdfBase64 = widget.pdfBase64Cached;

      // Busca do servidor se não tiver em cache
      if (pdfBase64 == null || pdfBase64.isEmpty) {
        pdfBase64 = await _service.buscarPdf(widget.requisicaoId);
      }

      if (pdfBase64 == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF não disponível. A requisição precisa estar aprovada.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Decodifica base64
      final clean = pdfBase64.replaceFirst(
          RegExp(r'^data:application/pdf;base64,'), '');
      final bytes = base64Decode(clean);

      // Salva em arquivo temporário
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/EPI_Requisicao_${String.fromCharCodes(Iterable.generate(5, (_) => 48 + (DateTime.now().millisecondsSinceEpoch % 10)))}.pdf');
      await file.writeAsBytes(bytes);

      // Compartilha
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject:
        'Ficha de EPI #${String.valueOf(widget.requisicaoId).padLeft(5, '0')} - BBnet Up',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _compartilharPDF,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFF00FF88).withOpacity(0.4)),
        ),
        child: _loading
            ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: Color(0xFF00FF88), strokeWidth: 2))
            : const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf,
                color: Color(0xFF00FF88), size: 16),
            SizedBox(width: 6),
            Text('PDF',
                style: TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}