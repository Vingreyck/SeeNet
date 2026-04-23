// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void abrirPdfNoNavegador(List<int> bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  html.Url.revokeObjectUrl(url);
}