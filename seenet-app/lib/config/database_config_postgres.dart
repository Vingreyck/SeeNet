// lib/config/database_config_postgres.dart - VERSÃO 2.4.6
import 'environment.dart';

class PostgreSQLConfig {
  // Configurações do banco
  static String get host => Environment.isDevelopment 
      ? Environment.dbHost ?? 'localhost'
      : Environment.dbHost ?? 'postgresql-host';
      
  static int get port => Environment.dbPort ?? 5432;
  
  static String get database => Environment.dbName ?? 'seenet';
  
  static String get username => Environment.dbUsername ?? 'postgres';
  
  static String get password => Environment.dbPassword ?? '';
  
  // Pool de conexões
  static const int maxConnections = 20;
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration queryTimeout = Duration(seconds: 60);
  
  // Configuração SSL para produção
  static bool get useSSL => Environment.isProduction;
  
  // Connection string para facilitar
  static String get connectionString {
    return 'postgresql://$username:$password@$host:$port/$database'
           '${useSSL ? '?sslmode=require' : ''}';
  }
  
  // Debug
  static void printConfig() {
    if (!Environment.enableDebugLogs) return;
    
    print('=== POSTGRESQL CONFIG ===');
    print('Host: $host');
    print('Port: $port');
    print('Database: $database');
    print('Username: $username');
    print('Password: ${password.isNotEmpty ? "***configured***" : "***empty***"}');
    print('SSL: $useSSL');
    print('Environment: ${Environment.isDevelopment ? "DEV" : "PROD"}');
    print('Connection String: postgresql://$username:***@$host:$port/$database');
    print('==============================');
  }
}