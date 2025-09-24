// lib/services/database_helper_postgres.dart - VERSÃO CORRETA 2.4.6
import 'package:postgres/postgres.dart';
import '../models/usuario.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../models/resposta_checkmark.dart';
import '../models/diagnostico.dart';
import '../models/transcricao_tecnica.dart';
import '../config/database_config_postgres.dart';
import '../config/environment.dart';
import 'security_service.dart';
import 'audit_service.dart';

class DatabaseHelperPostgreSQL {
  static PostgreSQLConnection? _connection;
  
  DatabaseHelperPostgreSQL._privateConstructor();
  static final DatabaseHelperPostgreSQL instance = DatabaseHelperPostgreSQL._privateConstructor();
  
  Future<PostgreSQLConnection> get connection async {
    if (_connection != null && !_connection!.isClosed) {
      return _connection!;
    }
    _connection = await _initConnection();
    return _connection!;
  }
  
  Future<PostgreSQLConnection> _initConnection() async {
    try {
      PostgreSQLConfig.printConfig();
      
      final conn = PostgreSQLConnection(
        PostgreSQLConfig.host,
        PostgreSQLConfig.port,
        PostgreSQLConfig.database,
        username: PostgreSQLConfig.username,
        password: PostgreSQLConfig.password,
        timeoutInSeconds: 30,
        queryTimeoutInSeconds: 30,
        useSSL: PostgreSQLConfig.useSSL,
      );
      
      await conn.open();
      
      print('PostgreSQL conectado: ${PostgreSQLConfig.host}:${PostgreSQLConfig.port}/${PostgreSQLConfig.database}');
      return conn;
    } catch (e) {
      print('Erro ao conectar PostgreSQL: $e');
      rethrow;
    }
  }
  
  Future<Usuario?> loginUsuario(String email, String senha) async {
    try {
      email = SecurityService.sanitizeInput(email.toLowerCase().trim());
      
      if (!SecurityService.checkRateLimit(email, maxAttempts: Environment.maxLoginAttempts)) {
        await AuditService.instance.logLogin(
          email: email,
          sucesso: false,
          motivo: 'Rate limit excedido',
        );
        throw Exception('Muitas tentativas de login. Tente novamente em 15 minutos.');
      }
      
      final conn = await connection;
      
      final result = await conn.query(
        'SELECT * FROM usuarios WHERE email = @email AND ativo = true',
        substitutionValues: {'email': email},
      );
      
      if (result.isEmpty) {
        await AuditService.instance.logLogin(
          email: email,
          sucesso: false,
          motivo: 'Usuário não encontrado',
        );
        return null;
      }
      
      final userData = result.first.toColumnMap();
      final storedPassword = userData['senha'] as String;
      
      bool passwordValid = SecurityService.verifyPassword(senha, storedPassword);
      
      if (passwordValid) {
        SecurityService.clearRateLimit(email);
        
        await conn.query(
          '''UPDATE usuarios SET 
             ultimo_login = CURRENT_TIMESTAMP,
             tentativas_login = 0,
             data_atualizacao = CURRENT_TIMESTAMP
             WHERE id = @id''',
          substitutionValues: {'id': userData['id']},
        );
        
        await AuditService.instance.logLogin(
          email: email,
          sucesso: true,
          usuarioId: userData['id'] as int,
        );
        
        return Usuario.fromMap(userData);
      } else {
        await conn.query(
          'UPDATE usuarios SET tentativas_login = tentativas_login + 1 WHERE id = @id',
          substitutionValues: {'id': userData['id']},
        );
        
        await AuditService.instance.logLogin(
          email: email,
          sucesso: false,
          usuarioId: userData['id'] as int,
          motivo: 'Senha incorreta',
        );
        
        return null;
      }
    } catch (e) {
      print('Erro no login PostgreSQL: $e');
      rethrow;
    }
  }
  
