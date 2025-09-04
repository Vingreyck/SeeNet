import 'package:sqflite/sqflite.dart';
import '../../models/diagnostico.dart';

class DiagnosticoTable {
  static const String tableName = 'diagnosticos';
  
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
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
  }
  
  static Future<bool> insert(Database db, Diagnostico diagnostico) async {
    try {
      await db.insert(tableName, {
        'avaliacao_id': diagnostico.avaliacaoId,
        'categoria_id': diagnostico.categoriaId,
        'prompt_enviado': diagnostico.promptEnviado,
        'resposta_chatgpt': diagnostico.respostaChatgpt,
        'resumo_diagnostico': diagnostico.resumoDiagnostico,
        'status_api': diagnostico.statusApi,
        'tokens_utilizados': diagnostico.tokensUtilizados,
      });
      print('✅ Diagnóstico salvo');
      return true;
    } catch (e) {
      print('❌ Erro salvar diagnóstico: $e');
      return false;
    }
  }
  
  static Future<List<Diagnostico>> getByAvaliacao(Database db, int avaliacaoId) async {
    try {
      List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: 'avaliacao_id = ?',
        whereArgs: [avaliacaoId],
        orderBy: 'data_criacao DESC',
      );
      
      return results.map((map) => Diagnostico.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro buscar diagnósticos: $e');
      return [];
    }
  }
}