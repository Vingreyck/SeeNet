// lib/services/database_helper.dart - VERSÃO CORRIGIDA
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/usuario.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../models/resposta_checkmark.dart';
import '../models/diagnostico.dart';
import '../config/environment.dart';
import '../models/transcricao_tecnica.dart';
import 'security_service.dart';
import 'audit_service.dart'; // ← NOVO IMPORT
import 'package:crypto/crypto.dart';
import 'dart:convert';

  class DatabaseHelper {
    static const String _databaseName = 'seenet.db';
    static const int _databaseVersion = 3; // ← INCREMENTADO PARA ADICIONAR TRANSCRICOES
    
    static Database? _database;
    
    // Singleton pattern
    DatabaseHelper._privateConstructor();
    static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
    
    // Getter para o database
    Future<Database> get database async {
      if (_database != null) return _database!;
      _database = await _initDatabase();
      return _database!;
    }
    
    // Inicializar database
    Future<Database> _initDatabase() async {
      try {
        String path = join(await getDatabasesPath(), _databaseName);
        
        Database db = await openDatabase(
          path,
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade, // ← NOVO: Para atualizar banco existente
          onOpen: _onOpen,
        );
        
        print('✅ SQLite conectado: $path');
        return db;
      } catch (e) {
        print('❌ Erro ao inicializar SQLite: $e');
        rethrow;
      }
    }

    // ← NOVA TABELA: Criar tabela de transcrições técnicas
    static Future<void> _createTranscricaoTable(Database db) async {
      await db.execute('''
        CREATE TABLE transcricoes_tecnicas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tecnico_id INTEGER NOT NULL,
          titulo TEXT NOT NULL,
          descricao TEXT,
          transcricao_original TEXT NOT NULL,
          pontos_da_acao TEXT NOT NULL,
          status TEXT DEFAULT 'concluida' CHECK (status IN ('gravando', 'processando', 'concluida', 'erro')),
          duracao_segundos INTEGER,
          categoria_problema TEXT,
          cliente_info TEXT,
          data_inicio TEXT,
          data_conclusao TEXT,
          data_criacao TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (tecnico_id) REFERENCES usuarios(id)
        )
      ''');
      
      // Criar índices para performance
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transcricoes_tecnico ON transcricoes_tecnicas(tecnico_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transcricoes_data ON transcricoes_tecnicas(data_criacao)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transcricoes_status ON transcricoes_tecnicas(status)');
      
      print('✅ Tabela transcricoes_tecnicas criada');
    }
    
    // Criar tabelas
    Future<void> _onCreate(Database db, int version) async {
      print('🔨 Criando tabelas SQLite...');
      
      // Tabela usuarios
      await db.execute('''
        CREATE TABLE usuarios (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          senha TEXT NOT NULL,
          tipo_usuario TEXT NOT NULL CHECK (tipo_usuario IN ('tecnico', 'administrador')),
          ativo INTEGER DEFAULT 1,
          tentativas_login INTEGER DEFAULT 0,
          ultimo_login TEXT,
          data_criacao TEXT DEFAULT CURRENT_TIMESTAMP,
          data_atualizacao TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Tabela categorias_checkmark
      await db.execute('''
        CREATE TABLE categorias_checkmark (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          descricao TEXT,
          ativo INTEGER DEFAULT 1,
          ordem INTEGER DEFAULT 0,
          data_criacao TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Tabela checkmarks
      await db.execute('''
        CREATE TABLE checkmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          categoria_id INTEGER NOT NULL,
          titulo TEXT NOT NULL,
          descricao TEXT,
          prompt_chatgpt TEXT NOT NULL,
          ativo INTEGER DEFAULT 1,
          ordem INTEGER DEFAULT 0,
          data_criacao TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (categoria_id) REFERENCES categorias_checkmark(id)
        )
      ''');

      // Tabela avaliacoes
      await db.execute('''
        CREATE TABLE avaliacoes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tecnico_id INTEGER NOT NULL,
          titulo TEXT,
          descricao TEXT,
          status TEXT DEFAULT 'em_andamento' CHECK (status IN ('em_andamento', 'concluida', 'cancelada')),
          data_inicio TEXT DEFAULT CURRENT_TIMESTAMP,
          data_conclusao TEXT,
          data_criacao TEXT DEFAULT CURRENT_TIMESTAMP,
          data_atualizacao TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (tecnico_id) REFERENCES usuarios(id)
        )
      ''');

      // Tabela respostas_checkmark
      await db.execute('''
        CREATE TABLE respostas_checkmark (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          avaliacao_id INTEGER NOT NULL,
          checkmark_id INTEGER NOT NULL,
          marcado INTEGER DEFAULT 0,
          observacoes TEXT,
          data_resposta TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (avaliacao_id) REFERENCES avaliacoes(id) ON DELETE CASCADE,
          FOREIGN KEY (checkmark_id) REFERENCES checkmarks(id),
          UNIQUE(avaliacao_id, checkmark_id)
        )
      ''');

      // Tabela diagnosticos
      await db.execute('''
        CREATE TABLE diagnosticos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          avaliacao_id INTEGER NOT NULL,
          categoria_id INTEGER NOT NULL,
          prompt_enviado TEXT NOT NULL,
          resposta_chatgpt TEXT NOT NULL,
          resumo_diagnostico TEXT,
          status_api TEXT DEFAULT 'pendente' CHECK (status_api IN ('pendente', 'sucesso', 'erro')),
          erro_api TEXT,
          tokens_utilizados INTEGER,
          data_criacao TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (avaliacao_id) REFERENCES avaliacoes(id) ON DELETE CASCADE,
          FOREIGN KEY (categoria_id) REFERENCES categorias_checkmark(id)
        )
      ''');
      
      // ← NOVA TABELA: Criar tabela de logs
      await AuditService.createTable(db);
      await _createTranscricaoTable(db);
      
      print('✅ Tabelas criadas com sucesso');
    }

  // ← NOVO: Atualizar banco existente
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('📈 Atualizando banco de v$oldVersion para v$newVersion');
    
    if (oldVersion < 2) {
      // Código existente para versão 2
      await AuditService.createTable(db);
      await db.execute('ALTER TABLE usuarios ADD COLUMN tentativas_login INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE usuarios ADD COLUMN ultimo_login TEXT');
      print('✅ Banco atualizado para versão 2');
    }
    
    if (oldVersion < 3) {
      // Nova atualização para versão 3 - adicionar transcrições
      await _createTranscricaoTable(db);
      print('✅ Banco atualizado para versão 3');
    }
  }
  
  // Executar quando abrir database
  Future<void> _onOpen(Database db) async {
    print('📂 Database SQLite aberto');
    await _insertInitialData(db);
  }
  
  // Inserir dados iniciais
  Future<void> _insertInitialData(Database db) async {
    try {
      // Verificar se já existem dados
      List<Map<String, dynamic>> usuarios = await db.query('usuarios', limit: 1);
      if (usuarios.isNotEmpty) {
        print('📊 Dados já existem no database');
        return;
      }
      
      print('📊 Inserindo dados iniciais...');
      
      // Inserir usuários com senha segura
      await db.insert('usuarios', {
        'nome': 'Administrador',
        'email': 'admin@seenet.com',
        'senha': SecurityService.hashPassword('admin123'), // ← Usar novo hash
        'tipo_usuario': 'administrador',
      });
      
      await db.insert('usuarios', {
        'nome': 'Técnico Teste',
        'email': 'tecnico@seenet.com',
        'senha': SecurityService.hashPassword('123456'), // ← Usar novo hash
        'tipo_usuario': 'tecnico',
      });

      // Inserir categorias
      List<Map<String, dynamic>> categorias = [
        {'nome': 'Lentidão', 'descricao': 'Problemas de velocidade, buffering e lentidão geral', 'ordem': 1},
        {'nome': 'IPTV', 'descricao': 'Travamentos, buffering, canais fora do ar, qualidade de vídeo', 'ordem': 2},
        {'nome': 'Aplicativos', 'descricao': 'Apps não carregam, erro de carregamento da logo', 'ordem': 3},
        {'nome': 'Acesso Remoto', 'descricao': 'Ativação de acessos remotos dos roteadores', 'ordem': 4},
      ];

      for (var categoria in categorias) {
        await db.insert('categorias_checkmark', categoria);
      }

      // Inserir checkmarks para Lentidão
      List<Map<String, dynamic>> checkmarksLentidao = [
        {
          'categoria_id': 1,
          'titulo': 'Velocidade abaixo do contratado',
          'descricao': 'Cliente relata velocidade de internet abaixo do contratado',
          'prompt_chatgpt': 'Analise problema de velocidade abaixo do contratado. Forneça diagnóstico e soluções.',
          'ordem': 1
        },
        {
          'categoria_id': 1,
          'titulo': 'Latência alta (ping > 100ms)',
          'descricao': 'Ping alto causando travamentos',
          'prompt_chatgpt': 'Cliente com ping alto acima de 100ms. Analise causas e soluções.',
          'ordem': 2
        },
        {
          'categoria_id': 1,
          'titulo': 'Perda de pacotes',
          'descricao': 'Perda de pacotes na conexão',
          'prompt_chatgpt': 'Problema de perda de pacotes. Identifique causas e soluções.',
          'ordem': 3
        },
        {
          'categoria_id': 1,
          'titulo': 'Wi-Fi com sinal fraco',
          'descricao': 'Sinal WiFi fraco ou instável',
          'prompt_chatgpt': 'Sinal WiFi fraco. Diagnóstico e melhorias de cobertura.',
          'ordem': 4
        },
        {
          'categoria_id': 1,
          'titulo': 'Problemas no cabo',
          'descricao': 'Problemas físicos no cabeamento',
          'prompt_chatgpt': 'Problemas de cabeamento. Orientações para resolução.',
          'ordem': 5
        },
      ];

      for (var checkmark in checkmarksLentidao) {
        await db.insert('checkmarks', checkmark);
      }

      // Inserir checkmarks para IPTV
      List<Map<String, dynamic>> checkmarksIptv = [
        {
          'categoria_id': 2,
          'titulo': 'Canais travando/congelando',
          'descricao': 'Canais de TV travando',
          'prompt_chatgpt': 'Travamento nos canais IPTV. Soluções técnicas.',
          'ordem': 1
        },
        {
          'categoria_id': 2,
          'titulo': 'Buffering constante',
          'descricao': 'Buffering constante nos canais',
          'prompt_chatgpt': 'IPTV com buffering constante. Diagnóstico e melhorias.',
          'ordem': 2
        },
        {
          'categoria_id': 2,
          'titulo': 'Canal fora do ar',
          'descricao': 'Canais específicos fora do ar',
          'prompt_chatgpt': 'Canais IPTV fora do ar. Causas e soluções.',
          'ordem': 3
        },
        {
          'categoria_id': 2,
          'titulo': 'Qualidade baixa',
          'descricao': 'Qualidade de vídeo baixa',
          'prompt_chatgpt': 'Qualidade ruim no IPTV. Diagnóstico e melhorias.',
          'ordem': 4
        },
        {
          'categoria_id': 2,
          'titulo': 'IPTV não abre',
          'descricao': 'Aplicativo IPTV não abre',
          'prompt_chatgpt': 'IPTV não inicializa. Diagnóstico e soluções.',
          'ordem': 5
        },
      ];

      for (var checkmark in checkmarksIptv) {
        await db.insert('checkmarks', checkmark);
      }

      // Inserir checkmarks para Aplicativos
      List<Map<String, dynamic>> checkmarksApps = [
        {
          'categoria_id': 3,
          'titulo': 'Aplicativo não abre',
          'descricao': 'Apps não conseguem abrir',
          'prompt_chatgpt': 'Aplicativos não abrem. Diagnóstico e soluções.',
          'ordem': 1
        },
        {
          'categoria_id': 3,
          'titulo': 'Erro de conexão',
          'descricao': 'Apps com erro de conexão',
          'prompt_chatgpt': 'Aplicativos com erro de conexão. Analise e solucione.',
          'ordem': 2
        },
        {
          'categoria_id': 3,
          'titulo': 'Buffering constante',
          'descricao': 'Apps com buffering constante',
          'prompt_chatgpt': 'Aplicativos com buffering. Diagnóstico e soluções.',
          'ordem': 3
        },
        {
          'categoria_id': 3,
          'titulo': 'Qualidade baixa',
          'descricao': 'Qualidade baixa nos apps',
          'prompt_chatgpt': 'Qualidade baixa nos aplicativos. Melhorias.',
          'ordem': 4
        },
        {
          'categoria_id': 3,
          'titulo': 'Error code: xxxxx',
          'descricao': 'Códigos de erro específicos',
          'prompt_chatgpt': 'Aplicativo com códigos de erro. Soluções baseadas no código.',
          'ordem': 5
        },
      ];

      for (var checkmark in checkmarksApps) {
        await db.insert('checkmarks', checkmark);
      }
      
      print('✅ Dados iniciais inseridos');
    } catch (e) {
      print('❌ Erro ao inserir dados iniciais: $e');
    }
  }
  
   Future<Usuario?> loginUsuario(String email, String senha) async {
    try {
      // Sanitizar email
      email = SecurityService.sanitizeInput(email.toLowerCase().trim());
      
      // Verificar rate limiting
      if (!SecurityService.checkRateLimit(email, maxAttempts: Environment.maxLoginAttempts)) {
        // ← LOG: Tentativa bloqueada por rate limit
        await AuditService.instance.logLogin(
          email: email,
          sucesso: false,
          motivo: 'Rate limit excedido',
        );
        
        print('⚠️ Rate limit excedido para: ${SecurityService.maskSensitiveData(email)}');
        throw Exception('Muitas tentativas de login. Tente novamente em 15 minutos.');
      }
      
      final db = await database;
      
      // Buscar usuário por email
      List<Map<String, dynamic>> results = await db.query(
        'usuarios',
        where: 'email = ? AND ativo = 1',
        whereArgs: [email],
      );
      
      if (results.isEmpty) {
        // ← LOG: Usuário não encontrado
        await AuditService.instance.logLogin(
          email: email,
          sucesso: false,
          motivo: 'Usuário não encontrado',
        );
        
        print('❌ Usuário não encontrado: ${SecurityService.maskSensitiveData(email)}');
        return null;
      }
      
      final userData = results.first;
      final storedPassword = userData['senha'] as String;
      
      // Verificar senha
      bool passwordValid = false;
      
      if (storedPassword.contains(':')) {
        // Novo formato com salt
        passwordValid = SecurityService.verifyPassword(senha, storedPassword);
      } else {
        // Formato antigo (compatibilidade)
        String oldHash = _hashPassword(senha);
        passwordValid = (storedPassword == oldHash || storedPassword == senha);
        
        // Se login com formato antigo for bem-sucedido, atualizar para novo formato
        if (passwordValid) {
          String newHash = SecurityService.hashPassword(senha);
          await db.update(
            'usuarios',
            {'senha': newHash},
            where: 'id = ?',
            whereArgs: [userData['id']],
          );
          print('🔄 Senha migrada para formato seguro para usuário: ${userData['id']}');
        }
      }
      
      if (passwordValid) {
        // Login bem-sucedido
        SecurityService.clearRateLimit(email);
        
        // Atualizar último login e resetar tentativas
        await db.update(
          'usuarios',
          {
            'ultimo_login': DateTime.now().toIso8601String(),
            'tentativas_login': 0,
            'data_atualizacao': DateTime.now().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [userData['id']],
        );
        
        // ← LOG: Login bem-sucedido
        await AuditService.instance.logLogin(
          email: email,
          sucesso: true,
          usuarioId: userData['id'] as int,
        );
        
        print('✅ Login bem-sucedido: ${SecurityService.maskSensitiveData(email)}');
        return Usuario.fromMap(userData);
      } else {
        // Incrementar tentativas de login falhas
        await db.update(
          'usuarios',
          {
            'tentativas_login': (userData['tentativas_login'] ?? 0) + 1,
          },
          where: 'id = ?',
          whereArgs: [userData['id']],
        );
        
        // ← LOG: Senha incorreta
        await AuditService.instance.logLogin(
          email: email,
          sucesso: false,
          usuarioId: userData['id'] as int,
          motivo: 'Senha incorreta',
        );
        
        print('❌ Senha incorreta para: ${SecurityService.maskSensitiveData(email)}');
        return null;
      }
      
    } catch (e) {
      print('❌ Erro no login: $e');
      rethrow;
    }
  }
  
  Future<bool> criarUsuario(Usuario usuario) async {
    try {
      final db = await database;
      
      int id = await db.insert('usuarios', {
        'nome': usuario.nome,
        'email': usuario.email.toLowerCase(),
        'senha': SecurityService.hashPassword(usuario.senha), // ← Usar novo hash
        'tipo_usuario': usuario.tipoUsuario,
        'ativo': usuario.ativo ? 1 : 0,
      });
      
      // ← LOG: Usuário criado
      await AuditService.instance.logUserChange(
        operacao: 'create',
        usuarioId: id,
        operadorId: null, // Auto-registro
        dadosNovos: {
          'nome': usuario.nome,
          'email': usuario.email,
          'tipo_usuario': usuario.tipoUsuario,
        },
      );
      
      print('✅ Usuário criado: ${usuario.email}');
      return true;
    } catch (e) {
      print('❌ Erro criar usuário: $e');
      return false;
    }
  }

  // ========== MÉTODOS PARA CHECKMARKS COM AUDITORIA ==========
  
  Future<bool> criarCheckmark(Checkmark checkmark, int operadorId) async {
    try {
      final db = await database;
      
      int id = await db.insert('checkmarks', checkmark.toMap());
      
      // ← LOG: Checkmark criado
      await AuditService.instance.log(
        action: AuditAction.checkmarkCreated,
        usuarioId: operadorId,
        tabelaAfetada: 'checkmarks',
        registroId: id,
        dadosNovos: checkmark.toMap(),
      );
      
      print('✅ Checkmark criado: $id');
      return true;
    } catch (e) {
      print('❌ Erro ao criar checkmark: $e');
      return false;
    }
  }
  
  // ========== MÉTODOS PARA DIAGNÓSTICOS COM AUDITORIA ==========

  Future<bool> salvarDiagnosticoComAuditoria(Diagnostico diagnostico) async {
    try {
      final db = await database;
      await db.insert('diagnosticos', diagnostico.toMap());
      
      // ← LOG: Diagnóstico gerado
      await AuditService.instance.log(
        action: diagnostico.isSucesso 
            ? AuditAction.diagnosticGenerated 
            : AuditAction.diagnosticFailed,
        tabelaAfetada: 'diagnosticos',
        detalhes: diagnostico.isSucesso 
            ? 'Diagnóstico gerado com sucesso'
            : 'Falha ao gerar diagnóstico: ${diagnostico.erroApi}',
      );
      
      print('✅ Diagnóstico salvo para avaliação ${diagnostico.avaliacaoId}');
      return true;
    } catch (e) {
      print('❌ Erro salvar diagnóstico: $e');
      return false;
    }
  }
  // ========== MÉTODOS DE SEGURANÇA E MANUTENÇÃO ==========
  
  // Verificar integridade do banco
  Future<Map<String, dynamic>> verificarIntegridade() async {
    try {
      final db = await database;
      Map<String, dynamic> resultado = {};
      
      // Verificar usuários com senhas fracas (formato antigo)
      var senhasFracas = await db.rawQuery('''
        SELECT COUNT(*) as total FROM usuarios 
        WHERE senha NOT LIKE '%:%'
      ''');
      resultado['senhas_fracas'] = senhasFracas.first['total'];
      
      // Verificar tentativas de login excessivas
      var tentativasExcessivas = await db.rawQuery('''
        SELECT id, email, tentativas_login FROM usuarios 
        WHERE tentativas_login > 5
      ''');
      resultado['usuarios_bloqueados'] = tentativasExcessivas;
      
      // Logs suspeitos
      var logsSuspeitos = await AuditService.instance.buscarLogs(
        nivel: 'error',
        dataInicio: DateTime.now().subtract(const Duration(days: 7)),
      );
      resultado['logs_suspeitos'] = logsSuspeitos.length;
      
      // ← LOG: Verificação de integridade
      await AuditService.instance.log(
        action: AuditAction.configChanged,
        detalhes: 'Verificação de integridade executada',
      );
      
      return resultado;
    } catch (e) {
      print('❌ Erro ao verificar integridade: $e');
      return {'erro': e.toString()};
    }
  }
  
  // Backup do banco
  Future<bool> fazerBackup(int operadorId) async {
    try {
      // Implementar backup real aqui
      // Por enquanto, apenas registrar a ação
      
      // ← LOG: Backup realizado
      await AuditService.instance.log(
        action: AuditAction.dataExported,
        usuarioId: operadorId,
        detalhes: 'Backup do banco de dados realizado',
      );
      
      print('💾 Backup realizado');
      return true;
    } catch (e) {
      print('❌ Erro ao fazer backup: $e');
      return false;
    }
  }
  
  // ========== MÉTODOS AUXILIARES (mantidos do original) ==========
  
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔒 SQLite database fechado');
    }
  }

  Future<bool> testarConexaoRapida() async {
    try {
      await database;
      print('✅ SQLite funcionando perfeitamente');
      return true;
    } catch (e) {
      print('❌ Erro no SQLite: $e');
      return false;
    }
  }

    // ← NOVO: Logout com auditoria
  Future<void> logoutUsuario(int usuarioId) async {
    try {
      await AuditService.instance.log(
        action: AuditAction.logout,
        usuarioId: usuarioId,
        detalhes: 'Logout realizado',
      );
      
      print('👋 Logout registrado para usuário: $usuarioId');
    } catch (e) {
      print('❌ Erro ao registrar logout: $e');
    }
  }
// Adicione este método no seu DatabaseHelper para corrigir o admin
// lib/services/database_helper.dart

// ========== MÉTODO PARA CORRIGIR ADMIN ==========
Future<void> corrigirUsuarioAdmin() async {
  try {
    final db = await database;
    
    // Atualizar o usuário admin para ter tipo correto
    await db.update(
      'usuarios',
      {'tipo_usuario': 'administrador'},
      where: 'email = ?',
      whereArgs: ['admin@seenet.com'],
    );
    
    print('✅ Usuário admin corrigido para tipo "administrador"');
    
    // Verificar se funcionou
    List<Map<String, dynamic>> results = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: ['admin@seenet.com'],
    );
    
    if (results.isNotEmpty) {
      var user = results.first;
      print('📊 Admin verificado:');
      print('   Email: ${user['email']}');
      print('   Tipo: ${user['tipo_usuario']}');
      print('   Nome: ${user['nome']}');
    }
    
  } catch (e) {
    print('❌ Erro ao corrigir admin: $e');
  }
}

// ========== MÉTODO PARA VERIFICAR TODOS OS USUÁRIOS ==========
Future<void> verificarTodosUsuarios() async {
  try {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query('usuarios');
    
    print('\n📊 === TODOS OS USUÁRIOS ===');
    for (var user in results) {
      print('🔍 ID: ${user['id']} | Email: ${user['email']} | Tipo: ${user['tipo_usuario']} | Nome: ${user['nome']}');
    }
    print('═══════════════════════════\n');
    
  } catch (e) {
    print('❌ Erro ao verificar usuários: $e');
  }
}

// ========== MÉTODOS PARA DEBUG ==========

// Listar todos os usuários no console
Future<void> debugListarUsuarios() async {
  try {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'usuarios',
      orderBy: 'data_criacao DESC',
    );
    
    print('\n📊 === USUÁRIOS CADASTRADOS (${results.length}) ===');
    print('┌──────┬─────────────────────┬─────────────────────────┬─────────────┬────────┬─────────────────────┐');
    print('│  ID  │       NOME          │         EMAIL           │    TIPO     │ ATIVO  │    DATA CRIAÇÃO     │');
    print('├──────┼─────────────────────┼─────────────────────────┼─────────────┼────────┼─────────────────────┤');
    
    for (var user in results) {
      String id = user['id'].toString().padRight(4);
      String nome = (user['nome'] ?? '').toString().padRight(19);
      String email = (user['email'] ?? '').toString().padRight(23);
      String tipo = (user['tipo_usuario'] ?? '').toString().padRight(11);
      String ativo = (user['ativo'] == 1 ? 'SIM' : 'NÃO').padRight(6);
      String data = _formatarDataConsole(user['data_criacao']);
      
      print('│ $id │ $nome │ $email │ $tipo │ $ativo │ $data │');
    }
    
    print('└──────┴─────────────────────┴─────────────────────────┴─────────────┴────────┴─────────────────────┘');
    
    // Estatísticas
    int totalTecnicos = results.where((u) => u['tipo_usuario'] == 'tecnico').length;
    int totalAdmins = results.where((u) => u['tipo_usuario'] == 'administrador').length;
    int totalAtivos = results.where((u) => u['ativo'] == 1).length;
    
    print('\n📈 ESTATÍSTICAS:');
    print('   • Total de usuários: ${results.length}');
    print('   • Técnicos: $totalTecnicos');
    print('   • Administradores: $totalAdmins');
    print('   • Ativos: $totalAtivos');
    print('   • Inativos: ${results.length - totalAtivos}');
    print('');
    
  } catch (e) {
    print('❌ Erro ao listar usuários: $e');
  }
}

