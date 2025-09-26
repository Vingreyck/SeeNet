// lib/config/database_config_postgres.dart - VERSÃO 2.4.6 - SUPABASE
import 'environment.dart';

class PostgreSQLConfig {
  // ✅ CONFIGURAÇÕES AJUSTADAS PARA SUPABASE
  static String get host => Environment.isDevelopment 
      ? Environment.dbHost
      : Environment.dbHost;
      
  static int get port => Environment.dbPort;
  
  // ✅ SUPABASE USA 'postgres' como nome do banco
  static String get database => Environment.dbName;
  
  static String get username => Environment.dbUsername;
  
  static String get password => Environment.dbPassword;
  
  // Pool de conexões
  static const int maxConnections = 20;
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration queryTimeout = Duration(seconds: 60);
  
  // ✅ SUPABASE SEMPRE USA SSL
  static bool get useSSL => true; // Supabase sempre requer SSL
  
  // Connection string para facilitar
  static String get connectionString {
    return 'postgresql://$username:$password@$host:$port/$database'
           '${useSSL ? '?sslmode=require' : ''}';
  }
  
  // Debug
  static void printConfig() {
    if (!Environment.enableDebugLogs) return;
    
    print('=== POSTGRESQL CONFIG (SUPABASE) ===');
    print('Host: $host');
    print('Port: $port');
    print('Database: $database');
    print('Username: $username');
    print('Password: ${password.isNotEmpty ? "***configured***" : "***EMPTY - CONFIGURE!***"}');
    print('SSL: $useSSL (Supabase requires SSL)');
    print('Use PostgreSQL: ${Environment.usePostgreSQL}');
    print('Environment: ${Environment.isDevelopment ? "DEV" : "PROD"}');
    print('Connection String: postgresql://$username:***@$host:$port/$database?sslmode=require');
    print('=====================================');
  }
}