  Future<bool> criarUsuario(Usuario usuario) async {
    try {
      final conn = await connection;
      
      final result = await conn.query(
        '''INSERT INTO usuarios (nome, email, senha, tipo_usuario, ativo) 
           VALUES (@nome, @email, @senha, @tipo_usuario, @ativo)
           RETURNING id''',
        substitutionValues: {
          'nome': usuario.nome,
          'email': usuario.email.toLowerCase(),
          'senha': SecurityService.hashPassword(usuario.senha),
          'tipo_usuario': usuario.tipoUsuario,
          'ativo': usuario.ativo,
        },
      );
      
      final id = result.first.first as int;
      
      await AuditService.instance.logUserChange(
        operacao: 'create',
        usuarioId: id,
        operadorId: null,
        dadosNovos: {
          'nome': usuario.nome,
          'email': usuario.email,
          'tipo_usuario': usuario.tipoUsuario,
        },
      );
      
      print('Usuário criado PostgreSQL: ${usuario.email}');
      return true;
    } catch (e) {
      print('Erro criar usuário PostgreSQL: $e');
      return false;
    }
  }
  
  Future<List<CategoriaCheckmark>> getCategorias() async {
    try {
      final conn = await connection;
      
      final result = await conn.query(
        'SELECT * FROM categorias_checkmark WHERE ativo = true ORDER BY ordem',
      );
      
      List<CategoriaCheckmark> categorias = result
          .map((row) => CategoriaCheckmark.fromMap(row.toColumnMap()))
          .toList();
      
      print('${categorias.length} categorias carregadas do PostgreSQL');
      return categorias;
    } catch (e) {
      print('Erro buscar categorias PostgreSQL: $e');
      return [];
    }
  }
  
  Future<List<Checkmark>> getCheckmarksPorCategoria(int categoriaId) async {
    try {
      final conn = await connection;
      
      final result = await conn.query(
        '''SELECT * FROM checkmarks 
           WHERE categoria_id = @categoria_id AND ativo = true 
           ORDER BY ordem''',
        substitutionValues: {'categoria_id': categoriaId},
      );
      
      List<Checkmark> checkmarks = result
          .map((row) => Checkmark.fromMap(row.toColumnMap()))
          .toList();
      
      print('${checkmarks.length} checkmarks carregados do PostgreSQL');
      return checkmarks;
    } catch (e) {
      print('Erro buscar checkmarks PostgreSQL: $e');
      return [];
    }
  }
  
  Future<int?> criarAvaliacao(Avaliacao avaliacao) async {
    try {
      final conn = await connection;
      
      final result = await conn.query(
        '''INSERT INTO avaliacoes (tecnico_id, titulo, descricao, status) 
           VALUES (@tecnico_id, @titulo, @descricao, @status)
           RETURNING id''',
        substitutionValues: {
          'tecnico_id': avaliacao.tecnicoId,
          'titulo': avaliacao.titulo,
          'descricao': avaliacao.descricao,
          'status': avaliacao.status,
        },
      );
      
      final id = result.first.first as int;
      print('Avaliação criada PostgreSQL: $id');
      return id;
    } catch (e) {
      print('Erro criar avaliação PostgreSQL: $e');
      return null;
    }
  }
  
  Future<bool> finalizarAvaliacao(int avaliacaoId) async {
    try {
      final conn = await connection;
      
      await conn.query(
        '''UPDATE avaliacoes SET 
           status = 'concluida',
           data_conclusao = CURRENT_TIMESTAMP
           WHERE id = @id''',
        substitutionValues: {'id': avaliacaoId},
      );
      
      print('Avaliação finalizada PostgreSQL: $avaliacaoId');
      return true;
    } catch (e) {
      print('Erro finalizar avaliação PostgreSQL: $e');
      return false;
    }
  }
  