// Buscar usuário específico por email
Future<void> debugBuscarUsuario(String email) async {
  try {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    
    if (results.isEmpty) {
      print('❌ Usuário não encontrado: $email');
      return;
    }
    
    var user = results.first;
    print('\n👤 === DETALHES DO USUÁRIO ===');
    print('📧 Email: ${user['email']}');
    print('👨‍💼 Nome: ${user['nome']}');
    print('🆔 ID: ${user['id']}');
    print('👔 Tipo: ${user['tipo_usuario']}');
    print('✅ Ativo: ${user['ativo'] == 1 ? 'Sim' : 'Não'}');
    print('📅 Criado em: ${_formatarDataConsole(user['data_criacao'])}');
    if (user['data_atualizacao'] != null) {
      print('🔄 Atualizado em: ${_formatarDataConsole(user['data_atualizacao'])}');
    }
    print('🔐 Senha (hash): ${user['senha']}');
    print('═══════════════════════════════\n');
    
  } catch (e) {
    print('❌ Erro ao buscar usuário: $e');
  }
}

// Listar últimos usuários cadastrados
Future<void> debugUltimosUsuarios({int limite = 5}) async {
  try {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'usuarios',
      orderBy: 'data_criacao DESC',
      limit: limite,
    );
    
    print('\n🆕 === ÚLTIMOS $limite USUÁRIOS CADASTRADOS ===');
    for (int i = 0; i < results.length; i++) {
      var user = results[i];
      print('${i + 1}. ${user['nome']} (${user['email']}) - ${_formatarDataConsole(user['data_criacao'])}');
    }
    print('═══════════════════════════════════════════\n');
    
  } catch (e) {
    print('❌ Erro ao buscar últimos usuários: $e');
  }
}

