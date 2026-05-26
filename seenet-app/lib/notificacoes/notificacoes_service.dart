// lib/notificacoes/notificacoes_service.dart
import 'package:get/get.dart';
import '../services/api_service.dart';

class NotificacoesService {
  ApiService get _api => Get.find<ApiService>();

  Future<Map<String, dynamic>> buscarNotificacoes({int pagina = 1}) async {
    final resp = await _api.get('/notificacoes?pagina=$pagina&limite=30');
    return {
      'notificacoes': (resp['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      'nao_lidas': resp['nao_lidas'] ?? 0,
    };
  }

  Future<void> marcarTodasLidas() async {
    await _api.put('/notificacoes/todas-lidas', {});
  }

  Future<void> marcarLida(int id) async {
    await _api.put('/notificacoes/$id/lida', {});
  }
}