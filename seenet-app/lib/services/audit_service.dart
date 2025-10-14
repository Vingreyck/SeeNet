// lib/services/audit_service.dart - VERSÃO API COMPLETA E CORRIGIDA
import 'package:get/get.dart';
import 'api_service.dart';

/// Tipos de ações para auditoria
enum AuditAction {
  // Autenticação
  login('LOGIN', 'info'),
  loginFailed('LOGIN_FAILED', 'warning'),
  logout('LOGOUT', 'info'),
  
  // Usuários
  userCreated('USER_CREATED', 'info'),
  userUpdated('USER_UPDATED', 'info'),
  userDeleted('USER_DELETED', 'warning'),
  userActivated('USER_ACTIVATED', 'info'),
  userDeactivated('USER_DEACTIVATED', 'warning'),
  passwordChanged('PASSWORD_CHANGED', 'warning'),
  passwordReset('PASSWORD_RESET', 'warning'),
  
  // Checkmarks
  checkmarkCreated('CHECKMARK_CREATED', 'info'),
  checkmarkUpdated('CHECKMARK_UPDATED', 'info'),
  checkmarkDeleted('CHECKMARK_DELETED', 'warning'),
  
  // Categorias
  categoryCreated('CATEGORY_CREATED', 'info'),
  categoryUpdated('CATEGORY_UPDATED', 'info'),
  categoryDeleted('CATEGORY_DELETED', 'warning'),
  
  // Avaliações
  evaluationStarted('EVALUATION_STARTED', 'info'),
  evaluationCompleted('EVALUATION_COMPLETED', 'info'),
  evaluationCancelled('EVALUATION_CANCELLED', 'warning'),
  
  // Diagnósticos
  diagnosticGenerated('DIAGNOSTIC_GENERATED', 'info'),
  diagnosticFailed('DIAGNOSTIC_FAILED', 'error'),
  
  // Documentação
  documentCreated('DOCUMENT_CREATED', 'info'),
  documentUpdated('DOCUMENT_UPDATED', 'info'),
  documentDeleted('DOCUMENT_DELETED', 'warning'),
  transcriptionStarted('TRANSCRIPTION_STARTED', 'info'),
  transcriptionCompleted('TRANSCRIPTION_COMPLETED', 'info'),
  transcriptionFailed('TRANSCRIPTION_FAILED', 'error'),
  
  // Sistema
  dataExported('DATA_EXPORTED', 'info'),
  dataImported('DATA_IMPORTED', 'warning'),
  configChanged('CONFIG_CHANGED', 'warning'),
  unauthorizedAccess('UNAUTHORIZED_ACCESS', 'error'),
  suspiciousActivity('SUSPICIOUS_ACTIVITY', 'error');

  const AuditAction(this.code, this.level);
  final String code;
  final String level;
}

/// Serviço de Auditoria via API
class AuditService extends GetxService {
  final ApiService _api = ApiService.instance;
  
  // Singleton
  static AuditService? _instance;
  static AuditService get instance => _instance ??= AuditService._();
  AuditService._();
  
  /// Registrar log de auditoria na API
  Future<void> log({
    required AuditAction action,
    int? usuarioId,
    String? tabelaAfetada,
    int? registroId,
    Map<String, dynamic>? dadosAnteriores,
    Map<String, dynamic>? dadosNovos,
    String? detalhes,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      // Sanitizar dados sensíveis
      if (dadosAnteriores != null) {
        dadosAnteriores = _sanitizarDadosSensiveis(dadosAnteriores);
      }
      
      if (dadosNovos != null) {
        dadosNovos = _sanitizarDadosSensiveis(dadosNovos);
      }
      
      // Enviar para API
      final response = await _api.post('/admin/logs', {
        'usuario_id': usuarioId,
        'acao': action.code,
        'nivel': action.level,
        'tabela_afetada': tabelaAfetada,
        'registro_id': registroId,
        'dados_anteriores': dadosAnteriores,
        'dados_novos': dadosNovos,
        'detalhes': detalhes,
        'ip_address': ipAddress ?? 'N/A',
        'user_agent': userAgent ?? 'Flutter App',
      });
      
      if (response['success']) {
        _logConsole(action, usuarioId, detalhes);
      } else {
        print('⚠️ Falha ao registrar auditoria: ${response['error']}');
      }
      
    } catch (e) {
      print('⚠️ Erro ao registrar log: $e');
    }
  }
  
