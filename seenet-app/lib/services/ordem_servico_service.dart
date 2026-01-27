import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/ordem_servico_model.dart';
import 'package:get/get.dart';
import 'package:seenet/services/auth_service.dart';

class OrdemServicoService {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  final AuthService _authService = Get.find<AuthService>();

  // Headers padrão com autenticação
  Map<String, String> get _headers {
    final token = _authService.token;
    final tenantCode = _authService.tenantCode;

    return {
      'Authorization': 'Bearer $token',
      'X-Tenant-Code': tenantCode ?? '',
      'Content-Type': 'application/json',
    };
  }

  // Buscar OSs do técnico logado (pendentes e em execução)
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

  // ✅ NOVO: Buscar OSs concluídas
  Future<List<OrdemServico>> buscarOSsConcluidas({String busca = '', int limite = 50}) async {
    try {
      final token = _authService.token;
      final tenantCode = _authService.tenantCode;

      if (token == null) throw Exception('Token não encontrado');
      if (tenantCode == null) throw Exception('Código da empresa não encontrado');

      // Montar URL com query params
      final uri = Uri.parse('$baseUrl/ordens-servico/concluidas').replace(
        queryParameters: {
          'limite': limite.toString(),
          if (busca.isNotEmpty) 'busca': busca,
        },
      );

      final response = await http.get(uri, headers: _headers);

      print('📥 buscarOSsConcluidas - Status: ${response.statusCode}');

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

  // Buscar detalhes de uma OS específica
  Future<OrdemServico> buscarDetalhesOS(String osId) async {
    try {
      final token = _authService.token;
      final tenantCode = _authService.tenantCode;

      if (token == null) throw Exception('Token não encontrado');
      if (tenantCode == null) throw Exception('Código da empresa não encontrado');

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

  // Iniciar execução da OS
  Future<bool> deslocarParaOS(String osId, double latitude, double longitude) async {
    try {
      final token = _authService.token;
      final tenantCode = _authService.tenantCode;

      if (token == null) throw Exception('Token não encontrado');
      if (tenantCode == null) throw Exception('Código da empresa não encontrado');

      final response = await http.post(
        Uri.parse('$baseUrl/ordens-servico/$osId/deslocar'),
        headers: _headers,
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      print('📥 deslocarParaOS - Status: ${response.statusCode}');

      return response.statusCode ==200;
    } catch (e) {
      print('❌ Erro em deslocarParaOS: $e');
      return false;
    }
  }

  // 2️⃣ Informar chegada ao local
  Future<bool> chegarAoLocal(String osId, double latitude, double longitude) async {
    try {
      final token = _authService.token;
      final tenantCode = _authService.tenantCode;

      if (token == null) throw Exception('Token não encontrado');
      if (tenantCode == null) throw Exception('Código da empresa não encontrado');

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

      // ✅ CONVERTER FOTOS PARA BASE64
      if (dados['fotos'] != null && (dados['fotos'] as List).isNotEmpty) {
        List<String> fotosBase64 = [];
        List<String> fotosPaths = List<String>.from(dados['fotos']);

        print('📸 Convertendo ${fotosPaths.length} foto(s) para base64...');

        for (String fotoPath in fotosPaths) {
          try {
            // Ler arquivo
            final File file = File(fotoPath);

            // Verificar se arquivo existe
            if (!await file.exists()) {
              print('⚠️ Arquivo não encontrado: $fotoPath');
              continue;
            }

            // Ler bytes
            final Uint8List bytes = await file.readAsBytes();

            // Converter para base64
            final String base64Image = base64Encode(bytes);
            fotosBase64.add(base64Image);

            print('✅ Foto convertida: ${fotoPath.split('/').last} (${(bytes.length / 1024).toStringAsFixed(2)} KB)');
          } catch (e) {
            print('❌ Erro ao converter foto $fotoPath: $e');
          }
        }

        // Substituir paths por base64
        dados['fotos'] = fotosBase64;
        print('📤 ${fotosBase64.length} foto(s) prontas para envio');
      }

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