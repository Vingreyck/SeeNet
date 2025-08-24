// lib/config/database_config.dart - CORRIGIDO
import 'env.config_example.dart'; // ← IMPORT CORRETO (não o .example)

class DatabaseConfig {
  // Configuração para desenvolvimento local
  static const bool isProduction = false;
  
  // Configurações locais (vem do arquivo de configuração)
  static const String localHost = '127.0.0.1';
  static const String localUsername = 'root';
  static String get localPassword => EnvConfig.localDbPassword; 
  
  // Configurações do servidor (vem do arquivo de configuração)
  static String get serverHost => EnvConfig.serverHost;
  static String get serverUsername => EnvConfig.serverUsername;
  static String get serverPassword => EnvConfig.serverDbPassword;
  
  // Configurações ativas
  static String get host => isProduction ? serverHost : localHost;
  static String get username => isProduction ? serverUsername : localUsername;
  static String get password => isProduction ? serverPassword : localPassword;
  
  // Configurações comuns
  static const int port = 3306;
  static const String database = 'seenet';
  static const int connectionTimeout = 30;
}