  /// Registrar tentativa de login
  Future<void> logLogin({
    required String email,
    required bool sucesso,
    int? usuarioId,
    String? motivo,
    String? ipAddress,
  }) async {
    await log(
      action: sucesso ? AuditAction.login : AuditAction.loginFailed,
      usuarioId: usuarioId,
      detalhes: sucesso 
          ? 'Login bem-sucedido para: ${_maskEmail(email)}'
          : 'Falha no login para: ${_maskEmail(email)}. Motivo: $motivo',
      ipAddress: ipAddress,
    );
  }
  
  /// Registrar mudança de senha
  Future<void> logPasswordChange({
    required int usuarioId,
    required String tipo,
    String? adminId,
  }) async {
    await log(
      action: tipo == 'reset' ? AuditAction.passwordReset : AuditAction.passwordChanged,
      usuarioId: usuarioId,
      detalhes: adminId != null 
          ? 'Senha resetada pelo admin ID: $adminId'
          : 'Usuário alterou própria senha',
    );
  }
  
  /// Registrar CRUD de usuários
  Future<void> logUserChange({
    required String operacao,
    required int? usuarioId,
    required int? operadorId,
    Map<String, dynamic>? dadosAnteriores,
    Map<String, dynamic>? dadosNovos,
  }) async {
    AuditAction action;
    switch (operacao) {
      case 'create':
        action = AuditAction.userCreated;
        break;
      case 'update':
        action = AuditAction.userUpdated;
        break;
      case 'delete':
        action = AuditAction.userDeleted;
        break;
      default:
        return;
    }
    
    await log(
      action: action,
      usuarioId: operadorId,
      tabelaAfetada: 'usuarios',
      registroId: usuarioId,
      dadosAnteriores: dadosAnteriores,
      dadosNovos: dadosNovos,
    );
  }
  
  /// Buscar logs da API com filtros
  Future<List<Map<String, dynamic>>> buscarLogs({
    int? usuarioId,
    String? acao,
    String? nivel,
    DateTime? dataInicio,
    DateTime? dataFim,
    int limite = 100,
    int offset = 0,
  }) async {
    try {
      // Construir URL com query string manualmente
      List<String> params = [];
      params.add('limite=$limite');
      params.add('offset=$offset');
      
      if (usuarioId != null) params.add('usuario_id=$usuarioId');
      if (acao != null) params.add('acao=$acao');
      if (nivel != null) params.add('nivel=$nivel');
      if (dataInicio != null) params.add('data_inicio=${dataInicio.toIso8601String()}');
      if (dataFim != null) params.add('data_fim=${dataFim.toIso8601String()}');
      
      String endpoint = '/admin/logs?${params.join('&')}';
      
      final response = await _api.get(endpoint);
      
      if (response['success']) {
        List<dynamic> logsData = response['data']['logs'] ?? [];
        return List<Map<String, dynamic>>.from(logsData);
      }
      
      print('⚠️ Erro ao buscar logs: ${response['error']}');
      return [];
    } catch (e) {
      print('❌ Erro ao buscar logs: $e');
      return [];
    }
  }
  
