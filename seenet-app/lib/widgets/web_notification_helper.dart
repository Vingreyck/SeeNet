// lib/widgets/web_notification_helper.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:get/get.dart';

// Mensagem chegou com a ABA ABERTA E EM FOCO — nesse caso o navegador NÃO
// mostra nada sozinho (só mostra automaticamente em 2º plano, via o service
// worker). Usa a Notification API nativa do navegador pra exibir também aqui.
void mostrarNotificacaoWeb(String titulo, String corpo, String rota) {
  if (html.Notification.permission != 'granted') return;
  try {
    final n = html.Notification(titulo, body: corpo);
    n.onClick.listen((_) {
      if (rota.isNotEmpty) Get.toNamed(rota);
    });
  } catch (_) {}
}
