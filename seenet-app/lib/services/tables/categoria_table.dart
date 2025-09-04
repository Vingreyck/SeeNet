import 'package:sqflite/sqflite.dart';
import '../../models/categoria_checkmark.dart';

class CategoriaTable {
  static const String tableName = 'categorias_checkmark';
  
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descricao TEXT,
        ativo INTEGER DEFAULT 1,
        ordem INTEGER DEFAULT 0,
        data_criacao TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }
  
  static Future<void> insertInitialData(Database db) async {
    List<Map<String, dynamic>> categorias = [
      {'nome': 'Lentidão', 'descricao': 'Problemas de velocidade, buffering e lentidão geral', 'ordem': 1},
      {'nome': 'IPTV', 'descricao': 'Travamentos, buffering, canais fora do ar, qualidade de vídeo', 'ordem': 2},
      {'nome': 'Aplicativos', 'descricao': 'Apps não carregam, erro de carregamento da logo', 'ordem': 3},
      {'nome': 'Acesso Remoto', 'descricao': 'Ativação de acessos remotos dos roteadores', 'ordem': 4},
    ];
    
    for (var categoria in categorias) {
      await db.insert(tableName, categoria);
    }
  }
  
  static Future<List<CategoriaCheckmark>> getAll(Database db) async {
    try {
      List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: 'ativo = 1',
        orderBy: 'ordem',
      );
      
      return results.map((map) => CategoriaCheckmark.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro buscar categorias: $e');
      return [];
    }
  }
}