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