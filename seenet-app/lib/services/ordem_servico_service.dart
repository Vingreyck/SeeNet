import 'dart:convert';
import 'app_info.dart';
import 'dart:io' if (dart.library.html) '../utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/ordem_servico_model.dart';
import 'package:get/get.dart';
import 'package:seenet/services/auth_service.dart';

class OrdemServicoService {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  final AuthService _authService = Get.find<AuthService>();

  Map<String, String> get _headers {
    final token = _authService.token;
    final tenantCode = _authService.tenantCode;
    return {
      'Authorization': 'Bearer $token',
      'X-Tenant-Code': tenantCode ?? '',
      'Content-Type': 'application/json',
      ...AppInfo.header,
    };
  }

  // 💾 Rascunho do wizard no servidor (preserva tudo ao reagendar/encaminhar).
  Future<bool> salvarRascunho(String osId, Map<String, dynamic> dados) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/rascunho'),
        headers: _headers,
        body: json.encode({'dados': dados}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro ao salvar rascunho da OS: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> buscarRascunho(String osId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/$osId/rascunho'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final d = body['data'];
        return d is Map ? Map<String, dynamic>.from(d) : null;
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar rascunho da OS: $e');
      return null;
    }
  }

  Future<void> limparRascunho(String osId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/ordens-servico/$osId/rascunho'),
        headers: _headers,
      );
    } catch (e) {
      print('⚠️ Erro ao apagar rascunho da OS: $e');
    }
  }

  // 🧹 Limpar MAC do login do cliente da OS (botão Limpar MAC do IXC).
  // Retorna {ok, message}. O backend lê o id_login do dados_ixc da OS.
  Future<Map<String, dynamic>> limparMac(String osId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/limpar-mac'),
        headers: _headers,
      );
      final body = response.body.isNotEmpty
          ? json.decode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'ok': true, 'message': body['message'] ?? 'MAC limpo'};
      }
      return {'ok': false, 'message': body['error'] ?? 'Falha ao limpar MAC'};
    } catch (e) {
      print('❌ Erro ao limpar MAC: $e');
      return {'ok': false, 'message': 'Erro de conexão ao limpar MAC'};
    }
  }

  /// 🏠 Corrige o endereço da OS em campo (o cliente informou referência/número
  /// errado no cadastro). O backend grava no SeeNet, no cadastro do login no
  /// IXC (conserta as OS futuras) e deixa um rastro na OS.
  /// [campos]: endereco, numero, bairro, cep, complemento, referencia.
  Future<Map<String, dynamic>> atualizarEndereco(
      String osId, Map<String, String> campos) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/ordens-servico/$osId/endereco'),
        headers: _headers,
        body: json.encode(campos),
      );
      final body = response.body.isNotEmpty
          ? json.decode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'ok': true, 'message': body['message'] ?? 'Endereço atualizado'};
      }
      return {'ok': false, 'message': body['error'] ?? 'Falha ao salvar endereço'};
    } catch (e) {
      print('❌ Erro ao atualizar endereço: $e');
      return {'ok': false, 'message': 'Erro de conexão ao salvar endereço'};
    }
  }

  // 📷 Foto da fachada (frente da casa) do cliente — 1 por cliente, só no SeeNet.
  Future<bool> salvarFachada(String osId, String base64Foto,
      {String mime = 'image/jpeg', double? latitude, double? longitude}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/fachada'),
        headers: _headers,
        body: json.encode({
          'foto_base64': base64Foto,
          'mime': mime,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro ao salvar foto da fachada: $e');
      return false;
    }
  }

  /// Retorna {foto_base64, mime, data} da fachada do cliente da OS, ou null.
  Future<Map<String, dynamic>?> buscarFachada(String osId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/$osId/fachada'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar foto da fachada: $e');
      return null;
    }
  }

  // ✅ NOVO: Buscar lista de admins do tenant
  Future<List<Map<String, dynamic>>> buscarAdmins() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/admins'),
        headers: _headers,
      );

      print('📥 buscarAdmins - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> admins = data['admins'] ?? [];
        return admins.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Erro em buscarAdmins: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> buscarTecnicos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/tecnicos'),
        headers: _headers,
      );

      print('📥 buscarTecnicos - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tecnicos = data['tecnicos'] ?? [];
        return tecnicos.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Erro em buscarTecnicos: $e');
      return [];
    }
  }

  Future<List<OrdemServico>> buscarMinhasOSs() async {
    try {
      final token = _authService.token;
      final tenantCode = _authService.tenantCode;
      if (token == null) throw Exception('Token não encontrado');
      if (tenantCode == null) throw Exception('Código da empresa não encontrado');

      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/minhas'),
        headers: _headers,
      );

      print('📥 buscarMinhasOSs - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData is Map && responseData.containsKey('data')
            ? responseData['data']
            : responseData;
        return data.map((json) => OrdemServico.fromJson(json)).toList();
      } else {
        throw Exception('Erro ao buscar OSs: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro em buscarMinhasOSs: $e');
      rethrow;
    }
  }

  Future<List<OrdemServico>> buscarOSsConcluidas({String busca = '', int limite = 50}) async {
    try {
      final token = _authService.token;
      final tenantCode = _authService.tenantCode;
      if (token == null) throw Exception('Token não encontrado');
      if (tenantCode == null) throw Exception('Código da empresa não encontrado');

      final uri = Uri.parse('$baseUrl/ordens-servico/concluidas').replace(
        queryParameters: {
          'limite': limite.toString(),
          if (busca.isNotEmpty) 'busca': busca,
        },
      );

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData is Map && responseData.containsKey('data')
            ? responseData['data']
            : responseData;
        return data.map((json) => OrdemServico.fromJson(json)).toList();
      } else {
        throw Exception('Erro ao buscar OSs concluídas: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro em buscarOSsConcluidas: $e');
      rethrow;
    }
  }

  Future<OrdemServico> buscarDetalhesOS(String osId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/$osId/detalhes'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return OrdemServico.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar detalhes: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro em buscarDetalhesOS: $e');
      rethrow;
    }
  }

  // ✅ MODIFICADO: Agora aceita adminId
  Future<bool> deslocarParaOS(String osId, double latitude, double longitude, {int? adminId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/deslocar'),
        headers: _headers,
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
          if (adminId != null) 'admin_responsavel_id': adminId,  // ✅ NOVO
        }),
      );

      print('📥 deslocarParaOS - Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro em deslocarParaOS: $e');
      return false;
    }
  }

  Future<bool> chegarAoLocal(String osId, double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/chegar-local'),
        headers: _headers,
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      print('📥 chegarAoLocal - Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro em chegarAoLocal: $e');
      return false;
    }
  }

  /// [itensEstoque] e [onuMac]: material já usado até aqui. Vai junto pro IXC
  /// (o backend reconcilia, não duplica) pra não se perder quando outro técnico
  /// pegar a OS — e pra auditoria já enxergar o que foi gasto.
  Future<bool> reagendarOS(String osId, double latitude, double longitude,
      {String? motivo, List<Map<String, dynamic>>? itensEstoque, String? onuMac,
      List<dynamic>? fotos}) async {
    try {
      final fotosB64 = await _fotosParaBase64(fotos);
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/reagendar'),
        headers: _headers,
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
          'motivo': motivo ?? '',
          if (itensEstoque != null && itensEstoque.isNotEmpty)
            'itens_estoque': itensEstoque,
          if (onuMac != null && onuMac.isNotEmpty) 'onu_mac': onuMac,
          if (fotosB64.isNotEmpty) 'fotos': fotosB64,
        }),
      );

      print('📥 reagendarOS - Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro em reagendarOS: $e');
      return false;
    }
  }

  Future<bool> encaminharOS(String osId, int tecnicoId,
      {String? motivo, List<Map<String, dynamic>>? itensEstoque, String? onuMac,
      List<dynamic>? fotos}) async {
    try {
      final fotosB64 = await _fotosParaBase64(fotos);
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/encaminhar'),
        headers: _headers,
        body: json.encode({
          'tecnico_id': tecnicoId,
          'motivo': motivo ?? '',
          if (itensEstoque != null && itensEstoque.isNotEmpty)
            'itens_estoque': itensEstoque,
          if (onuMac != null && onuMac.isNotEmpty) 'onu_mac': onuMac,
          if (fotosB64.isNotEmpty) 'fotos': fotosB64,
        }),
      );

      print('📥 encaminharOS - Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro em encaminharOS: $e');
      return false;
    }
  }

  /// Sincroniza material/patrimônio/fotos com o IXC DURANTE a execução, sem
  /// esperar finalizar/reagendar/encaminhar — usado ao avançar a etapa de
  /// Fotos ou a de Materiais no wizard. Best-effort: chamado sem bloquear o
  /// técnico (o app não trava se a rede falhar; a foto/produto sobe de novo
  /// no próximo ponto de sincronização — reconciliação, não duplica).
  Future<bool> sincronizarMateriaisEmAndamento(String osId,
      {List<Map<String, dynamic>>? itensEstoque, String? onuMac,
      List<dynamic>? fotos}) async {
    try {
      final fotosB64 = await _fotosParaBase64(fotos);
      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/sincronizar-materiais'),
        headers: _headers,
        body: json.encode({
          if (itensEstoque != null && itensEstoque.isNotEmpty)
            'itens_estoque': itensEstoque,
          if (onuMac != null && onuMac.isNotEmpty) 'onu_mac': onuMac,
          if (fotosB64.isNotEmpty) 'fotos': fotosB64,
        }),
      );
      print('📥 sincronizarMateriaisEmAndamento - Status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro em sincronizarMateriaisEmAndamento: $e');
      return false;
    }
  }

  Future<bool> verificarAPR(String osId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/apr/status/$osId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['preenchido'] == true;
      }
      return true; // em caso de erro não bloqueia
    } catch (e) {
      print('⚠️ Erro ao verificar APR: $e');
      return true;
    }
  }

  /// Converte a lista de fotos do wizard (com `path` de arquivo) pra `base64`,
  /// formato que o backend espera. Usado na finalização e também no
  /// reagendar/encaminhar (material já usado não pode se perder na troca de
  /// técnico). No web não tem acesso a arquivo local → pula (mesma limitação
  /// de sempre; a foto some, mas o resto do fluxo segue normal).
  Future<List<Map<String, String>>> _fotosParaBase64(List<dynamic>? fotos) async {
    final fotosComMetadados = <Map<String, String>>[];
    if (fotos == null || fotos.isEmpty) return fotosComMetadados;

    for (var anexo in List<Map<String, dynamic>>.from(fotos)) {
      try {
        if (kIsWeb) continue; // web não tem acesso ao sistema de arquivos
        final File file = File(anexo['path']);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final String base64Image = base64Encode(bytes);
        fotosComMetadados.add({
          'base64': base64Image,
          'tipo': anexo['tipo'] ?? 'outro',
          'descricao': anexo['descricao'] ?? '',
        });
      } catch (e) {
        print('❌ Erro ao converter foto: $e');
      }
    }
    return fotosComMetadados;
  }

  Future<bool> finalizarOS(String osId, Map<String, dynamic> dados) async {
    try {
      print('🏁 Finalizando OS $osId');

      if (dados['fotos'] != null && (dados['fotos'] as List).isNotEmpty) {
        dados['fotos'] = await _fotosParaBase64(dados['fotos'] as List);
      }

      print('📦 Payload itens_estoque: ${json.encode(dados['itens_estoque'])}');


      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/finalizar'),
        headers: _headers,
        body: json.encode(dados),
      );

      print('✅ Resposta: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro ao finalizar OS: $e');
      return false;
    }
  }
}