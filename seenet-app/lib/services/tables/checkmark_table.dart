import 'package:sqflite/sqflite.dart';
import '../../models/checkmark.dart';

class CheckmarkTable {
  static const String tableName = 'checkmarks';
  
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
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
  }
  
  static Future<void> insertInitialData(Database db) async {
    // Checkmarks para Lentidão (categoria 1)
    List<Map<String, dynamic>> lentidao = [
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
    
    // Checkmarks para IPTV (categoria 2)
    List<Map<String, dynamic>> iptv = [
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
    
    // Checkmarks para Aplicativos (categoria 3)
    List<Map<String, dynamic>> apps = [
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
    
    // Inserir todos os checkmarks
    for (var checkmark in [...lentidao, ...iptv, ...apps]) {
      await db.insert(tableName, checkmark);
    }
  }
  
  static Future<List<Checkmark>> getByCategoria(Database db, int categoriaId) async {
    try {
      List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: 'categoria_id = ? AND ativo = 1',
        whereArgs: [categoriaId],
        orderBy: 'ordem',
      );
      
      return results.map((map) => Checkmark.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro buscar checkmarks: $e');
      return [];
    }
  }
}