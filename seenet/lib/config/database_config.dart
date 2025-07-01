// lib/config/database_config.dart - CONFIGURAÇÃO REAL
class DatabaseConfig {
  // Configuração para desenvolvimento local
  static const bool isProduction = false;
  
  // Configurações locais (ajuste conforme seu setup)
  static const String localHost = '127.0.0.1';  // ou 'localhost'
  static const String localUsername = 'root';    // seu usuário MySQL
  static const String localPassword = '12345678'; // sua senha MySQL (ajuste aqui)
  
  // Configurações do servidor (para quando subir)
  static const String serverHost = 'IP_DO_SERVIDOR_AQUI';
  static const String serverUsername = 'flutter_user';
  static const String serverPassword = '1524Br101';
  
  // Configurações ativas
  static String get host => isProduction ? serverHost : localHost;
  static String get username => isProduction ? serverUsername : localUsername;
  static String get password => isProduction ? serverPassword : localPassword;
  
  // Configurações comuns
  static const int port = 3306;
  static const String database = 'seenet';
  static const int connectionTimeout = 30;
}