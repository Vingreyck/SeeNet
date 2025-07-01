// lib/services/database_helper.dart - VERSÃO CORRIGIDA
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/usuario.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../models/resposta_checkmark.dart';
import '../models/diagnostico.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static const String _databaseName = 'seenet.db';
  static const int _databaseVersion = 1;
  
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
        onOpen: _onOpen,
      );
      
      print('✅ SQLite conectado: $path');
      return db;
    } catch (e) {
      print('❌ Erro ao inicializar SQLite: $e');
      rethrow;
    }
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
    
    print('✅ Tabelas criadas com sucesso');
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
      
      // Inserir usuários
      await db.insert('usuarios', {
        'nome': 'Administrador',
        'email': 'admin@seenet.com',
        'senha': _hashPassword('admin123'),
        'tipo_usuario': 'administrador',
      });
      
      await db.insert('usuarios', {
        'nome': 'Técnico Teste',
        'email': 'tecnico@seenet.com',
        'senha': _hashPassword('123456'),
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
  
  // ========== MÉTODOS PARA USUÁRIOS ==========
  Future<Usuario?> loginUsuario(String email, String senha) async {
    try {
      final db = await database;
      String senhaHash = _hashPassword(senha);
      
      List<Map<String, dynamic>> results = await db.query(
        'usuarios',
        where: 'email = ? AND (senha = ? OR senha = ?) AND ativo = 1',
        whereArgs: [email, senha, senhaHash],
      );
      
      if (results.isNotEmpty) {
        print('✅ Login: $email');
        return Usuario.fromMap(results.first);
      }
      return null;
    } catch (e) {
      print('❌ Erro login: $e');
      return null;
    }
  }
  
  Future<bool> criarUsuario(Usuario usuario) async {
    try {
      final db = await database;
      
      await db.insert('usuarios', {
        'nome': usuario.nome,
        'email': usuario.email,
        'senha': _hashPassword(usuario.senha),
        'tipo_usuario': usuario.tipoUsuario,
        'ativo': usuario.ativo ? 1 : 0,
      });
      
      print('✅ Usuário criado: ${usuario.email}');
      return true;
    } catch (e) {
      print('❌ Erro criar usuário: $e');
      return false;
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

  // ========== UTILIDADES ==========
  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

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