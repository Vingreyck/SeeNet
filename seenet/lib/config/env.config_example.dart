// lib/config/env_config.example - CORRIGIDO
// Este arquivo serve como exemplo das variáveis necessárias
// Copie para env_config.dart e configure os valores reais

/*
Variáveis de Ambiente - SeeNet

Para usar em desenvolvimento, configure estas variáveis:

DEVELOPMENT=true
PRODUCTION=false
GEMINI_API_KEY=sua_chave_real_aqui
DB_PASSWORD=senha_do_banco
API_URL_DEV=http://localhost:3000
API_URL_PROD=https://api.seenet.com
SESSION_TIMEOUT=480
MAX_LOGIN_ATTEMPTS=5

Para compilar com essas variáveis:
flutter run --dart-define=GEMINI_API_KEY=sua_chave --dart-define=DEVELOPMENT=true

Para build de produção:
flutter build apk --dart-define=PRODUCTION=true --dart-define=GEMINI_API_KEY=sua_chave_prod
*/

// ✅ EXEMPLO DE CONFIGURAÇÃO:
class EnvConfigExample {
  // Este é apenas um exemplo, não use em produção
  static const Map<String, String> exampleConfig = {
    'DEVELOPMENT': 'true',
    'PRODUCTION': 'false',
    'GEMINI_API_KEY': 'AIzaSyDL9UktpfDwR48vyhyNB9cFdhybVUVHISE', 
    'DB_PASSWORD': 'senha123',
    'API_URL_DEV': 'http://localhost:3000',
    'API_URL_PROD': 'https://api.seenet.com',
    'SESSION_TIMEOUT': '480',
    'MAX_LOGIN_ATTEMPTS': '5',
  };
  
  // Documentação de uso
  static const String usage = '''
  
  🔧 COMO USAR AS VARIÁVEIS DE AMBIENTE:
  
  1. DESENVOLVIMENTO:
     flutter run --dart-define=DEVELOPMENT=true --dart-define=GEMINI_API_KEY=AIzaSyDL9UktpfDwR48vyhyNB9cFdhybVUVHISE
  
  2. PRODUÇÃO:
     flutter build apk --dart-define=PRODUCTION=true --dart-define=GEMINI_API_KEY=sua_chave_prod
  
  3. TODAS AS VARIÁVEIS:
     flutter run --dart-define=DEVELOPMENT=true --dart-define=GEMINI_API_KEY=AIzaSyDL9UktpfDwR48vyhyNB9cFdhybVUVHISE --dart-define=DB_PASSWORD=senha123 --dart-define=SESSION_TIMEOUT=480 --dart-define=MAX_LOGIN_ATTEMPTS=5
  ''';
}