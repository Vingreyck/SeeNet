// lib/config/database_config.dart
class DatabaseConfig {
  // Configuração LOCAL (desenvolvimento)
  static const bool isProduction = false;
  
  // Configurações locais
  static const String localHost = '127.0.0.1';
  static const String localUsername = 'root';
  static const String localPassword = '12345678';
  
  // Configurações do servidor (para quando subir)
  static const String serverHost = 'IP_DO_SERVIDOR_AQUI'; // Trocar pelo IP real
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