  /// Gerar relatório de auditoria via API
  Future<Map<String, dynamic>> gerarRelatorio({
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      List<String> params = [];
      
      if (dataInicio != null) params.add('data_inicio=${dataInicio.toIso8601String()}');
      if (dataFim != null) params.add('data_fim=${dataFim.toIso8601String()}');
      
      String endpoint = '/admin/stats';
      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }
      
      final response = await _api.get(endpoint);
      
      if (response['success']) {
        return response['data'];
      }
      
      return {'erro': response['error'] ?? 'Falha ao gerar relatório'};
    } catch (e) {
      print('❌ Erro ao gerar relatório: $e');
      return {'erro': e.toString()};
    }
  }
  
  /// Limpar logs antigos (via API)
  Future<void> limparLogsAntigos({int diasParaManter = 90}) async {
    try {
      String endpoint = '/admin/logs/cleanup?dias=$diasParaManter';
      
      final response = await _api.delete(endpoint);
      
      if (response['success']) {
        print('🧹 Logs antigos removidos');
        
        await log(
          action: AuditAction.dataExported,
          detalhes: 'Limpeza automática: logs com mais de $diasParaManter dias removidos',
        );
      }
    } catch (e) {
      print('❌ Erro ao limpar logs: $e');
    }
  }
  
  /// Exportar logs via API
  Future<String> exportarLogs({
    DateTime? dataInicio,
    DateTime? dataFim,
    String formato = 'json',
  }) async {
    try {
      List<String> params = [];
      params.add('formato=$formato');
      
      if (dataInicio != null) params.add('data_inicio=${dataInicio.toIso8601String()}');
      if (dataFim != null) params.add('data_fim=${dataFim.toIso8601String()}');
      
      String endpoint = '/admin/logs/export?${params.join('&')}';
      
      final response = await _api.get(endpoint);
      
      if (response['success']) {
        return response['data']['export'] ?? '';
      }
      
      return '';
    } catch (e) {
      print('❌ Erro ao exportar logs: $e');
      return '';
    }
  }
  
  /// Obter estatísticas rápidas
  Future<Map<String, dynamic>> getEstatisticasRapidas() async {
    try {
      final response = await _api.get('/admin/stats/quick');
      
      if (response['success']) {
        return response['data'];
      }
      
      return {'logs_24h': 0, 'acoes_criticas': 0};
    } catch (e) {
      print('❌ Erro ao obter estatísticas: $e');
      return {'logs_24h': 0, 'acoes_criticas': 0};
    }
  }
  
  // ===== MÉTODOS PRIVADOS =====
  
  /// Sanitizar dados sensíveis
  Map<String, dynamic> _sanitizarDadosSensiveis(Map<String, dynamic> dados) {
    Map<String, dynamic> dadosSanitizados = Map.from(dados);
    
    const camposSensiveis = ['senha', 'password', 'token', 'api_key', 'secret'];
    
    for (String campo in camposSensiveis) {
      if (dadosSanitizados.containsKey(campo)) {
        dadosSanitizados[campo] = '***REMOVIDO***';
      }
    }
    
    if (dadosSanitizados.containsKey('email')) {
      dadosSanitizados['email'] = _maskEmail(dadosSanitizados['email'].toString());
    }
    
    return dadosSanitizados;
  }
  
  /// Mascarar email
  String _maskEmail(String email) {
    if (email.length <= 4) return '***';
    
    
    int atIndex = email.indexOf('@');
    if (atIndex <= 0) return '***';
    
    String username = email.substring(0, atIndex);
    String domain = email.substring(atIndex);
    
    if (username.length <= 2) {
      return '***$domain';
    }
    
    return '${username.substring(0, 2)}***$domain';
  }
  
  /// Log no console
  void _logConsole(AuditAction action, int? usuarioId, String? detalhes) {
    String emoji;
    switch (action.level) {
      case 'error':
        emoji = '❌';
        break;
      case 'warning':
        emoji = '⚠️';
        break;
      default:
        emoji = '📝';
    }
    
    print('$emoji AUDIT [${action.code}] User: $usuarioId - $detalhes');
  }
  
  /// Info sobre o serviço
  Map<String, String> get infoServico {
    return {
      'Nome': 'Auditoria via API',
      'Modo': 'Produção (PostgreSQL/Railway)',
      'Storage': 'Banco remoto',
      'Status': 'Ativo',
    };
  }
  
  /// Debug info
  void debugInfo() {
    print('\n🔍 === AUDITORIA DEBUG ===');
    print('📡 Modo: API (Railway PostgreSQL)');
    print('🔐 Sanitização: Ativa');
    print('📊 Console logs: Ativo');
    print('============================\n');
  }
}