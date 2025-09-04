import 'package:sqflite/sqflite.dart';
import '../../models/avaliacao.dart';

class AvaliacaoTable {
  static const String tableName = 'avaliacoes';
  
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
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
  }
  
  static Future<int?> insert(Database db, Avaliacao avaliacao) async {
    try {
      int id = await db.insert(tableName, {
        'tecnico_id': avaliacao.tecnicoId,
        'titulo': avaliacao.titulo,
        'descricao': avaliacao.descricao,
        'status': avaliacao.status,
      });
      print('✅ Avaliação criada: $id');
      return id;
    } catch (e) {
      print('❌ Erro criar avaliação: $e');
      return null;
    }
  }
  
  static Future<bool> finalizar(Database db, int avaliacaoId) async {
    try {
      await db.update(
        tableName,
        {
          'status': 'concluida',
          'data_conclusao': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [avaliacaoId],
      );
      print('✅ Avaliação finalizada: $avaliacaoId');
      return true;
    } catch (e) {
      print('❌ Erro finalizar: $e');
      return false;
    }
  }
}