  Future<bool> salvarResposta(RespostaCheckmark resposta) async {
    try {
      final conn = await connection;
      
      final existing = await conn.query(
        'SELECT id FROM respostas_checkmark WHERE avaliacao_id = @avaliacao_id AND checkmark_id = @checkmark_id',
        substitutionValues: {
          'avaliacao_id': resposta.avaliacaoId,
          'checkmark_id': resposta.checkmarkId,
        },
      );
      
      if (existing.isNotEmpty) {
        await conn.query(
          '''UPDATE respostas_checkmark SET 
             marcado = @marcado,
             observacoes = @observacoes,
             data_resposta = CURRENT_TIMESTAMP
             WHERE avaliacao_id = @avaliacao_id AND checkmark_id = @checkmark_id''',
          substitutionValues: {
            'avaliacao_id': resposta.avaliacaoId,
            'checkmark_id': resposta.checkmarkId,
            'marcado': resposta.marcado,
            'observacoes': resposta.observacoes,
          },
        );
      } else {
        await conn.query(
          '''INSERT INTO respostas_checkmark (avaliacao_id, checkmark_id, marcado, observacoes) 
             VALUES (@avaliacao_id, @checkmark_id, @marcado, @observacoes)''',
          substitutionValues: {
            'avaliacao_id': resposta.avaliacaoId,
            'checkmark_id': resposta.checkmarkId,
            'marcado': resposta.marcado,
            'observacoes': resposta.observacoes,
          },
        );
      }
      
      print('Resposta salva PostgreSQL: checkmark ${resposta.checkmarkId} = ${resposta.marcado}');
      return true;
    } catch (e) {
      print('Erro salvar resposta PostgreSQL: $e');
      return false;
    }
  }
  
  Future<bool> salvarDiagnostico(Diagnostico diagnostico) async {
    try {
      final conn = await connection;
      
      await conn.query(
        '''INSERT INTO diagnosticos (
             avaliacao_id, categoria_id, prompt_enviado, resposta_chatgpt,
             resumo_diagnostico, status_api, tokens_utilizados
           ) VALUES (@avaliacao_id, @categoria_id, @prompt_enviado, @resposta_chatgpt,
                     @resumo_diagnostico, @status_api, @tokens_utilizados)''',
        substitutionValues: {
          'avaliacao_id': diagnostico.avaliacaoId,
          'categoria_id': diagnostico.categoriaId,
          'prompt_enviado': diagnostico.promptEnviado,
          'resposta_chatgpt': diagnostico.respostaChatgpt,
          'resumo_diagnostico': diagnostico.resumoDiagnostico,
          'status_api': diagnostico.statusApi,
          'tokens_utilizados': diagnostico.tokensUtilizados,
        },
      );
      
      print('Diagnóstico salvo PostgreSQL');
      return true;
    } catch (e) {
      print('Erro salvar diagnóstico PostgreSQL: $e');
      return false;
    }
  }
  
  Future<List<Diagnostico>> getDiagnosticosPorAvaliacao(int avaliacaoId) async {
    try {
      final conn = await connection;
      
      final result = await conn.query(
        '''SELECT * FROM diagnosticos 
           WHERE avaliacao_id = @avaliacao_id 
           ORDER BY data_criacao DESC''',
        substitutionValues: {'avaliacao_id': avaliacaoId},
      );
      
      List<Diagnostico> diagnosticos = result
          .map((row) => Diagnostico.fromMap(row.toColumnMap()))
          .toList();
      
      print('${diagnosticos.length} diagnósticos carregados PostgreSQL');
      return diagnosticos;
    } catch (e) {
      print('Erro buscar diagnósticos PostgreSQL: $e');
      return [];
    }
  }
  
