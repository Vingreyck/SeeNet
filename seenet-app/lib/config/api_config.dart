import 'environment.dart';

class ApiConfig {
  // URLs ambiente
  static const String _devBaseUrl = 'http://10.0.0.6:3000/api'; // desenvolvimento local
  static const String _prodBaseUrl = 'https://seenet-production.up.railway.app/api'; // ✅ ATUALIZADO
  
  // URL atual baseado no ambiente
  static String get baseUrl {
    return Environment.isDevelopment ? _devBaseUrl : _prodBaseUrl;
  }
  
  // Endpoints 
  static const Map<String, String> endpoints = {
    // Health
    'health': '/health',

    // Autenticação
    'login': '/auth/login',
    'register': '/auth/register',
    'verify': '/auth/verify',
    'logout': '/auth/logout',

    // Tenant
    'verifyTenant': '/tenant/verify',
    
    // Usuários
    'users': '/users',
    'profile': '/users/profile',
    
    // Checkmarks
    'categorias': '/checkmarks/categorias',
    'checkmarksPorCategoria': '/checkmarks/categoria',
    'criarCategoria': '/checkmarks/categorias',
    'criarCheckmark': '/checkmarks/checkmarks',
    
    // Diagnósticos
    'gerarDiagnostico': '/diagnostics/gerar',
    'listarDiagnosticos': '/diagnostics/avaliacao',
    'verDiagnostico': '/diagnostics',
    
    // Transcrições
    'transcricoes': '/transcriptions',
    'minhasTranscricoes': '/transcriptions/minhas',
    'statsTranscricoes': '/transcriptions/stats/resumo',
    
    // Admin
    'adminUsers': '/admin/users',
    'adminStats': '/admin/stats',
    'adminLogs': '/admin/logs',
  };
  
  // Headers padrão
  static Map<String, String> get defaultHeaders {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  
  // Headers com autenticação
  static Map<String, String> getAuthHeaders(String token, String tenantCode) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Tenant-Code': tenantCode,
    };
  }
  
  // Timeout das requisições
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);
  
  // URLs completas
  static String getUrl(String endpoint) => '$baseUrl$endpoint';
  
  // Debug - mostrar configuração
  static void printConfig() {
    if (!Environment.enableDebugLogs) return;
    
    print('🌐 === CONFIGURAÇÃO DA API ===');
    print('📡 Base URL: $baseUrl');
    print('🏗️ Ambiente: ${Environment.isDevelopment ? "DEV" : "PROD"}');
    print('⏰ Timeout: ${requestTimeout.inSeconds}s');
    print('📊 Total endpoints: ${endpoints.length}');
    if (Environment.isDevelopment) {
      print('🤖 Emulador Android: 10.0.2.2');
      print('📱 Dispositivo físico: Ajuste o IP em _devBaseUrl');
    }
    print('================================\n');
  }
}