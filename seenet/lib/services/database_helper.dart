// lib/services/database_helper.dart
import 'package:mysql1/mysql1.dart';
import '../config/database_config.dart';

class DatabaseHelper {
  static MySqlConnection? _connection;

  static Future<MySqlConnection> _getConnection() async {
    if (_connection == null) {
      try {
        final settings = ConnectionSettings(
          host: DatabaseConfig.host,        // Sem porta aqui
          port: DatabaseConfig.port,        // Porta separada
          user: DatabaseConfig.username,
          password: DatabaseConfig.password,
          db: DatabaseConfig.database,
          timeout: const Duration(seconds: DatabaseConfig.connectionTimeout),
        );
        
        _connection = await MySqlConnection.connect(settings);
        print('✅ Conexão com banco estabelecida');
        print('📍 Conectado em: ${DatabaseConfig.host}:${DatabaseConfig.port}');
        print('🗄️ Database: ${DatabaseConfig.database}');
      } catch (e) {
        print('❌ Erro ao conectar com banco: $e');
        rethrow;
      }
    }
    return _connection!;
  }

  // ... resto da classe igual
}