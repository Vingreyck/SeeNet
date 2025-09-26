class Environment {
  // Configurações de ambiente
  static const bool isDevelopment = bool.fromEnvironment('DEVELOPMENT', defaultValue: true);
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  // ✅ SUPABASE PostgreSQL - Configurações corrigidas
  static bool get usePostgreSQL => 
    const String.fromEnvironment('USE_POSTGRESQL', defaultValue: 'false') == 'true';
    
  static String get dbHost => 
    const String.fromEnvironment('DB_HOST', defaultValue: 'db.tcqhyzbkkigukrqniefx.supabase.co');
    
  static int get dbPort => 
    const int.fromEnvironment('DB_PORT', defaultValue: 5432);
    
  static String get dbName => 
    const String.fromEnvironment('DB_NAME', defaultValue: 'postgres');
    
  static String get dbUsername => 
    const String.fromEnvironment('DB_USERNAME', defaultValue: 'postgres');
    
  static String get dbPassword => 
    const String.fromEnvironment('DB_PASSWORD', defaultValue: '');
  
  // ✅ URL COMPLETA para facilitar
  static String get databaseUrl => 
    const String.fromEnvironment('DATABASE_URL', 
      defaultValue: 'postgresql://postgres:@db.tcqhyzbkkigukrqniefx.supabase.co:5432/postgres');
  
  // API Keys
  static String get geminiApiKey => 
    const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  
  // URLs por ambiente
  static String get apiBaseUrl {
    if (isProduction) {
      return const String.fromEnvironment('API_URL_PROD', defaultValue: 'https://api.seenet.com');
    }
    return const String.fromEnvironment('API_URL_DEV', defaultValue: 'http://localhost:3000');
  }
  
  // Debug/Logs
  static bool get enableDebugLogs => isDevelopment;
  static bool get enableCrashReporting => isProduction;
  
  // Configurações de segurança
  static int get sessionTimeoutMinutes => 
    const int.fromEnvironment('SESSION_TIMEOUT', defaultValue: 480);
  
  static int get maxLoginAttempts => 
    const int.fromEnvironment('MAX_LOGIN_ATTEMPTS', defaultValue: 5);
  
  // Validar configuração
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
    print('🔑 Gemini configurado: ${geminiApiKey.isNotEmpty ? "SIM" : "NÃO"}');
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
}