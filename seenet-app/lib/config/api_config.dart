import 'environment.dart';

class ApiConfig {
  // ✅ CORRIGIDO: Usar Environment.apiBaseUrl (que lê do .env)
  static String get baseUrl => Environment.apiBaseUrl;
  
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
    
    // ✅ ADMIN - USANDO OS ENDPOINTS QUE JÁ EXISTEM NO AUTH.JS
    'adminUsers': '/auth/debug/usuarios',              // Listar usuários
    'adminUserEdit': '/auth/usuarios',                 // Editar: PUT /auth/usuarios/:id
    'adminUserResetPassword': '/auth/usuarios',        // Resetar: PUT /auth/usuarios/:id/resetar-senha
    'adminUserStatus': '/auth/usuarios',               // Status: PUT /auth/usuarios/:id/status
    'adminUserDelete': '/auth/usuarios',               // Deletar: DELETE /auth/usuarios/:id
    
    // CHECKMARKS
    'categorias': '/checkmark/categorias',
    'checkmarksPorCategoria': '/checkmark/categoria',
    'criarCategoria': '/checkmark/categorias',
    'criarCheckmark': '/checkmark/checkmark',
    
    // AVALIAÇÕES
    'criarAvaliacao': '/avaliacoes',
    'finalizarAvaliacao': '/avaliacoes',
    'minhasAvaliacoes': '/avaliacoes/minhas',
    'verAvaliacao': '/avaliacoes',
    'salvarRespostas': '/avaliacoes',
    
    // Diagnósticos
    'gerarDiagnostico': '/diagnostics/gerar',
    'listarDiagnosticos': '/diagnostics/avaliacao',
    'verDiagnostico': '/diagnostics',
    
    // Transcrições
    'transcricoes': '/transcriptions',
    'minhasTranscricoes': '/transcriptions/minhas',
    'statsTranscricoes': '/transcriptions/stats/resumo',
    
    // Admin
    'adminStats': '/admin/stats',
    'adminLogs': '/admin/logs',
    
    // Auditoria
    'auditLog': '/admin/logs',
    'auditLogs': '/admin/logs',
    'auditStats': '/admin/stats',
    'auditStatsQuick': '/admin/stats/quick',
    'auditExport': '/admin/logs/export',
    'auditCleanup': '/admin/logs/cleanup',
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
    print('🌐 === CONFIGURAÇÃO DA API ===');
    print('📡 Base URL: $baseUrl');
    print('🏗️ Ambiente: ${Environment.isProduction ? "PRODUÇÃO" : "DESENVOLVIMENTO"}');
    print('⏰ Timeout: ${requestTimeout.inSeconds}s');
    print('📊 Total endpoints: ${endpoints.length}');
    print('🔍 Endpoints de Auditoria: ${endpoints.keys.where((k) => k.startsWith('audit')).length}');
    print('================================\n');
  }
}