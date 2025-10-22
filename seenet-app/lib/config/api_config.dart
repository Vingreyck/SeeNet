import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  // ✅ SEMPRE usar Railway em produção ou variável .env
  static String get baseUrl =>
      dotenv.env['API_URL'] ?? 'https://seenet-production.up.railway.app';
  
  // ✅ MAPEAMENTO DE ENDPOINTS
  static final Map<String, String> endpoints = {
    // Health
    'health': '/health',
    
    // Auth
    'login': '/auth/login',
    'logout': '/auth/logout',
    'verify_token': '/auth/verify',
    
    // Tenant
    'tenant_verify': '/tenant/verify',
    
    // Checkmarks
    'checkmarks': '/checkmark',
    'checkmarks_create': '/checkmark',
    'checkmarks_update': '/checkmark',
    'checkmarks_delete': '/checkmark',
    'checkmarks_by_category': '/checkmark/categoria',
    
    // Categorias
    'categorias': '/checkmark/categorias',
    
    // Avaliações
    'avaliacoes': '/avaliacoes',
    'avaliacoes_create': '/avaliacoes',
    'avaliacoes_detail': '/avaliacoes',
    
    // ✅ DIAGNÓSTICOS - ENDPOINT CORRIGIDO
    'diagnostics_gerar': '/diagnostics/gerar',
    'diagnostics_list': '/diagnostics/avaliacao',
    'diagnostics_detail': '/diagnostics',
    
    // Transcrições
    'transcriptions': '/transcriptions',
    'transcriptions_detail': '/transcriptions',
    
    // Admin
    'admin_checkmarks': '/admin/checkmarks',
    'admin_categorias': '/admin/categorias',
  };
  
  // ✅ MÉTODO PARA MONTAR URL COMPLETA
  static String getUrl(String endpoint) {
    // If endpoint key was passed (like 'health'), resolve to path
    final resolved = endpoints.containsKey(endpoint) ? endpoints[endpoint]! : endpoint;

    // If the endpoint already includes /api at start, attach directly
    if (resolved.startsWith('/api/')) {
      return baseUrl + resolved;
    }

    // If starts with '/', add /api prefix
    if (resolved.startsWith('/')) {
      return '$baseUrl/api$resolved';
    }

    // Otherwise add /api/ between
    return '$baseUrl/api/$resolved';
  }
  
  // Headers padrão
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };
  
  // Headers com autenticação
  static Map<String, String> getAuthHeaders(String token, String tenantCode) {
    return {
      ...defaultHeaders,
      'Authorization': 'Bearer $token',
      'X-Tenant-Code': tenantCode,
    };
  }
  
  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  // Configurações de retry
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // ✅ MÉTODO DE DEBUG
  static void printConfig() {
    print('\n🔧 === CONFIGURAÇÃO DA API ===');
    print('� Base URL: $baseUrl');
    print('⏱️  Request Timeout: ${requestTimeout.inSeconds}s');
    print('🔄 Max Retries: $maxRetries');
    print('\n📋 Endpoints mapeados:');
    endpoints.forEach((key, value) {
      final fullUrl = getUrl(value);
      print('   $key → $fullUrl');
    });
    print('================================\n');
  }
  
  // ✅ TESTE DE CONECTIVIDADE
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: defaultHeaders,
      ).timeout(connectionTimeout);
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erro ao testar conexão: $e');
      return false;
    }
  }
  
  // ✅ MÉTODO AUXILIAR PARA CONSTRUIR URL COM QUERY PARAMS
  static String buildUrlWithParams(String endpoint, Map<String, String> params) {
    final url = getUrl(endpoint);
    if (params.isEmpty) return url;
    
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return '$url?$queryString';
  }
  
  // ✅ VALIDAR CONFIGURAÇÃO
  static bool validateConfig() {
    if (baseUrl.isEmpty) {
      print('❌ ERRO: Base URL não configurada!');
      return false;
    }
    
    if (!baseUrl.startsWith('http')) {
      print('❌ ERRO: Base URL deve começar com http:// ou https://');
      return false;
    }
    
    print('✅ Configuração válida');
    return true;
  }
}