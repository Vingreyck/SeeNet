import 'dart:convert';
import 'dart:io' if (dart.library.html) '../utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
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
    };
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

  Future<bool> finalizarOS(String osId, Map<String, dynamic> dados) async {
    try {
      print('🏁 Finalizando OS $osId');

      if (dados['fotos'] != null && (dados['fotos'] as List).isNotEmpty) {
        List<Map<String, String>> fotosComMetadados = [];
        List<Map<String, dynamic>> anexos = List<Map<String, dynamic>>.from(dados['fotos']);

        for (var anexo in anexos) {
          try {
            if (kIsWeb) continue; // web não tem acesso ao sistema de arquivos
            final File file = File(anexo['path']);
            if (!await file.exists()) continue;
            final bytes = await file.readAsBytes();
            final Uint8List uint8Bytes = Uint8List.fromList(bytes);
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

        dados['fotos'] = fotosComMetadados;
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