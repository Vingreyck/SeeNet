// lib/services/audit_service.dart
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../models/log_sistema.dart';
import 'database_helper.dart';
import 'security_service.dart';

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
  
  // Sistema
  dataExported('DATA_EXPORTED', 'info'),
  dataImported('DATA_IMPORTED', 'warning'),
  configChanged('CONFIG_CHANGED', 'warning'),
  unauthorizedAccess('UNAUTHORIZED_ACCESS', 'error'),
  suspiciousActivity('SUSPICIOUS_ACTIVITY', 'error');

  const AuditAction(this.code, this.level);
  final String code;
  final String level; // info, warning, error
}

/// Serviço de Auditoria e Logs
class AuditService {
  static const String _tableName = 'logs_sistema';
  
  // Singleton
  AuditService._();
  static final AuditService instance = AuditService._();
  
  /// Criar tabela de logs
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER,
        acao TEXT NOT NULL,
        nivel TEXT NOT NULL,
        tabela_afetada TEXT,
        registro_id INTEGER,
        dados_anteriores TEXT,
        dados_novos TEXT,
        ip_address TEXT,
        user_agent TEXT,
        detalhes TEXT,
        data_acao TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
      )
    ''');
    
    // Criar índices para performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_usuario ON $_tableName(usuario_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_acao ON $_tableName(acao)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_data ON $_tableName(data_acao)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_nivel ON $_tableName(nivel)');
  }
  
  /// Registrar log de auditoria
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
      final db = await DatabaseHelper.instance.database;
      
      // Preparar dados para JSON
      String? dadosAnterioresJson;
      String? dadosNovosJson;
      
      if (dadosAnteriores != null) {
        // Remover dados sensíveis antes de salvar
        dadosAnteriores = _sanitizarDadosSensiveis(dadosAnteriores);
        dadosAnterioresJson = json.encode(dadosAnteriores);
      }
      
      if (dadosNovos != null) {
        dadosNovos = _sanitizarDadosSensiveis(dadosNovos);
        dadosNovosJson = json.encode(dadosNovos);
      }
      
      await db.insert(_tableName, {
        'usuario_id': usuarioId,
        'acao': action.code,
        'nivel': action.level,
        'tabela_afetada': tabelaAfetada,
        'registro_id': registroId,
        'dados_anteriores': dadosAnterioresJson,
        'dados_novos': dadosNovosJson,
        'detalhes': detalhes,
        'ip_address': ipAddress ?? 'N/A',
        'user_agent': userAgent ?? 'Flutter App',
        'data_acao': DateTime.now().toIso8601String(),
      });
      
      // Log no console em desenvolvimento
      _logConsole(action, usuarioId, detalhes);
      
      // Verificar atividades suspeitas
      await _verificarAtividadeSuspeita(usuarioId, action);
      
    } catch (e) {
      print('❌ Erro ao registrar log de auditoria: $e');
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
          ? 'Login bem-sucedido para: ${SecurityService.maskSensitiveData(email)}'
          : 'Falha no login para: ${SecurityService.maskSensitiveData(email)}. Motivo: $motivo',
      ipAddress: ipAddress,
    );
  }
  
  /// Registrar mudança de senha
  Future<void> logPasswordChange({
    required int usuarioId,
    required String tipo, // 'change' ou 'reset'
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
    required String operacao, // create, update, delete
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
  
  /// Buscar logs com filtros
  Future<List<LogSistema>> buscarLogs({
    int? usuarioId,
    String? acao,
    String? nivel,
    DateTime? dataInicio,
    DateTime? dataFim,
    int limite = 100,
    int offset = 0,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      String query = 'SELECT * FROM $_tableName WHERE 1=1';
      List<dynamic> args = [];
      
      if (usuarioId != null) {
        query += ' AND usuario_id = ?';
        args.add(usuarioId);
      }
      
      if (acao != null) {
        query += ' AND acao = ?';
        args.add(acao);
      }
      
      if (nivel != null) {
        query += ' AND nivel = ?';
        args.add(nivel);
      }
      
      if (dataInicio != null) {
        query += ' AND data_acao >= ?';
        args.add(dataInicio.toIso8601String());
      }
      
      if (dataFim != null) {
        query += ' AND data_acao <= ?';
        args.add(dataFim.toIso8601String());
      }
      
      query += ' ORDER BY data_acao DESC LIMIT ? OFFSET ?';
      args.addAll([limite, offset]);
      
      List<Map<String, dynamic>> results = await db.rawQuery(query, args);
      
      return results.map((map) => LogSistema.fromMap(map)).toList();
      
    } catch (e) {
      print('❌ Erro ao buscar logs: $e');
      return [];
    }
  }
  
  /// Gerar relatório de auditoria
  Future<Map<String, dynamic>> gerarRelatorio({
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (dataInicio != null && dataFim != null) {
        whereClause = 'WHERE data_acao BETWEEN ? AND ?';
        whereArgs = [dataInicio.toIso8601String(), dataFim.toIso8601String()];
      }
      
      // Total por ação
      var totalPorAcao = await db.rawQuery('''
        SELECT acao, COUNT(*) as total 
        FROM $_tableName 
        $whereClause 
        GROUP BY acao 
        ORDER BY total DESC
      ''', whereArgs);
      
      // Total por nível
      var totalPorNivel = await db.rawQuery('''
        SELECT nivel, COUNT(*) as total 
        FROM $_tableName 
        $whereClause 
        GROUP BY nivel
      ''', whereArgs);
      
      // Usuários mais ativos
      var usuariosMaisAtivos = await db.rawQuery('''
        SELECT u.nome, u.email, COUNT(l.id) as total_acoes
        FROM $_tableName l
        LEFT JOIN usuarios u ON l.usuario_id = u.id
        $whereClause
        ${whereClause.isEmpty ? 'WHERE' : 'AND'} l.usuario_id IS NOT NULL
        GROUP BY l.usuario_id
        ORDER BY total_acoes DESC
        LIMIT 10
      ''', whereArgs);
      
      // Ações suspeitas
      var acoesSuspeitas = await db.rawQuery('''
        SELECT * FROM $_tableName 
        WHERE nivel IN ('warning', 'error')
        ${whereClause.isEmpty ? '' : 'AND'} $whereClause
        ORDER BY data_acao DESC
        LIMIT 50
      ''', whereArgs);
      
      return {
        'periodo': {
          'inicio': dataInicio?.toIso8601String() ?? 'Início',
          'fim': dataFim?.toIso8601String() ?? 'Agora',
        },
        'resumo': {
          'total_logs': totalPorAcao.fold(0, (sum, item) => sum + (item['total'] as int)),
          'por_acao': totalPorAcao,
          'por_nivel': totalPorNivel,
        },
        'usuarios_ativos': usuariosMaisAtivos,
        'acoes_suspeitas': acoesSuspeitas,
      };
      
    } catch (e) {
      print('❌ Erro ao gerar relatório: $e');
      return {};
    }
  }
  
  /// Limpar logs antigos
  Future<void> limparLogsAntigos({int diasParaManter = 90}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dataLimite = DateTime.now().subtract(Duration(days: diasParaManter));
      
      int deletados = await db.delete(
        _tableName,
        where: 'data_acao < ? AND nivel = ?',
        whereArgs: [dataLimite.toIso8601String(), 'info'],
      );
      
      await log(
        action: AuditAction.dataExported,
        detalhes: 'Limpeza automática: $deletados logs antigos removidos',
      );
      
      print('🧹 $deletados logs antigos removidos');
      
    } catch (e) {
      print('❌ Erro ao limpar logs: $e');
    }
  }
  
  /// Exportar logs para análise
  Future<String> exportarLogs({
    DateTime? dataInicio,
    DateTime? dataFim,
    String formato = 'json', // json ou csv
  }) async {
    try {
      List<LogSistema> logs = await buscarLogs(
        dataInicio: dataInicio,
        dataFim: dataFim,
        limite: 10000,
      );
      
      if (formato == 'csv') {
        // Cabeçalho CSV
        StringBuffer csv = StringBuffer();
        csv.writeln('ID,Usuario ID,Acao,Nivel,Tabela,Registro ID,Detalhes,IP,Data');
        
        // Dados
        for (var log in logs) {
          csv.writeln(
            '${log.id},'
            '${log.usuarioId ?? ""},'
            '"${log.acao}",'
            '"${log.nivel ?? ""}",'
            '"${log.tabelaAfetada ?? ""}",'
            '${log.registroId ?? ""},'
            '"${log.detalhes ?? ""}",'
            '"${log.ipAddress ?? ""}",'
            '"${log.dataAcao ?? ""}"'
          );
        }
        
        return csv.toString();
      } else {
        // JSON
        List<Map<String, dynamic>> jsonLogs = logs.map((l) => l.toMap()).toList();
        return json.encode(jsonLogs);
      }
      
    } catch (e) {
      print('❌ Erro ao exportar logs: $e');
      return '';
    }
  }
  
  // ===== MÉTODOS PRIVADOS =====
  
  /// Sanitizar dados sensíveis antes de salvar
  Map<String, dynamic> _sanitizarDadosSensiveis(Map<String, dynamic> dados) {
    Map<String, dynamic> dadosSanitizados = Map.from(dados);
    
    // Lista de campos sensíveis
    const camposSensiveis = ['senha', 'password', 'token', 'api_key', 'secret'];
    
    for (String campo in camposSensiveis) {
      if (dadosSanitizados.containsKey(campo)) {
        dadosSanitizados[campo] = '***REMOVIDO***';
      }
    }
    
    // Mascarar emails
    if (dadosSanitizados.containsKey('email')) {
      dadosSanitizados['email'] = SecurityService.maskSensitiveData(
        dadosSanitizados['email'].toString()
      );
    }
    
    return dadosSanitizados;
  }
  
  /// Log no console para desenvolvimento
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
  
  /// Verificar padrões suspeitos
  Future<void> _verificarAtividadeSuspeita(int? usuarioId, AuditAction action) async {
    if (usuarioId == null) return;
    
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Verificar múltiplas falhas de login
      if (action == AuditAction.loginFailed) {
        var falhas = await db.rawQuery('''
          SELECT COUNT(*) as total 
          FROM $_tableName 
          WHERE usuario_id = ? 
            AND acao = ? 
            AND data_acao > ?
        ''', [
          usuarioId,
          AuditAction.loginFailed.code,
          DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String()
        ]);
        
        int totalFalhas = falhas.first['total'] as int;
        if (totalFalhas >= 5) {
          await log(
            action: AuditAction.suspiciousActivity,
            usuarioId: usuarioId,
            detalhes: 'Múltiplas falhas de login detectadas: $totalFalhas tentativas em 15 minutos',
          );
        }
      }
      
      // Verificar ações administrativas fora do horário
      if (action.code.contains('DELETE') || action.code.contains('RESET')) {
        int hora = DateTime.now().hour;
        if (hora < 6 || hora > 22) {
          await log(
            action: AuditAction.suspiciousActivity,
            usuarioId: usuarioId,
            detalhes: 'Ação administrativa fora do horário comercial: ${action.code}',
          );
        }
      }
      
    } catch (e) {
      print('❌ Erro ao verificar atividade suspeita: $e');
    }
  }
  
  /// Obter estatísticas rápidas
  Future<Map<String, dynamic>> getEstatisticasRapidas() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Logs das últimas 24h
      var logs24h = await db.rawQuery('''
        SELECT COUNT(*) as total 
        FROM $_tableName 
        WHERE data_acao > ?
      ''', [DateTime.now().subtract(const Duration(hours: 24)).toIso8601String()]);
      
      // Ações críticas hoje
      var acoesCriticas = await db.rawQuery('''
        SELECT COUNT(*) as total 
        FROM $_tableName 
        WHERE nivel IN ('warning', 'error') 
          AND data_acao > ?
      ''', [DateTime.now().subtract(const Duration(hours: 24)).toIso8601String()]);
      
      return {
        'logs_24h': logs24h.first['total'],
        'acoes_criticas': acoesCriticas.first['total'],
      };
      
    } catch (e) {
      print('❌ Erro ao obter estatísticas: $e');
      return {'logs_24h': 0, 'acoes_criticas': 0};
    }
  }
}

// Extension para adicionar nível ao LogSistema
extension LogSistemaExtension on LogSistema {
  String? get nivel {
    // Extrair nível baseado na ação
    for (var action in AuditAction.values) {
      if (action.code == acao) {
        return action.level;
      }
    }
    return 'info';
  }
  
  String? get detalhes => dadosNovos; // Usar dadosNovos como detalhes temporariamente
}