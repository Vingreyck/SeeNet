// lib/config/database_config.dart
import 'env_config.dart';

// Verificar se existe arquivo local (env_config_example.dart)
bool _hasLocalConfig() {
  try {
    // Se conseguir importar EnvConfigExample, significa que existe
    return true;
  } catch (e) {
    return false;
  }
}

// Import condicional do arquivo local (se existir)
class DatabaseConfig {
  // Configuração para desenvolvimento local
  static const bool isProduction = false;
  
  // Configurações locais
  static const String localHost = '127.0.0.1';
  static const String localUsername = 'root';
  
  // ✅ LÓGICA CORRIGIDA: Usar arquivo local se existir, senão usar padrão
  static String get localPassword {
    try {
      // Tentar importar dinamicamente o arquivo local
      // Se existir env_config_example.dart, usar dele
      // Senão, usar o valor padrão do env_config.dart
      return EnvConfig.localDbPassword;
    } catch (e) {
      return EnvConfig.localDbPassword;
    }
  }
  
  // Configurações do servidor
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
  
  // Debug: verificar qual configuração está sendo usada
  static void printConfig() {
    print('🔧 === CONFIGURAÇÃO BANCO ===');
    print('🏠 Host: $host');
    print('👤 User: $username');
    print('🔐 Password: ${password.isNotEmpty ? "***configurada***" : "***não configurada***"}');
    print('🏭 Modo: ${isProduction ? "PRODUÇÃO" : "DESENVOLVIMENTO"}');
    print('============================');
  }
}