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
    Map<String, String> queryParams = {
      'limite': limite.toString(),
      'offset': offset.toString(),
    };
    
    if (usuarioId != null) queryParams['usuario_id'] = usuarioId.toString();
    if (acao != null) queryParams['acao'] = acao;
    if (nivel != null) queryParams['nivel'] = nivel;
    if (dataInicio != null) queryParams['data_inicio'] = dataInicio.toIso8601String();
    if (dataFim != null) queryParams['data_conclusao'] = dataFim.toIso8601String();
    
    final response = await _api.get(
      '/admin/logs',
      queryParams: queryParams,
      requireAuth: true,
    );
    
    if (!response['success']) {
      String erro = response['error']?.toString() ?? 'Erro desconhecido';
      print('❌ Erro da API: $erro');
      
      if (erro.toLowerCase().contains('token') || 
          erro.toLowerCase().contains('autenticação') || 
          erro.toLowerCase().contains('autorização') ||
          erro.toLowerCase().contains('requerido')) {
        throw Exception('AUTH_ERROR: $erro');
      }
      
      throw Exception(erro);
    }
    
    // ✅ CORREÇÃO: A API retorna { success, data: { logs, total, ... } }
    // O ApiService já extrai 'data', mas a API está retornando outra camada
    
    dynamic apiResponse = response['data'];
    
    if (apiResponse == null) {
      print('⚠️ Resposta sem dados');
      return [];
    }
    
    // ✅ A resposta tem DUAS camadas de 'data':
    // response['data'] = { success: true, data: { logs: [...] } }
    // Precisamos acessar response['data']['data']['logs']
    
    dynamic innerData;
    
    if (apiResponse is Map) {
      // Se tem 'success' na resposta, pegar o 'data' interno
      if (apiResponse.containsKey('success') && apiResponse.containsKey('data')) {
        innerData = apiResponse['data'];
        print('📊 Estrutura: resposta com success/data duplo');
      } else if (apiResponse.containsKey('logs')) {
        innerData = apiResponse;
        print('📊 Estrutura: resposta direta com logs');
      } else {
        innerData = apiResponse;
      }
    } else {
      innerData = apiResponse;
    }
    
    // Agora extrair os logs
    List<dynamic> logsData = [];
    
    if (innerData is Map && innerData.containsKey('logs')) {
      logsData = innerData['logs'] ?? [];
      print('✅ ${logsData.length} logs encontrados!');
    } else if (innerData is List) {
      logsData = innerData;
      print('✅ ${logsData.length} logs encontrados (lista direta)!');
    } else {
      print('⚠️ Estrutura não reconhecida');
      print('🔍 innerData type: ${innerData.runtimeType}');
      print('🔍 innerData: $innerData');
      return [];
    }
    
    print('📊 ${logsData.length} logs carregados da API');
    return List<Map<String, dynamic>>.from(logsData);
    
  } on Exception catch (e) {
    String errorMsg = e.toString();
    print('❌ Erro ao buscar logs: $errorMsg');
    
    if (errorMsg.contains('AUTH_ERROR') || errorMsg.contains('Autenticação necessária')) {
      rethrow;
    }
    
    return [];
  } catch (e) {
    print('❌ Erro inesperado ao buscar logs: $e');
    print('🔍 Stack trace: ${StackTrace.current}');
    return [];
  }
}

/// Gerar relatório de auditoria via API
Future<Map<String, dynamic>> gerarRelatorio({
  DateTime? dataInicio,
  DateTime? dataFim,
}) async {
  try {
    Map<String, String> queryParams = {};
    
    if (dataInicio != null) queryParams['data_inicio'] = dataInicio.toIso8601String();
    if (dataFim != null) queryParams['data_conclusao'] = dataFim.toIso8601String();
    
    final response = await _api.get(
      '/admin/stats',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      requireAuth: true,
    );
    
    if (!response['success']) {
      String erro = response['error']?.toString() ?? 'Erro desconhecido';
      
      if (erro.toLowerCase().contains('token') || 
          erro.toLowerCase().contains('autenticação')) {
        throw Exception('AUTH_ERROR: $erro');
      }
      
      return {'erro': erro};
    }
    
    // ✅ CORREÇÃO: Cast explícito para Map<String, dynamic>
    dynamic apiResponse = response['data'];
    
    if (apiResponse == null) {
      return <String, dynamic>{};
    }
    
    // Verificar se tem camada dupla
    if (apiResponse is Map) {
      if (apiResponse.containsKey('success') && apiResponse.containsKey('data')) {
        var innerData = apiResponse['data'];
        return innerData is Map ? Map<String, dynamic>.from(innerData) : <String, dynamic>{};
      }
      return Map<String, dynamic>.from(apiResponse);
    }
    
    return <String, dynamic>{};
  } catch (e) {
    print('❌ Erro ao gerar relatório: $e');
    if (e.toString().contains('AUTH_ERROR')) {
      rethrow;
    }
    return {'erro': e.toString()};
  }
}

