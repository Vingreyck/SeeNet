import 'dart:convert';
import 'package:get/get.dart';
import '../database/local_database.dart';
import '../services/ordem_servico_service.dart';

class SyncManager extends GetxService {
  final RxInt pendentes = 0.obs;
  bool _rodando = false;

  @override
  void onInit() {
    super.onInit();
    _atualizarContador();
  }

  Future<void> _atualizarContador() async {
    pendentes.value = await LocalDatabase.contarPendentes();
  }

  Future<void> sincronizar() async {
    if (_rodando) return;
    _rodando = true;

    try {
      final fila = await LocalDatabase.pendentes();
      if (fila.isEmpty) return;

      print('🔄 SyncManager: ${fila.length} item(ns) na fila');

      final service = Get.find<OrdemServicoService>();

      for (final item in fila) {
        final id = item['id'] as int;
        final tipo = item['tipo'] as String;
        final payload = json.decode(item['payload'] as String);

        try {
          switch (tipo) {
            case 'FINALIZAR_OS':
              await service.finalizarOS(
                payload['os_id'] as String,
                Map<String, dynamic>.from(payload['dados']),
              );
              break;
            case 'DESLOCAR':
              await service.deslocarParaOS(
                payload['os_id'] as String,
                (payload['latitude'] as num).toDouble(),
                (payload['longitude'] as num).toDouble(),
                adminId: payload['admin_id'] as int?,
              );
              break;
            case 'CHEGAR_LOCAL':
              await service.chegarAoLocal(
                payload['os_id'] as String,
                (payload['latitude'] as num).toDouble(),
                (payload['longitude'] as num).toDouble(),
              );
              break;
          }

          await LocalDatabase.marcarSincronizado(id);
          print('   ✅ [$tipo] sincronizado');
        } catch (e) {
          await LocalDatabase.incrementarTentativa(id);
          print('   ❌ [$tipo] falhou: $e');
        }
      }
    } finally {
      _rodando = false;
      await _atualizarContador();
    }
  }

  Future<void> enfileirarFinalizarOS(
      String osId, Map<String, dynamic> dados) async {
    await LocalDatabase.enfileirar(
      'FINALIZAR_OS',
      json.encode({'os_id': osId, 'dados': dados}),
    );
    await _atualizarContador();
  }

  Future<void> enfileirarDeslocar(String osId, double lat, double lng,
      {int? adminId}) async {
    await LocalDatabase.enfileirar(
      'DESLOCAR',
      json.encode({
        'os_id': osId,
        'latitude': lat,
        'longitude': lng,
        'admin_id': adminId,
      }),
    );
    await _atualizarContador();
  }

  Future<void> enfileirarChegar(
      String osId, double lat, double lng) async {
    await LocalDatabase.enfileirar(
      'CHEGAR_LOCAL',
      json.encode({'os_id': osId, 'latitude': lat, 'longitude': lng}),
    );
    await _atualizarContador();
  }
}