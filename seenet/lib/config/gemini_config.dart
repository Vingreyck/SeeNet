// lib/config/gemini_config.dart - VERSÃO OTIMIZADA PARA INSTRUÇÕES DIRETAS
class GeminiConfig {
  // SUBSTITUA PELA SUA CHAVE REAL DO GEMINI
  static const String apiKey = 'AIzaSyBuTLGFDYNDgjNyx_ozSoojteihsDTEUMA';
  
  // URL da API baseada no exemplo oficial do Google
  static const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  
  // Configurações do modelo
  static const int maxTokens = 2048;
  static const double temperature = 0.7;
  
  // ✅ PROMPT OTIMIZADO PARA INSTRUÇÕES DIRETAS E PRÁTICAS
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

  // Configurações baseadas no exemplo oficial
  static const String modelName = 'gemini-2.0-flash';
  static const String apiVersion = 'v1beta';
  
  // URLs úteis
  static const String apiKeyUrl = 'https://makersuite.google.com/app/apikey';
  
  // Verificar se está configurado
  static bool get isConfigured {
    return apiKey != 'SUA_CHAVE_GEMINI_AQUI' && 
           apiKey.isNotEmpty &&
           apiKey.length > 20;
  }
  
  // Debug
  static void printStatus() {
    print('🔑 Gemini configurado: ${isConfigured ? "SIM" : "NÃO"}');
    if (isConfigured) {
      print('🗝️ Chave: ${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}');
    }
    print('🤖 Modelo: $modelName');
    print('📡 URL: $apiUrl');
  }
}