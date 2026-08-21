import 'dart:convert';
import 'package:get/get.dart';
import '../database/local_database.dart';
import '../services/ordem_servico_service.dart';
import '../services/api_service.dart';

class SyncManager extends GetxService {
  final RxInt pendentes = 0.obs;
  bool _rodando = false;
  final ApiService _api = ApiService.instance;

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
                // `?? const []` cobre a fila gravada por versão ANTERIOR do
                // app, que não tinha esse campo — sem isso, um deslocamento
                // enfileirado offline antes da atualização daria erro de cast.
                adminsIds: ((payload['admins_ids'] as List?) ?? const [])
                    .map((e) => e as int)
                    .toList(),
              );
              break;
            case 'CHEGAR_LOCAL':
              await service.chegarAoLocal(
                payload['os_id'] as String,
                (payload['latitude'] as num).toDouble(),
                (payload['longitude'] as num).toDouble(),
              );
              break;
            case 'SALVAR_APR':
              await _api.post('/apr/respostas', {
                'os_id': int.tryParse(payload['os_id'] as String) ?? payload['os_id'],
                'respostas': payload['respostas'],
                'epis_selecionados': payload['epis_selecionados'],
              });
              break;
            case 'POSICAO':
              // Posição do GPS que falhou por falta de conexão (ver
              // tracking_service.dart / background_location_service.dart).
              // Reenvia pro mesmo endpoint que o tracking ao vivo usa — o
              // backend trata como uma posição normal (upsert + trilha).
              await _api.put('/ordens-servico/${payload['os_id']}/location', {
                'latitude': payload['latitude'],
                'longitude': payload['longitude'],
                'velocidade': payload['velocidade'],
                'precisao': payload['precisao'],
              });
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
      {int? adminId, List<int>? adminsIds}) async {
    await LocalDatabase.enfileirar(
      'DESLOCAR',
      json.encode({
        'os_id': osId,
        'latitude': lat,
        'longitude': lng,
        'admin_id': adminId,
        'admins_ids': adminsIds ?? const <int>[],
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

  Future<void> enfileirarPosicao(String osId, double lat, double lng,
      {double? velocidade, double? precisao}) async {
    await LocalDatabase.enfileirar(
      'POSICAO',
      json.encode({
        'os_id': osId,
        'latitude': lat,
        'longitude': lng,
        'velocidade': velocidade,
        'precisao': precisao,
      }),
    );
    await _atualizarContador();
  }

  Future<void> enfileirarSalvarAPR(
      String osId,
      List<Map<String, dynamic>> respostas,
      List<int> episSelecionados) async {
    await LocalDatabase.enfileirar(
      'SALVAR_APR',
      json.encode({
        'os_id': osId,
        'respostas': respostas,
        'epis_selecionados': episSelecionados,
      }),
    );
    await _atualizarContador();
  }
}