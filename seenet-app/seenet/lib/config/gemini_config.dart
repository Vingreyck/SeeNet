import 'environment.dart';

class GeminiConfig {
  // Agora usando Environment
  static String get apiKey => Environment.geminiApiKey;
  
  static const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  
  static const int maxTokens = 2048;
  static const double temperature = 0.7;
  
  static const String systemPrompt = '''
Você é um técnico especialista em internet/IPTV. Suas respostas devem ser EXTREMAMENTE DIRETAS e PRÁTICAS.

REGRAS OBRIGATÓRIAS:
1. Use apenas PASSOS NUMERADOS curtos e objetivos
2. Máximo 3-5 passos por solução
3. Linguagem simples e clara (não seja técnico demais)
4. Comece SEMPRE com a solução mais rápida
5. Cada passo deve ter no máximo 1 linha
6. Use emojis para facilitar visualização

FORMATO OBRIGATÓRIO:

🔧 **SOLUÇÃO RÁPIDA (2 min):**
1. [ação específica]
2. [ação específica]
3. [resultado esperado]

🔧 **SE NÃO RESOLVER (5 min):**
1. [próxima ação]
2. [próxima ação]
3. [testar resultado]

⚠️ **AINDA COM PROBLEMA:**
"Ligue para a operadora informando: [info específica]"

✅ **DICA RÁPIDA:**
[uma dica preventiva em 1 linha]

IMPORTANTE: Seja direto, prático e focado na solução imediata.
  ''';

  static const String modelName = 'gemini-2.0-flash';
  static const String apiVersion = 'v1beta';
  static const String apiKeyUrl = 'https://makersuite.google.com/app/apikey';
  
  // Verificar se está configurado
  static bool get isConfigured {
    return apiKey.isNotEmpty && 
           apiKey.length > 20 &&
           apiKey.startsWith('AIza');
  }
  
  // Debug - só mostra se necessário
  static void printStatus() {
    if (!Environment.enableDebugLogs) return;
    
    print('🔑 Gemini configurado: ${isConfigured ? "SIM" : "NÃO"}');
    if (isConfigured) {
      print('🗝️ Chave: ${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}');
    } else {
      print('⚠️ Configure a chave em: $apiKeyUrl');
    }
    print('🤖 Modelo: $modelName');
    print('📡 URL: $apiUrl');
  }
}
