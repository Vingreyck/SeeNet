// lib/config/env_config_example.dart
// ⚠️ ARQUIVO LOCAL - SUAS CONFIGURAÇÕES REAIS
// Este arquivo NÃO deve ir para o GitHub (está no .gitignore)

class EnvConfigExample {
  // 🔑 Google Gemini API Key - SUA CHAVE REAL
  static const String geminiApiKey = 'AIzaSyDL9UktpfDwR48vyhyNB9cFdhybVUVHISE';
  
  // 🗄️ Banco de dados local - SUA SENHA REAL
  static const String localDbPassword = '12345678';
  
  // 🌐 Configurações do servidor - SUAS CONFIGURAÇÕES REAIS
  static const String serverDbPassword = '1524Br101';
  static const String serverHost = 'IP_DO_SERVIDOR_AQUI';
  static const String serverUsername = 'flutter_user';
  
  // 🔐 Chave de criptografia (sua chave de 32 caracteres)
  static const String encryptionKey = 'minha_chave_super_secreta_32chars';
  
  // Configurações de desenvolvimento
  static const bool isDevelopment = true;
  static const bool isProduction = false;
  static const String apiUrlDev = 'http://localhost:3000';
  static const String apiUrlProd = 'https://api.seenet.com';
  static const int sessionTimeout = 480;
  static const int maxLoginAttempts = 5;
  
  // Mapa para compatibilidade
  static const Map<String, String> config = {
    'DEVELOPMENT': 'true',
    'PRODUCTION': 'false',
    'GEMINI_API_KEY': geminiApiKey,
    'DB_PASSWORD': localDbPassword,
    'API_URL_DEV': apiUrlDev,
    'API_URL_PROD': apiUrlProd,
    'SESSION_TIMEOUT': '480',
    'MAX_LOGIN_ATTEMPTS': '5',
  };
}