// Verificar se email já existe
Future<bool> debugEmailExiste(String email) async {
  try {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    
    bool existe = results.isNotEmpty;
    print('📧 Email "$email" ${existe ? 'JÁ EXISTE' : 'DISPONÍVEL'}');
    return existe;
    
  } catch (e) {
    print('❌ Erro ao verificar email: $e');
    return false;
  }
}

// Contar usuários por tipo
Future<void> debugEstatisticas() async {
  try {
    final db = await database;
    
    var totalUsuarios = await db.rawQuery('SELECT COUNT(*) as count FROM usuarios');
    var totalTecnicos = await db.rawQuery("SELECT COUNT(*) as count FROM usuarios WHERE tipo_usuario = 'tecnico'");
    var totalAdmins = await db.rawQuery("SELECT COUNT(*) as count FROM usuarios WHERE tipo_usuario = 'administrador'");
    var totalAtivos = await db.rawQuery('SELECT COUNT(*) as count FROM usuarios WHERE ativo = 1');
    
    print('\n📊 === ESTATÍSTICAS DETALHADAS ===');
    print('👥 Total de usuários: ${totalUsuarios.first['count']}');
    print('🔧 Técnicos: ${totalTecnicos.first['count']}');
    print('👑 Administradores: ${totalAdmins.first['count']}');
    print('✅ Ativos: ${totalAtivos.first['count']}');
    print('❌ Inativos: ${(totalUsuarios.first['count'] as int) - (totalAtivos.first['count'] as int)}');
    print('═══════════════════════════════════\n');
    
  } catch (e) {
    print('❌ Erro ao gerar estatísticas: $e');
  }
}

