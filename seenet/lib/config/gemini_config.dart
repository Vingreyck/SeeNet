// lib/config/gemini_config.dart - BASEADO NO EXEMPLO OFICIAL
class GeminiConfig {
  // SUBSTITUA PELA SUA CHAVE REAL DO GEMINI
  static const String apiKey = 'AIzaSyBuTLGFDYNDgjNyx_ozSoojteihsDTEUMA';
  
  // URL da API baseada no exemplo oficial do Google
  static const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  
  // Configurações do modelo
  static const int maxTokens = 2048;
  static const double temperature = 0.7;
  
  // Prompt otimizado para diagnósticos técnicos
  static const String systemPrompt = '''
Você é um técnico especialista em redes, internet e IPTV com mais de 10 anos de experiência. 
Analise os problemas de conectividade e forneça diagnósticos precisos com soluções práticas.

FORMATO DA RESPOSTA:
🔍 DIAGNÓSTICO: [resumo claro do problema]

🎯 CAUSA PROVÁVEL: [explicação técnica das causas]

🛠️ SOLUÇÕES RECOMENDADAS:

**1. VERIFICAÇÃO BÁSICA (5 min)**
   ✓ [passo simples 1]
   ✓ [passo simples 2]

**2. DIAGNÓSTICO AVANÇADO (15 min)**
   ✓ [passo técnico 1] 
   ✓ [passo técnico 2]

⚠️ **SE PERSISTIR:** [contatar suporte]

✅ **PREVENÇÃO:** [dicas preventivas]

Seja direto, técnico e prático.
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