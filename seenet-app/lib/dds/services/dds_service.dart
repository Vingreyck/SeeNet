// lib/dds/services/dds_service.dart
import 'package:get/get.dart';
import '../../services/api_service.dart';

class DdsService extends GetxService {
  ApiService get _api => Get.find<ApiService>();

  // ── Sessão ────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> verificarSessaoAtiva() async {
    try {
      final resp = await _api.get('/api/dds/sessao/ativa');
      if (resp['success'] == true) return resp['data'] ?? resp;
      return null;
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>> criarSessao({
    required String tema,
    required int duracaoMinutos,
    String localDds = 'BBNet Up Provedor',
    String? linkMeet,
  }) async {
    try {
      final body = {
        'tema': tema,
        'duracao_minutos': duracaoMinutos,
        'local_dds': localDds,
        if (linkMeet != null && linkMeet.isNotEmpty) 'link_meet': linkMeet,
      };
      return await _api.post('/api/dds/sessao', body);
    } catch (e) {
      return {'error': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> assinar({
    required int sessaoId,
    required String assinaturaBase64,
  }) async {
    try {
      final resp = await _api.post(
        '/api/dds/sessao/$sessaoId/assinar',
        {'assinatura_base64': assinaturaBase64},
      );
      return resp;
    } catch (e) {
      return {'error': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> encerrarSessao(int sessaoId) async {
    try {
      final resp = await _api.put(
        '/api/dds/sessao/$sessaoId/encerrar', {},
      );
      return resp;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Histórico ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> buscarHistorico({int? ano, int? mes}) async {
    try {
      final params = <String, String>{};
      if (ano != null) params['ano'] = '$ano';
      if (mes != null) params['mes'] = '$mes';

      final resp = await _api.get('/api/dds/historico', queryParams: params);
      if (resp['success'] == true) {
        final data = resp['data'] ?? resp;
        final List lista = data['sessoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> buscarParticipantes(int sessaoId) async {
    try {
      final resp = await _api.get('/api/dds/sessao/$sessaoId/participantes');
      if (resp['success'] == true) return resp['data'] ?? resp;
      return null;
    } catch (_) { return null; }
  }

  // ── Calendário técnico ────────────────────────────────────────

  Future<Map<String, dynamic>> buscarCalendarioTecnico(
      int tecnicoId, {int? ano}
      ) async {
    try {
      final params = <String, String>{};
      if (ano != null) params['ano'] = '$ano';

      final resp = await _api.get(
        '/api/dds/tecnico/$tecnicoId/calendario',
        queryParams: params,
      );
      if (resp['success'] == true) {
        final data = resp['data'] ?? resp;
        return (data['calendario'] as Map?)?.cast<String, dynamic>() ?? {};
      }
      return {};
    } catch (_) { return {}; }
  }

  // ── Config responsável ────────────────────────────────────────

  Future<Map<String, dynamic>?> buscarConfig() async {
    try {
      final resp = await _api.get('/api/dds/config');
      if (resp['success'] == true) {
        final data = resp['data'] ?? resp;
        return (data['config'] as Map?)?.cast<String, dynamic>();
      }
      return null;
    } catch (_) { return null; }
  }


  Future<Map<String, dynamic>> salvarConfig(Map<String, dynamic> dados) async {
    try {
      return await _api.put('/api/dds/config', dados);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}