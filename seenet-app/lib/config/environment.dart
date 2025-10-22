// lib/config/environment.dart - VERSÃO SEGURA
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  // ✅ Carregar variáveis de ambiente do arquivo .env
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: ".env");
      print('✅ Variáveis de ambiente carregadas do .env');
    } catch (e) {
      print('⚠️ Arquivo .env não encontrado. Usando valores padrão.');
    }
  }

  // Configurações de ambiente
  static const bool isDevelopment = bool.fromEnvironment('DEVELOPMENT', defaultValue: true);
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  // ✅ SUPABASE PostgreSQL
  static bool get usePostgreSQL => 
    dotenv.env['USE_POSTGRESQL']?.toLowerCase() == 'true' || false;
    
  static String get dbHost => 
    dotenv.env['DB_HOST'] ?? 'db.tcqhyzbkkigukrqniefx.supabase.co';
    
  static int get dbPort => 
    int.tryParse(dotenv.env['DB_PORT'] ?? '5432') ?? 5432;
    
  static String get dbName => 
    dotenv.env['DB_NAME'] ?? 'postgres';
    
  static String get dbUsername => 
    dotenv.env['DB_USERNAME'] ?? 'postgres';
    
  static String get dbPassword => 
    dotenv.env['DB_PASSWORD'] ?? ''; // ✅ NUNCA tem defaultValue com senha real
  
  static String get databaseUrl => 
    dotenv.env['DATABASE_URL'] ?? 
    'postgresql://postgres:@db.tcqhyzbkkigukrqniefx.supabase.co:5432/postgres';
  
  // ✅ API Keys - SEGURAS
  static String get geminiApiKey => 
    dotenv.env['GEMINI_API_KEY'] ?? ''; // ✅ SEM defaultValue!
  
  // URLs por ambiente
  static String get apiBaseUrl {
    if (isProduction) {
      return dotenv.env['API_URL_PROD'] ?? 'https://api.seenet.com';
    }
    return dotenv.env['API_URL_DEV'] ?? 'http://localhost:3000';
  }
  
  // Debug/Logs
  static bool get enableDebugLogs => isDevelopment;
  static bool get enableCrashReporting => isProduction;
  
  // Configurações de segurança
  static int get sessionTimeoutMinutes => 
    int.tryParse(dotenv.env['SESSION_TIMEOUT'] ?? '480') ?? 480;
  
  static int get maxLoginAttempts => 
    int.tryParse(dotenv.env['MAX_LOGIN_ATTEMPTS'] ?? '5') ?? 5;
  
  // ✅ Validar se API keys estão configuradas
  static bool get isGeminiConfigured => geminiApiKey.isNotEmpty;
  
  static bool get isConfigured {
    if (usePostgreSQL) {
      return dbHost.isNotEmpty && dbPassword.isNotEmpty;
    }
    return true;
  }
  
  // Debug info (só em desenvolvimento)
  static void printConfiguration() {
    if (!isDevelopment) return;
    
    print('🔧 === CONFIGURAÇÃO DE AMBIENTE ===');
    print('🏗️ Modo: ${isProduction ? "PRODUÇÃO" : "DESENVOLVIMENTO"}');
    print('🐘 PostgreSQL: ${usePostgreSQL ? "ATIVO" : "INATIVO"}');
    print('🔑 Gemini configurado: ${isGeminiConfigured ? "SIM ✅" : "NÃO ❌"}');
    print('📡 API URL: $apiBaseUrl');
    print('🐘 DB Host: $dbHost');
    print('🔌 DB Port: $dbPort');
    print('💾 DB Name: $dbName');
    print('👤 DB User: $dbUsername');
    print('🔐 DB Password: ${dbPassword.isNotEmpty ? "***configured***" : "***empty***"}');
    print('⏰ Timeout sessão: ${sessionTimeoutMinutes}min');
    print('🛡️ Max tentativas login: $maxLoginAttempts');
    print('🔧 Debug logs: $enableDebugLogs');
    print('📊 Crash reporting: $enableCrashReporting');
    print('✅ Configuração válida: $isConfigured');
    print('=====================================\n');
  }
  
  // ✅ NOVO: Validar se todas as keys necessárias estão presentes
  static void validateRequiredKeys() {
    final List<String> missing = [];
    
    if (!isGeminiConfigured) {
      missing.add('GEMINI_API_KEY');
    }
    
    if (usePostgreSQL && dbPassword.isEmpty) {
      missing.add('DB_PASSWORD');
    }
    
    if (missing.isNotEmpty) {
      print('⚠️ ATENÇÃO: Variáveis de ambiente faltando:');
      for (var key in missing) {
        print('   ❌ $key');
      }
      print('');
      print('💡 Configure-as no arquivo .env na raiz do projeto.');
    } else {
      print('✅ Todas as variáveis de ambiente necessárias estão configuradas!');
    }
  }
}