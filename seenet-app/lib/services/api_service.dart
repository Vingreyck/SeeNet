import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (!kIsWeb) ApiConfig.printConfig();
  }

  String? get token => _token;
  String? get tenantCode => _tenantCode;
  
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
  
  // ✅ HEADERS CORRIGIDOS COM LOGS
  Map<String, String> _getHeaders({bool requireAuth = true}) {
    print('\n🔍 === MONTANDO HEADERS ===');
    print('   Requer autenticação: $requireAuth');
    
    if (requireAuth) {
      print('   Token: ${_token != null ? "PRESENTE (${_token!.length} chars)" : "AUSENTE"}');
      print('   Tenant Code: ${_tenantCode ?? "AUSENTE"}');
      
      if (_token == null || _tenantCode == null) {
        print('❌ ERRO: Autenticação necessária mas token/tenant ausente!');
        throw Exception('Autenticação necessária - Token ou código da empresa não configurado');
      }
      
      final headers = ApiConfig.getAuthHeaders(_token!, _tenantCode!);
      print('✅ Headers com autenticação montados:');
      headers.forEach((key, value) {
        if (key == 'Authorization') {
          print('   $key: Bearer ${value.substring(7, 17)}...');
        } else {
          print('   $key: $value');
        }
      });
      return headers;
    } else {
      print('✅ Headers sem autenticação');
      return ApiConfig.defaultHeaders;
    }
  }
  
  // GET
  Future<dynamic> get(
      String endpoint, {
        Map<String, String>? queryParams,
        bool requireAuth = true,
        Duration? timeout,
      }) async {
    try {
      String url = ApiConfig.getUrl(ApiConfig.endpoints[endpoint] ?? endpoint);
      
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
          .timeout(timeout ?? ApiConfig.requestTimeout);
      
      return _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }
  
  // ✅ POST CORRIGIDO COM LOGS EXTENSIVOS
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    try {
      print('\n🚀 === INICIANDO POST REQUEST ===');
      print('📍 Endpoint recebido: $endpoint');
      
      // ✅ CORREÇÃO CRÍTICA: Garantir que o endpoint está correto
      String fullEndpoint = ApiConfig.endpoints[endpoint] ?? endpoint;
      print('📍 Endpoint processado: $fullEndpoint');
      
      String url = ApiConfig.getUrl(fullEndpoint);
      print('🌐 URL completa: $url');
      
      // ✅ SEMPRE mostrar o body (não apenas em debug)
      print('📦 Body da requisição:');
      print(json.encode(data));
      
      print('🔐 Autenticação requerida: $requireAuth');
      
      final headers = _getHeaders(requireAuth: requireAuth);
      
      print('📤 Enviando requisição HTTP POST...');
      
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(data),
          )
          .timeout(
            ApiConfig.requestTimeout,
            onTimeout: () {
              print('⏱️ TIMEOUT: Servidor não respondeu em ${ApiConfig.requestTimeout.inSeconds}s');
              throw Exception('Timeout na requisição');
            },
          );
      
      print('📥 Resposta recebida do servidor');
      
      return _handleResponse(response);
    } catch (e) {
      print('❌ EXCEÇÃO no POST: $e');
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
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    try {
      String url = ApiConfig.getUrl(ApiConfig.endpoints[endpoint] ?? endpoint);
      
      if (queryParams != null && queryParams.isNotEmpty) {
        url += '?' + queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }
      
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
  
// ✅ TRATAR RESPOSTA COM LOGS DETALHADOS - VERSÃO CORRIGIDA
dynamic _handleResponse(http.Response response) {
  print('\n=== PROCESSANDO RESPOSTA ===');
  print('Status Code: ${response.statusCode}');
  print('Body length: ${response.body.length} bytes');
  
  if (response.body.isEmpty) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true};
    } else {
      return {
        'success': false,
        'error': 'Resposta vazia com status ${response.statusCode}',
        'statusCode': response.statusCode
      };
    }
  }
  
  try {
    dynamic decoded = json.decode(response.body);
    
    // Normalizar estrutura de resposta
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('SUCESSO: ${response.statusCode}');
      
      // Se já está no formato correto
      if (decoded is Map && decoded.containsKey('success')) {
        // Se tem data aninhada desnecessariamente, desaninh
        if (decoded['data'] is Map && 
            decoded['data'].containsKey('success') && 
            decoded['data'].containsKey('data')) {
          print('Estrutura dupla detectada, corrigindo...');
          return {
            'success': true,
            'data': decoded['data']['data']
          };
        }
        return decoded;
      }
      
      // Se é lista ou dados diretos, encapsular
      return {
        'success': true,
        'data': decoded
      };
    } else {
  print('❌ Resposta de erro detectada');
  
  Map<String, dynamic> errorData = decoded is Map<String, dynamic> 
      ? decoded 
      : {'error': decoded.toString()};
  
  // ✅ ADICIONAR LOG DO QUE O BACKEND ENVIOU
  print('📦 ErrorData recebido do backend: $errorData');
  print('🔍 Type no errorData: ${errorData['type']}');
  print('🔍 Error no errorData: ${errorData['error']}');
  
  return {
    'success': false,
    'error': errorData['error'] ?? 'Erro no servidor',
    'type': errorData['type'],  // ← ADICIONAR ESTA LINHA!
    'details': errorData['details'],
    'statusCode': response.statusCode
  };
}
  } catch (e) {
    print('ERRO ao decodificar JSON: $e');
    
    return {
      'success': false,
      'error': 'Erro ao processar resposta do servidor',
      'statusCode': response.statusCode,
      'rawBody': response.body,
      'parseError': e.toString()
    };
  }
}
  
  // ✅ TRATAR ERRO COM LOGS DETALHADOS
  Map<String, dynamic> _handleError(dynamic error) {
    print('\n❌ === ERRO NA REQUISIÇÃO ===');
    print('   Tipo: ${error.runtimeType}');
    print('   Mensagem: $error');

    final errorStr = error.toString();

    // ✅ kIsWeb não tem SocketException/HttpException — verificação por string funciona nos dois
    if (!kIsWeb && errorStr.contains('SocketException') || errorStr.contains('Failed host lookup')) {
      print('   Categoria: Sem conexão com internet');
      return {'success': false, 'error': 'Sem conexão com a internet', 'type': 'connection', 'details': errorStr};
    }

    if (!kIsWeb && errorStr.contains('HttpException')) {
      print('   Categoria: Erro HTTP');
      return {'success': false, 'error': 'Erro de conexão com o servidor', 'type': 'http', 'details': errorStr};
    }

    if (errorStr.contains('TimeoutException') || errorStr.contains('Timeout')) {
      print('   Categoria: Timeout');
      return {'success': false, 'error': 'Tempo limite da requisição excedido', 'type': 'timeout', 'details': errorStr};
    }

    return {'success': false, 'error': errorStr, 'type': 'unknown', 'details': errorStr};
  }
  
  // Verificar conectividade
  Future<bool> checkConnectivity() async {
    try {
      final response = await get('/health', requireAuth: false);
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }
  
  // ✅ DEBUG MELHORADO
  Future<void> debugEndpoints() async {
    print('\n🧪 === TESTE DE ENDPOINTS ===');
    print('📍 Base URL: ${ApiConfig.baseUrl}');
    print('🔐 Token: ${_token != null ? "Configurado" : "NÃO configurado"}');
    print('🏢 Tenant: ${_tenantCode ?? "NÃO configurado"}');
    
    // Testar health check
    try {
      print('\n🏥 Testando health check...');
      bool health = await checkConnectivity();
      print('🏥 Health check: ${health ? "✅ OK" : "❌ FALHOU"}');
    } catch (e) {
      print('🏥 Health check: ❌ ERRO - $e');
    }
    
    // Testar montagem de URL do diagnóstico
    try {
      print('\n🧪 Testando montagem de URL de diagnóstico...');
      String diagnosticEndpoint = ApiConfig.endpoints['diagnostics_gerar'] ?? '/diagnostics/gerar';
      String diagnosticUrl = ApiConfig.getUrl(diagnosticEndpoint);
      print('   Endpoint: $diagnosticEndpoint');
      print('   URL completa: $diagnosticUrl');
    } catch (e) {
      print('❌ Erro ao montar URL: $e');
    }
    
    print('\n================================\n');
  }
}