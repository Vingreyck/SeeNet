import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ordem_servico_model.dart';
import 'package:get/get.dart';
import 'package:seenet/services/auth_service.dart';

class OrdemServicoService {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  final AuthService _authService = Get.find<AuthService>();

  // Buscar OSs do técnico logado
  Future<List<OrdemServico>> buscarMinhasOSs() async {
    try {
      final token = _authService.token;
      if (token == null) throw Exception('Token não encontrado');

      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/minhas'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => OrdemServico.fromJson(json)).toList();
      } else {
        throw Exception('Erro ao buscar OSs: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro em buscarMinhasOSs: $e');
      rethrow;
    }
  }

  // Buscar detalhes de uma OS específica
  Future<OrdemServico> buscarDetalhesOS(String osId) async {
    try {
      final token = _authService.token;
      if (token == null) throw Exception('Token não encontrado');

      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/$osId/detalhes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
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

  // Iniciar execução da OS
  Future<bool> iniciarOS(String osId, double latitude, double longitude) async {
    try {
      final token = _authService.token;
      if (token == null) throw Exception('Token não encontrado');

      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/iniciar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro em iniciarOS: $e');
      return false;
    }
  }

  // Finalizar OS
  Future<bool> finalizarOS(String osId, Map<String, dynamic> dados) async {
    try {
      final token = _authService.token;
      if (token == null) throw Exception('Token não encontrado');

      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/finalizar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(dados),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro em finalizarOS: $e');
      return false;
    }
  }
}