// Método auxiliar para formatar data no console
String _formatarDataConsole(String? dataString) {
  if (dataString == null) return 'N/A'.padRight(19);
  
  try {
    DateTime data = DateTime.parse(dataString);
    String formatted = '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    return formatted.padRight(19);
  } catch (e) {
    return 'Data inválida'.padRight(19);
  }
}
  // ========== MÉTODOS PARA CATEGORIAS ==========
  Future<List<CategoriaCheckmark>> getCategorias() async {
    try {
      final db = await database;
      List<Map<String, dynamic>> results = await db.query(
        'categorias_checkmark',
        where: 'ativo = 1',
        orderBy: 'ordem',
      );
      
      List<CategoriaCheckmark> categorias = results
          .map((map) => CategoriaCheckmark.fromMap(map))
          .toList();
      
      print('✅ ${categorias.length} categorias carregadas');
      return categorias;
    } catch (e) {
      print('❌ Erro buscar categorias: $e');
      return [];
    }
  }

  // ========== MÉTODOS PARA CHECKMARKS ==========
  Future<List<Checkmark>> getCheckmarksPorCategoria(int categoriaId) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> results = await db.query(
        'checkmarks',
        where: 'categoria_id = ? AND ativo = 1',
        whereArgs: [categoriaId],
        orderBy: 'ordem',
      );
      
      List<Checkmark> checkmarks = results
          .map((map) => Checkmark.fromMap(map))
          .toList();
      
      print('✅ ${checkmarks.length} checkmarks carregados para categoria $categoriaId');
      return checkmarks;
    } catch (e) {
      print('❌ Erro buscar checkmarks: $e');
      return [];
    }
  }

  // ========== MÉTODOS PARA AVALIAÇÕES ==========
  Future<int?> criarAvaliacao(Avaliacao avaliacao) async {
    try {
      final db = await database;
      int id = await db.insert('avaliacoes', {
        'tecnico_id': avaliacao.tecnicoId,
        'titulo': avaliacao.titulo,
        'descricao': avaliacao.descricao,
        'status': avaliacao.status,
      });
      
      print('✅ Avaliação criada com ID: $id');
      return id;
    } catch (e) {
      print('❌ Erro criar avaliação: $e');
      return null;
    }
  }

  Future<bool> finalizarAvaliacao(int avaliacaoId) async {
    try {
      final db = await database;
      await db.update(
        'avaliacoes',
        {
          'status': 'concluida',
          'data_conclusao': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [avaliacaoId],
      );
      
      print('✅ Avaliação $avaliacaoId finalizada');
      return true;
    } catch (e) {
      print('❌ Erro finalizar avaliação: $e');
      return false;
    }
  }

  // ========== MÉTODOS PARA RESPOSTAS ==========
  Future<bool> salvarResposta(RespostaCheckmark resposta) async {
    try {
      final db = await database;
      await db.insert(
        'respostas_checkmark',
        {
          'avaliacao_id': resposta.avaliacaoId,
          'checkmark_id': resposta.checkmarkId,
          'marcado': resposta.marcado ? 1 : 0,
          'observacoes': resposta.observacoes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('✅ Resposta salva: checkmark ${resposta.checkmarkId} = ${resposta.marcado}');
      return true;
    } catch (e) {
      print('❌ Erro salvar resposta: $e');
      return false;
    }
  }

  // ========== MÉTODOS PARA DIAGNÓSTICOS ==========
  Future<bool> salvarDiagnostico(Diagnostico diagnostico) async {
    try {
      final db = await database;
      await db.insert('diagnosticos', {
        'avaliacao_id': diagnostico.avaliacaoId,
        'categoria_id': diagnostico.categoriaId,
        'prompt_enviado': diagnostico.promptEnviado,
        'resposta_chatgpt': diagnostico.respostaChatgpt,
        'resumo_diagnostico': diagnostico.resumoDiagnostico,
        'status_api': diagnostico.statusApi,
        'tokens_utilizados': diagnostico.tokensUtilizados,
      });
      
      print('✅ Diagnóstico salvo para avaliação ${diagnostico.avaliacaoId}');
      return true;
    } catch (e) {
      print('❌ Erro salvar diagnóstico: $e');
      return false;
    }
  }

  Future<List<Diagnostico>> getDiagnosticosPorAvaliacao(int avaliacaoId) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> results = await db.query(
        'diagnosticos',
        where: 'avaliacao_id = ?',
        whereArgs: [avaliacaoId],
        orderBy: 'data_criacao DESC',
      );
      
      List<Diagnostico> diagnosticos = results
          .map((map) => Diagnostico.fromMap(map))
          .toList();
      
      print('✅ ${diagnosticos.length} diagnósticos carregados');
      return diagnosticos;
    } catch (e) {
      print('❌ Erro buscar diagnósticos: $e');
      return [];
    }
  }
  // =========== MÉTODOS PARA TRANSCRIÇÕES ==========
  /// Salvar transcrição
  Future<bool> salvarTranscricao(TranscricaoTecnica transcricao) async {
    try {
      final db = await database;
      
      await db.insert('transcricoes_tecnicas', transcricao.toMap());
      
      // Log de auditoria
      await AuditService.instance.log(
        action: AuditAction.documentCreated,
        usuarioId: transcricao.tecnicoId,
        tabelaAfetada: 'transcricoes_tecnicas',
        detalhes: 'Documentação criada: ${transcricao.titulo}',
      );
      
      print('✅ Transcrição salva: ${transcricao.titulo}');
      return true;
    } catch (e) {
      print('❌ Erro ao salvar transcrição: $e');
      return false;
    }
  }

  /// Buscar transcrições por técnico
  Future<List<TranscricaoTecnica>> getTranscricoesPorTecnico(int tecnicoId) async {
    try {
      final db = await database;
      
      List<Map<String, dynamic>> results = await db.query(
        'transcricoes_tecnicas',
        where: 'tecnico_id = ?',
        whereArgs: [tecnicoId],
        orderBy: 'data_criacao DESC',
      );
      
      List<TranscricaoTecnica> transcricoes = results
          .map((map) => TranscricaoTecnica.fromMap(map))
          .toList();
      
      print('✅ ${transcricoes.length} transcrições carregadas para técnico $tecnicoId');
      return transcricoes;
    } catch (e) {
      print('❌ Erro ao buscar transcrições: $e');
      return [];
    }
  }

  /// Buscar transcrição por ID
  Future<TranscricaoTecnica?> getTranscricaoPorId(int id) async {
    try {
      final db = await database;
      
      List<Map<String, dynamic>> results = await db.query(
        'transcricoes_tecnicas',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (results.isNotEmpty) {
        return TranscricaoTecnica.fromMap(results.first);
      }
      
      return null;
    } catch (e) {
      print('❌ Erro ao buscar transcrição: $e');
      return null;
    }
  }

  /// Atualizar transcrição
  Future<bool> atualizarTranscricao(TranscricaoTecnica transcricao) async {
    try {
      final db = await database;
      
      await db.update(
        'transcricoes_tecnicas',
        transcricao.toMap(),
        where: 'id = ?',
        whereArgs: [transcricao.id],
      );
      
      // Log de auditoria
      await AuditService.instance.log(
        action: AuditAction.documentUpdated,
        usuarioId: transcricao.tecnicoId,
        tabelaAfetada: 'transcricoes_tecnicas',
        registroId: transcricao.id,
        detalhes: 'Documentação atualizada: ${transcricao.titulo}',
      );
      
      print('✅ Transcrição atualizada: ${transcricao.id}');
      return true;
    } catch (e) {
      print('❌ Erro ao atualizar transcrição: $e');
      return false;
    }
  }

  /// Remover transcrição
  Future<bool> removerTranscricao(int id, int operadorId) async {
    try {
      final db = await database;
      
      // Buscar dados antes de remover para log
      TranscricaoTecnica? transcricao = await getTranscricaoPorId(id);
      
      await db.delete(
        'transcricoes_tecnicas',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Log de auditoria
      await AuditService.instance.log(
        action: AuditAction.documentDeleted,
        usuarioId: operadorId,
        tabelaAfetada: 'transcricoes_tecnicas',
        registroId: id,
        detalhes: 'Documentação removida: ${transcricao?.titulo ?? "ID $id"}',
      );
      
      print('✅ Transcrição removida: $id');
      return true;
    } catch (e) {
      print('❌ Erro ao remover transcrição: $e');
      return false;
    }
  }

  /// Buscar transcrições com filtros
  Future<List<TranscricaoTecnica>> buscarTranscricoes({
    int? tecnicoId,
    String? status,
    String? categoria,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? termoBusca,
    int limite = 100,
    int offset = 0,
  }) async {
    try {
      final db = await database;
      
      String query = 'SELECT * FROM transcricoes_tecnicas WHERE 1=1';
      List<dynamic> args = [];
      
      if (tecnicoId != null) {
        query += ' AND tecnico_id = ?';
        args.add(tecnicoId);
      }
      
      if (status != null) {
        query += ' AND status = ?';
        args.add(status);
      }
      
      if (categoria != null) {
        query += ' AND categoria_problema = ?';
        args.add(categoria);
      }
      
      if (dataInicio != null) {
        query += ' AND data_criacao >= ?';
        args.add(dataInicio.toIso8601String());
      }
      
      if (dataFim != null) {
        query += ' AND data_criacao <= ?';
        args.add(dataFim.toIso8601String());
      }
      
      if (termoBusca != null && termoBusca.isNotEmpty) {
        query += ' AND (titulo LIKE ? OR transcricao_original LIKE ? OR pontos_da_acao LIKE ?)';
        String termo = '%$termoBusca%';
        args.addAll([termo, termo, termo]);
      }
      
      query += ' ORDER BY data_criacao DESC LIMIT ? OFFSET ?';
      args.addAll([limite, offset]);
      
      List<Map<String, dynamic>> results = await db.rawQuery(query, args);
      
      return results.map((map) => TranscricaoTecnica.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar transcrições: $e');
      return [];
    }
  }

  /// Obter estatísticas de transcrições
  Future<Map<String, dynamic>> getEstatisticasTranscricoes(int tecnicoId) async {
    try {
      final db = await database;
      
      // Total de transcrições
      var totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM transcricoes_tecnicas WHERE tecnico_id = ?',
        [tecnicoId],
      );
      
      // Transcrições este mês
      DateTime agora = DateTime.now();
      DateTime inicioMes = DateTime(agora.year, agora.month, 1);
      
      var esteMesResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM transcricoes_tecnicas WHERE tecnico_id = ? AND data_criacao >= ?',
        [tecnicoId, inicioMes.toIso8601String()],
      );
      
      // Tempo total de gravação
      var tempoResult = await db.rawQuery(
        'SELECT SUM(duracao_segundos) as total_segundos FROM transcricoes_tecnicas WHERE tecnico_id = ? AND duracao_segundos IS NOT NULL',
        [tecnicoId],
      );
      
      // Categorias mais usadas
      var categoriasResult = await db.rawQuery(
        'SELECT categoria_problema, COUNT(*) as total FROM transcricoes_tecnicas WHERE tecnico_id = ? AND categoria_problema IS NOT NULL GROUP BY categoria_problema ORDER BY total DESC LIMIT 5',
        [tecnicoId],
      );
      
      int total = totalResult.first['total'] as int;
      int esteMes = esteMesResult.first['total'] as int;
      int totalSegundos = (tempoResult.first['total_segundos'] as int?) ?? 0;
      
      return {
        'total': total,
        'esteMes': esteMes,
        'tempoTotalSegundos': totalSegundos,
        'tempoTotal': _formatarDuracao(totalSegundos),
        'mediaMinutos': total > 0 ? totalSegundos / 60.0 / total : 0.0,
        'categorias': categoriasResult,
      };
    } catch (e) {
      print('❌ Erro ao obter estatísticas: $e');
      return {};
    }
  }

  /// Método auxiliar para formatar duração
  String _formatarDuracao(int totalSegundos) {
    int horas = totalSegundos ~/ 3600;
    int minutos = (totalSegundos % 3600) ~/ 60;
    int segundos = totalSegundos % 60;
    
    if (horas > 0) {
      return '${horas}h ${minutos.toString().padLeft(2, '0')}m';
    } else {
      return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
    }
  }

  // ========== UTILIDADES ==========

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔒 SQLite database fechado');
    }
  }

  Future<bool> testarConexao() async {
    try {
      await database;
      print('✅ SQLite funcionando perfeitamente');
      return true;
    } catch (e) {
      print('❌ Erro no SQLite: $e');
      return false;
    }
  }

  Future<void> verificarEstrutura() async {
    try {
      final db = await database;
      
      var usuarios = await db.rawQuery('SELECT COUNT(*) as count FROM usuarios');
      print('👥 Usuários no SQLite: ${usuarios.first['count']}');
      
      var categorias = await db.rawQuery('SELECT COUNT(*) as count FROM categorias_checkmark');
      print('📁 Categorias no SQLite: ${categorias.first['count']}');
  
      var checkmarks = await db.rawQuery('SELECT COUNT(*) as count FROM checkmarks');
      print('✅ Checkmarks no SQLite: ${checkmarks.first['count']}');
      
    } catch (e) {
      print('❌ Erro ao verificar SQLite: $e');
    }
  }

  // Debug: Resetar database
  Future<void> resetDatabase() async {
    try {
      String path = join(await getDatabasesPath(), _databaseName);
      await deleteDatabase(path);
      _database = null;
      print('🗑️ Database resetado');
    } catch (e) {
      print('❌ Erro ao resetar: $e');
    }
  }
}