import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../config/api_config.dart';
import '../config/environment.dart';

class ApiService extends GetxService {
  static ApiService get instance => Get.find<ApiService>();
  
  late http.Client _client;
  String? _token;
  String? _tenantCode;
  
  @override
  void onInit() {
    super.onInit();
    _client = http.Client();
    ApiConfig.printConfig();
  }
  
  @override
  void onClose() {
    _client.close();
    super.onClose();
  }
  
  // Configurar autenticação
  void setAuth(String token, String tenantCode) {
    _token = token;
    _tenantCode = tenantCode;
    print('🔐 Autenticação configurada para tenant: $tenantCode');
  }
  
  // Limpar autenticação
  void clearAuth() {
    _token = null;
    _tenantCode = null;
    print('🚪 Autenticação limpa');
  }
  
  // Headers da requisição
  Map<String, String> _getHeaders({bool requireAuth = true}) {
    if (requireAuth && (_token == null || _tenantCode == null)) {
      throw Exception('Autenticação necessária - Token ou código da empresa não configurado');
    }
    
    return requireAuth 
        ? ApiConfig.getAuthHeaders(_token!, _tenantCode!)
        : ApiConfig.defaultHeaders;
  }
  
  // ✅ RESOLVER ENDPOINT - VERSÃO SIMPLIFICADA E FUNCIONAL
  String _resolveEndpoint(String endpoint) {
    print('🔍 Resolvendo endpoint: "$endpoint"');
    
    // 1. Se começa com '/', é um caminho completo direto
    if (endpoint.startsWith('/')) {
      final url = '${ApiConfig.baseUrl}$endpoint';
      print('   → Caminho direto: $url');
      return url;
    }
    
    // 2. Se contém '/', é chave/id (ex: "checkmarksPorCategoria/1")
    if (endpoint.contains('/')) {
      final parts = endpoint.split('/');
      final key = parts[0];
      final rest = parts.sublist(1).join('/');
      
      if (ApiConfig.endpoints.containsKey(key)) {
        final basePath = ApiConfig.endpoints[key]!;
        final url = '${ApiConfig.baseUrl}$basePath/$rest';
        print('   → Chave+ID: $key → $url');
        return url;
      } else {
        // Fallback: adicionar /api/ se não tiver
        final url = '${ApiConfig.baseUrl}/$endpoint';
        print('   ⚠️ Chave não encontrada: $key, usando: $url');
        return url;
      }
    }
    
    // 3. É uma chave simples (ex: "categorias")
    if (ApiConfig.endpoints.containsKey(endpoint)) {
      final path = ApiConfig.endpoints[endpoint]!;
      final url = '${ApiConfig.baseUrl}$path';
      print('   → Chave: $endpoint → $url');
      return url;
    }
    
    // 4. Fallback: tratar como caminho e adicionar /api/
    final url = '${ApiConfig.baseUrl}/$endpoint';
    print('   ⚠️ Endpoint não encontrado no mapa: $endpoint, usando: $url');
    return url;
  }
  
  // GET
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    try {
      String url = _resolveEndpoint(endpoint);
      
      if (queryParams != null && queryParams.isNotEmpty) {
        url += '?' + queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }
      
      print('🌐 GET: $url');
      
      final response = await _client
          .get(
            Uri.parse(url),
            headers: _getHeaders(requireAuth: requireAuth),
          )
          .timeout(ApiConfig.requestTimeout);
      
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }
  
  // POST
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    try {
      String url = _resolveEndpoint(endpoint);
      
      print('🌐 POST: $url');
      if (Environment.enableDebugLogs) {
        print('📄 Data: ${json.encode(data)}');
      }
      
      final response = await _client
          .post(
            Uri.parse(url),
            headers: _getHeaders(requireAuth: requireAuth),
            body: json.encode(data),
          )
          .timeout(ApiConfig.requestTimeout);
      
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }
  
  // PUT
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    try {
      String url = _resolveEndpoint(endpoint);
      
      print('🌐 PUT: $url');
      
      final response = await _client
          .put(
            Uri.parse(url),
            headers: _getHeaders(requireAuth: requireAuth),
            body: json.encode(data),
          )
          .timeout(ApiConfig.requestTimeout);
      
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }
  
  // DELETE
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    try {
      String url = _resolveEndpoint(endpoint);
      
      print('🌐 DELETE: $url');
      
      final response = await _client
          .delete(
            Uri.parse(url),
            headers: _getHeaders(requireAuth: requireAuth),
          )
          .timeout(ApiConfig.requestTimeout);
      
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }
  
  // Tratar resposta
  Map<String, dynamic> _handleResponse(http.Response response) {
    print('📡 Status: ${response.statusCode}');
    
    if (response.body.isEmpty) {
      return {'success': response.statusCode < 400};
    }
    
    try {
      Map<String, dynamic> data = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Sucesso: ${response.statusCode}');
        return {'success': true, 'data': data};
      } else {
        print('❌ Erro: ${response.statusCode} - ${data['error'] ?? 'Erro desconhecido'}');
        return {
          'success': false,
          'error': data['error'] ?? 'Erro no servidor',
          'details': data['details'],
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      print('❌ Erro ao decodificar resposta: $e');
      print('📄 Body: ${response.body}');
      return {
        'success': false,
        'error': 'Erro ao processar resposta do servidor',
        'statusCode': response.statusCode,
        'rawBody': response.body
      };
    }
  }
  
  // Tratar erro
  Map<String, dynamic> _handleError(dynamic error) {
    print('❌ Erro na requisição: $error');
    
    if (error is SocketException) {
      return {
        'success': false,
        'error': 'Sem conexão com a internet',
        'type': 'connection'
      };
    }
    
    if (error is HttpException) {
      return {
        'success': false,
        'error': 'Erro de conexão com o servidor',
        'type': 'http'
      };
    }
    
    if (error.toString().contains('TimeoutException')) {
      return {
        'success': false,
        'error': 'Tempo limite da requisição excedido',
        'type': 'timeout'
      };
    }
    
    return {
      'success': false,
      'error': error.toString(),
      'type': 'unknown'
    };
  }
  
  // Verificar conectividade
  Future<bool> checkConnectivity() async {
    try {
      final response = await get('health', requireAuth: false);
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }
  
  // Debug - testar todas as URLs
  Future<void> debugEndpoints() async {
    if (!Environment.enableDebugLogs) return;
    
    print('\n🧪 === TESTE DE ENDPOINTS ===');
    
    // Testar health check
    try {
      bool health = await checkConnectivity();
      print('🏥 Health check: ${health ? "OK" : "FALHOU"}');
    } catch (e) {
      print('🏥 Health check: ERRO - $e');
    }
    
    // Testar resolução de endpoints
    print('\n🔍 Testando resolução de endpoints:');
    final testes = {
      'categorias': '${ApiConfig.baseUrl}/checkmark/categorias',
      'checkmarksPorCategoria/1': '${ApiConfig.baseUrl}/checkmark/categoria/1',
      'criarAvaliacao': '${ApiConfig.baseUrl}/avaliacoes',
      '/checkmark/categorias': '${ApiConfig.baseUrl}/checkmark/categorias',
    };
    
    testes.forEach((input, expected) {
      final result = _resolveEndpoint(input);
      final status = result == expected ? '✅' : '❌';
      print('  $status "$input"');
      print('     Esperado: $expected');
      print('     Obtido:   $result');
      if (result != expected) {
        print('     ⚠️ DIVERGÊNCIA!');
      }
    });
    
    print('================================\n');
  }
}