/// Obter estatísticas rápidas
Future<Map<String, dynamic>> getEstatisticasRapidas() async {
  try {
    final response = await _api.get(
      '/admin/stats/quick',
      requireAuth: true,
    );
    
    if (!response['success']) {
      String erro = response['error']?.toString() ?? 'Erro desconhecido';
      
      if (erro.toLowerCase().contains('token') || 
          erro.toLowerCase().contains('autenticação')) {
        throw Exception('AUTH_ERROR: $erro');
      }
      
      return {'logs_24h': 0, 'acoes_criticas': 0};
    }
    
    dynamic apiResponse = response['data'];
    
    if (apiResponse == null) {
      return {'logs_24h': 0, 'acoes_criticas': 0};
    }
    
    // Verificar se tem camada dupla de data
    dynamic innerData;
    
    if (apiResponse is Map) {
      if (apiResponse.containsKey('success') && apiResponse.containsKey('data')) {
        innerData = apiResponse['data'];
        print('📊 Stats Quick: estrutura com success/data duplo');
      } else {
        innerData = apiResponse;
        print('📊 Stats Quick: estrutura direta');
      }
    } else {
      innerData = apiResponse;
    }
    
    // ✅ CORREÇÃO: Garantir conversão para int
    if (innerData is Map) {
      var logs24h = innerData['logs_24h'] ?? innerData['logs24h'] ?? 0;
      var acoesCriticas = innerData['acoes_criticas'] ?? innerData['acoesCriticas'] ?? 0;
      
      return {
        'logs_24h': logs24h is int ? logs24h : (logs24h is String ? int.tryParse(logs24h) ?? 0 : 0),
        'acoes_criticas': acoesCriticas is int ? acoesCriticas : (acoesCriticas is String ? int.tryParse(acoesCriticas) ?? 0 : 0),
      };
    }
    
    return {'logs_24h': 0, 'acoes_criticas': 0};
    
  } catch (e) {
    print('❌ Erro ao obter estatísticas: $e');
    if (e.toString().contains('AUTH_ERROR')) {
      rethrow;
    }
    return {'logs_24h': 0, 'acoes_criticas': 0};
  }
}

/// Limpar logs antigos (via API)
Future<void> limparLogsAntigos({int diasParaManter = 90}) async {
  try {
    final response = await _api.delete(
      '/admin/logs/cleanup',
      queryParams: {'dias': diasParaManter.toString()},
      requireAuth: true,
    );
    
    if (response['success']) {
      print('🧹 Logs antigos removidos');
      
      await log(
        action: AuditAction.dataExported,
        detalhes: 'Limpeza automática: logs com mais de $diasParaManter dias removidos',
      );
    } else {
      throw Exception(response['error'] ?? 'Erro ao limpar logs');
    }
  } catch (e) {
    print('❌ Erro ao limpar logs: $e');
    rethrow;
  }
}

/// Exportar logs via API
Future<String> exportarLogs({
  DateTime? dataInicio,
  DateTime? dataFim,
  String formato = 'json',
}) async {
  try {
    Map<String, String> queryParams = {'formato': formato};
    
    if (dataInicio != null) queryParams['data_inicio'] = dataInicio.toIso8601String();
    if (dataFim != null) queryParams['data_conclusao'] = dataFim.toIso8601String();
    
    print('🔍 Exportando logs com params: $queryParams');
    
    final response = await _api.get(
      '/admin/logs/export',
      queryParams: queryParams,
      requireAuth: true,
    );
    
    print('🔍 Response success: ${response['success']}');
    print('🔍 Response data type: ${response['data'].runtimeType}');
    print('🔍 Response data: ${response['data']}');
    
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Erro ao exportar');
    }
    
    // Estrutura dupla de data
    dynamic apiResponse = response['data'];
    
    if (apiResponse == null) {
      print('⚠️ apiResponse é null');
      return '';
    }
    
    // Verificar se tem camada dupla
    dynamic innerData;
    
    if (apiResponse is Map) {
      if (apiResponse.containsKey('success') && apiResponse.containsKey('data')) {
        innerData = apiResponse['data'];
        print('📊 Estrutura com success/data duplo');
      } else {
        innerData = apiResponse;
        print('📊 Estrutura direta');
      }
    } else {
      innerData = apiResponse;
    }
    
    print('🔍 innerData type: ${innerData.runtimeType}');
    print('🔍 innerData: $innerData');
    
    // Extrair o export
    if (innerData is Map && innerData.containsKey('export')) {
      String result = innerData['export']?.toString() ?? '';
      print('✅ Retornando export: ${result.length} caracteres');
      return result;
    }
    
    // Se não tem 'export', tentar retornar o conteúdo direto
    if (innerData is String) {
      print('✅ Retornando innerData como String: ${innerData.length} caracteres');
      return innerData;
    }
    
    print('⚠️ Nenhum dado de export encontrado');
    return '';
    
  } catch (e) {
    print('❌ Erro ao exportar logs: $e');
    rethrow;
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