  Future<bool> salvarTranscricao(TranscricaoTecnica transcricao) async {
    try {
      final conn = await connection;
      
      await conn.query(
        '''INSERT INTO transcricoes_tecnicas (
             tecnico_id, titulo, descricao, transcricao_original, pontos_da_acao,
             status, duracao_segundos, categoria_problema, cliente_info,
             data_inicio, data_conclusao
           ) VALUES (@tecnico_id, @titulo, @descricao, @transcricao_original, @pontos_da_acao,
                     @status, @duracao_segundos, @categoria_problema, @cliente_info,
                     @data_inicio, @data_conclusao)''',
        substitutionValues: {
          'tecnico_id': transcricao.tecnicoId,
          'titulo': transcricao.titulo,
          'descricao': transcricao.descricao,
          'transcricao_original': transcricao.transcricaoOriginal,
          'pontos_da_acao': transcricao.pontosDaAcao,
          'status': transcricao.status,
          'duracao_segundos': transcricao.duracaoSegundos,
          'categoria_problema': transcricao.categoriaProblema,
          'cliente_info': transcricao.clienteInfo,
          'data_inicio': transcricao.dataInicio?.toIso8601String(),
          'data_conclusao': transcricao.dataConclusao?.toIso8601String(),
        },
      );
      
      await AuditService.instance.log(
        action: AuditAction.documentCreated,
        usuarioId: transcricao.tecnicoId,
        tabelaAfetada: 'transcricoes_tecnicas',
        detalhes: 'Documentação criada: ${transcricao.titulo}',
      );
      
      print('Transcrição salva PostgreSQL: ${transcricao.titulo}');
      return true;
    } catch (e) {
      print('Erro salvar transcrição PostgreSQL: $e');
      return false;
    }
  }
  
  Future<List<TranscricaoTecnica>> getTranscricoesPorTecnico(int tecnicoId) async {
    try {
      final conn = await connection;
      
      final result = await conn.query(
        '''SELECT * FROM transcricoes_tecnicas 
           WHERE tecnico_id = @tecnico_id 
           ORDER BY data_criacao DESC''',
        substitutionValues: {'tecnico_id': tecnicoId},
      );
      
      List<TranscricaoTecnica> transcricoes = result
          .map((row) => TranscricaoTecnica.fromMap(row.toColumnMap()))
          .toList();
      
      print('${transcricoes.length} transcrições carregadas PostgreSQL');
      return transcricoes;
    } catch (e) {
      print('Erro buscar transcrições PostgreSQL: $e');
      return [];
    }
  }
  
  Future<bool> testarConexao() async {
    try {
      final conn = await connection;
      
      final result = await conn.query('SELECT 1 as test');
      
      if (result.isNotEmpty) {
        print('PostgreSQL funcionando perfeitamente');
        return true;
      }
      return false;
    } catch (e) {
      print('Erro no teste PostgreSQL: $e');
      return false;
    }
  }
  
  Future<void> verificarEstrutura() async {
    try {
      final conn = await connection;
      
      final usuarios = await conn.query('SELECT COUNT(*) FROM usuarios');
      print('Usuários no PostgreSQL: ${usuarios.first.first}');
      
      final categorias = await conn.query('SELECT COUNT(*) FROM categorias_checkmark');
      print('Categorias no PostgreSQL: ${categorias.first.first}');
      
      final checkmarks = await conn.query('SELECT COUNT(*) FROM checkmarks');
      print('Checkmarks no PostgreSQL: ${checkmarks.first.first}');
      
      final transcricoes = await conn.query('SELECT COUNT(*) FROM transcricoes_tecnicas');
      print('Transcrições no PostgreSQL: ${transcricoes.first.first}');
      
    } catch (e) {
      print('Erro ao verificar estrutura PostgreSQL: $e');
    }
  }
  
  Future<void> logoutUsuario(int usuarioId) async {
    try {
      await AuditService.instance.log(
        action: AuditAction.logout,
        usuarioId: usuarioId,
        detalhes: 'Logout realizado',
      );
      
      print('Logout registrado PostgreSQL para usuário: $usuarioId');
    } catch (e) {
      print('Erro ao registrar logout PostgreSQL: $e');
    }
  }
  
  Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
      _connection = null;
      print('Conexão PostgreSQL fechada');
    }
  }
}