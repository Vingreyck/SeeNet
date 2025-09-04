// lib/config/env_config.dart
// 📋 ARQUIVO PARA GITHUB - VALORES PADRÃO/EXEMPLO
// ⚠️ Para usar localmente, configure env_config_example.dart com suas chaves reais

class EnvConfig {
  // 🔑 Google Gemini API Key - SUBSTITUA pela sua chave real
  static const String geminiApiKey = 'COLE_SUA_CHAVE_GEMINI_AQUI';
  
  // 🗄️ Banco de dados local - CONFIGURE com sua senha real
  static const String localDbPassword = 'sua_senha_mysql_local';
  
  // 🌐 Configurações do servidor (opcional)
  static const String serverDbPassword = 'senha_do_servidor';
  static const String serverHost = 'ip_do_seu_servidor';
  static const String serverUsername = 'usuario_do_banco';
  
  // 🔐 Chave de criptografia (32 caracteres)
  static const String encryptionKey = 'sua_chave_de_32_caractees_aquiii';
  
  // Configurações de desenvolvimento
  static const bool isDevelopment = true;
  static const bool isProduction = false;
  static const String apiUrlDev = 'http://localhost:3000';
  static const String apiUrlProd = 'https://api.seenet.com';
  static const int sessionTimeout = 480;
  static const int maxLoginAttempts = 5;
}

/*
📝 INSTRUÇÕES PARA DESENVOLVEDORES:

1. 🔧 CONFIGURAÇÃO LOCAL:
   - Copie este arquivo para 'env_config_example.dart'
   - Configure env_config_example.dart com suas credenciais reais
   - O sistema automaticamente usará o arquivo _example.dart se existir

2. 🔑 OBTER CHAVE GEMINI:
   - Acesse: https://makersuite.google.com/app/apikey
   - Faça login com conta Google
   - Crie nova API Key (gratuita - 15 req/min)
   - Copie para env_config_example.dart

3. 🗄️ CONFIGURAR MYSQL LOCAL:
   - Instale MySQL em sua máquina
   - Configure usuário 'root' e senha
   - Use a senha no env_config_example.dart
*/