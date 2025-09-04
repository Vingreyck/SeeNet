// lib/services/gemini_service.dart - BASEADO NO EXEMPLO OFICIAL
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/gemini_config.dart';

class GeminiService {
  static Future<String?> gerarDiagnostico(String prompt) async {
    try {
      // Verificar se a chave está configurada
      if (!GeminiConfig.isConfigured) {
        print('⚠️ Chave do Google Gemini não configurada');
        print('📝 Configure em: ${GeminiConfig.apiKeyUrl}');
        print('🔍 Status atual: chave="${GeminiConfig.apiKey.substring(0, 10)}..."');
        return null;
      }

      print('🚀 Enviando para Google Gemini...');
      print('📝 Modelo: ${GeminiConfig.modelName}');
      print('📝 Prompt (${prompt.length} chars): ${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}...');
      
      // Payload exatamente como no exemplo oficial do Google
      final Map<String, dynamic> requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': '${GeminiConfig.systemPrompt}\n\n$prompt'
              }
            ]
          }
        ]
      };

      print('📡 Enviando requisição para: ${GeminiConfig.apiUrl}');

      final response = await http.post(
        Uri.parse(GeminiConfig.apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': GeminiConfig.apiKey,  // Header exato do exemplo oficial
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📡 Status da resposta: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('📄 Estrutura da resposta: ${data.keys.toList()}');
        
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          String resposta = data['candidates'][0]['content']['parts'][0]['text'];
          print('✅ Resposta recebida do Gemini (${resposta.length} caracteres)');
          print('📖 Prévia: ${resposta.substring(0, resposta.length > 100 ? 100 : resposta.length)}...');
          
          return resposta;
        } else {
          print('❌ Resposta em formato inesperado');
          print('📄 Resposta completa: ${response.body}');
          return null;
        }
      } else {
        print('❌ Erro na API: ${response.statusCode}');
        print('📄 Resposta de erro: ${response.body}');
        
        // Interpretar erros específicos
        try {
          final errorData = json.decode(response.body);
          if (errorData['error'] != null) {
            print('💡 Erro detalhado: ${errorData['error']['message']}');
            
            if (response.statusCode == 400) {
              print('💡 Erro 400: Chave API inválida ou request malformado');
            } else if (response.statusCode == 403) {
              print('💡 Erro 403: API não habilitada ou sem permissão');
            } else if (response.statusCode == 404) {
              print('💡 Erro 404: Modelo não encontrado');
            } else if (response.statusCode == 429) {
              print('💡 Erro 429: Limite de requisições atingido');
            }
          }
        } catch (e) {
          print('💡 Erro ao decodificar resposta de erro: $e');
        }
        
        return null;
      }
    } catch (e) {
      print('❌ Erro ao conectar com Gemini: $e');
      
      if (e.toString().contains('TimeoutException')) {
        print('💡 Timeout - Tente novamente');
      } else if (e.toString().contains('SocketException')) {
        print('💡 Erro de rede - Verifique sua conexão');
      }
      
      return null;
    }
  }

  // Teste simples baseado no exemplo oficial
  static Future<bool> testarConexao() async {
    print('🧪 Testando conexão com Google Gemini...');
    
    // Debug da configuração
    GeminiConfig.printStatus();
    
    // Teste com prompt simples
    String? resposta = await gerarDiagnostico('Teste simples. Responda apenas: "Gemini funcionando!"');
    
    if (resposta != null && resposta.isNotEmpty) {
      print('✅ Teste bem-sucedido!');
      print('📝 Resposta: $resposta');
      return true;
    } else {
      print('❌ Teste falhou');
      return false;
    }
  }

  // Gerar diagnóstico com retry
  static Future<String?> gerarDiagnosticoComRetry(String prompt, {int maxTentativas = 3}) async {
    for (int tentativa = 1; tentativa <= maxTentativas; tentativa++) {
      print('🔄 Tentativa $tentativa de $maxTentativas...');
      
      String? resultado = await gerarDiagnostico(prompt);
      
      if (resultado != null) {
        print('✅ Sucesso na tentativa $tentativa');
        return resultado;
      }
      
      if (tentativa < maxTentativas) {
        print('⏳ Aguardando 3 segundos...');
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    print('❌ Todas as $maxTentativas tentativas falharam');
    return null;
  }

  // Validar chave API
  static bool validarChave(String chave) {
    // Chaves Gemini começam com AIza e têm ~39 caracteres
    return chave.isNotEmpty && 
           chave.length >= 35 && 
           chave.startsWith('AIza');
  }

  // Info sobre o serviço
  static Map<String, String> getInfo() {
    return {
      'Nome': 'Google Gemini 2.0 Flash',
      'Custo': 'Gratuito',
      'Limite': '15 req/min',
      'Qualidade': 'Excelente',
      'Configuração': GeminiConfig.apiKeyUrl,
      'Status': GeminiConfig.isConfigured ? 'Configurado' : 'Não configurado',
    };
  }

  // Verificar status
  static bool get isConfigured => GeminiConfig.isConfigured;

  // Debug completo
  static void debugConfiguracoes() {
    print('\n🔍 === DEBUG GEMINI SERVICE ===');
    print('🔑 Chave configurada: ${isConfigured ? "SIM" : "NÃO"}');
    print('📡 URL: ${GeminiConfig.apiUrl}');
    print('🤖 Modelo: ${GeminiConfig.modelName}');
    
    if (isConfigured) {
      String chave = GeminiConfig.apiKey;
      print('🗝️ Chave: ${chave.substring(0, 8)}...${chave.substring(chave.length - 6)}');
      print('✅ Formato válido: ${validarChave(chave)}');
      print('📏 Tamanho: ${chave.length} caracteres');
    } else {
      print('❌ Chave atual: "${GeminiConfig.apiKey}"');
      print('💡 Configure em: ${GeminiConfig.apiKeyUrl}');
    }
    
    print('════════════════════════════════\n');
  }
}