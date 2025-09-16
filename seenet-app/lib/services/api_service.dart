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
  
  // GET
Future<Map<String, dynamic>> get(
  String endpoint, {
  Map<String, String>? queryParams,
  bool requireAuth = true,
}) async {
  try {
    String url;
    
    // Se o endpoint começar com '/', usar diretamente
    if (endpoint.startsWith('/')) {
      url = '${ApiConfig.baseUrl.replaceAll('/api', '')}$endpoint';
    } else {
      // Senão, procurar na lista de endpoints
      url = ApiConfig.getUrl(ApiConfig.endpoints[endpoint] ?? endpoint);
    }
    
    if (queryParams != null && queryParams.isNotEmpty) {
      url += '?${queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&')}';
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
      String url = ApiConfig.getUrl(ApiConfig.endpoints[endpoint] ?? endpoint);
      
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
      String url = ApiConfig.getUrl(ApiConfig.endpoints[endpoint] ?? endpoint);
      
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
      String url = ApiConfig.getUrl(ApiConfig.endpoints[endpoint] ?? endpoint);
      
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
    // Usar URL direta para health check
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    final url = '$baseUrl/health';
    
    print('🌐 Health Check: $url');
    
    final response = await _client
        .get(
          Uri.parse(url),
          headers: ApiConfig.defaultHeaders,
        )
        .timeout(const Duration(seconds: 10));
    
    print('📡 Health Status: ${response.statusCode}');
    print('📄 Health Response: ${response.body}');
    
    return response.statusCode == 200;
  } catch (e) {
    print('❌ Health Check Error: $e');
    return false;
  }
}
  
  // Debug - testar todas as URLs
  Future<void> debugEndpoints() async {
    if (!Environment.enableDebugLogs) return;
    
    print('🧪 === TESTE DE ENDPOINTS ===');
    
    // Testar health check
    try {
      bool health = await checkConnectivity();
      print('🏥 Health check: ${health ? "OK" : "FALHOU"}');
    } catch (e) {
      print('🏥 Health check: ERRO - $e');
    }
    
    print('================================\n');
  }
}