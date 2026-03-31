import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'seenet_offline.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Fila de ações pendentes para sincronizar
        await db.execute('''
          CREATE TABLE fila_sincronizacao (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            payload TEXT NOT NULL,
            tentativas INTEGER DEFAULT 0,
            criado_em INTEGER NOT NULL,
            sincronizado INTEGER DEFAULT 0
          )
        ''');

        // Cache local das OSs (para exibir offline)
        await db.execute('''
          CREATE TABLE cache_ordens_servico (
            id TEXT PRIMARY KEY,
            dados TEXT NOT NULL,
            atualizado_em INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ── FILA DE SINCRONIZAÇÃO ──────────────────────────

  static Future<int> enfileirar(String tipo, String payload) async {
    final db = await instance;
    return db.insert('fila_sincronizacao', {
      'tipo': tipo,
      'payload': payload,
      'criado_em': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> pendentes() async {
    final db = await instance;
    return db.query(
      'fila_sincronizacao',
      where: 'sincronizado = 0 AND tentativas < 3',
      orderBy: 'criado_em ASC',
    );
  }

  static Future<void> marcarSincronizado(int id) async {
    final db = await instance;
    await db.update(
      'fila_sincronizacao',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> incrementarTentativa(int id) async {
    final db = await instance;
    await db.rawUpdate(
      'UPDATE fila_sincronizacao SET tentativas = tentativas + 1 WHERE id = ?',
      [id],
    );
  }

  static Future<int> contarPendentes() async {
    final db = await instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM fila_sincronizacao WHERE sincronizado = 0 AND tentativas < 3',
    );
    return result.first['total'] as int;
  }

  // ── CACHE DE OSs ──────────────────────────────────

  static Future<void> salvarOS(String id, String dadosJson) async {
    final db = await instance;
    await db.insert(
      'cache_ordens_servico',
      {
        'id': id,
        'dados': dadosJson,
        'atualizado_em': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> listarOSsCache() async {
    final db = await instance;
    return db.query('cache_ordens_servico', orderBy: 'atualizado_em DESC');
  }

  static Future<void> limparCacheAntigo() async {
    final db = await instance;
    final limite = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    await db.delete(
      'cache_ordens_servico',
      where: 'atualizado_em < ?',
      whereArgs: [limite],
    );
  }
}