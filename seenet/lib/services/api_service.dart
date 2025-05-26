import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Substitua pela sua chave da API do OpenAI
  static const String _apiKey = 'SUA_CHAVE_API_AQUI';
  static const String _baseUrl = 'https://api.openai.com/v1';
  
  // Para seu backend personalizado, mude para:
  // static const String _baseUrl = 'https://seu-backend.com/api';

  /// Envia o vídeo para análise e retorna o diagnóstico
  static Future<String> analyzeVideo(String videoPath) async {
    try {
      // Opção 1: Enviar para ChatGPT diretamente (apenas texto por enquanto)
      return await _sendToOpenAI("Usuário relatou problema de rede. Forneça diagnóstico.");
      
      // Opção 2: Enviar para seu backend personalizado
      // return await _sendToCustomBackend(videoPath);
      
    } catch (e) {
      throw Exception('Erro ao analisar vídeo: $e');
    }
  }

  /// Envia texto para OpenAI ChatGPT
  static Future<String> _sendToOpenAI(String prompt) async {
    final url = Uri.parse('$_baseUrl/chat/completions');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content': '''Você é um especialista em diagnóstico de problemas de rede e infraestrutura de TI. 
            Analise o relato do técnico e forneça um diagnóstico detalhado incluindo:
            - Identificação do problema
            - Possíveis causas
            - Soluções recomendadas passo a passo
            - Prioridade do problema
            - Tempo estimado de resolução
            
            Formate a resposta de forma clara e profissional.'''
          },
          {
            'role': 'user',
            'content': prompt
          }
        ],
        'max_tokens': 800,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Erro na API: ${response.statusCode}');
    }
  }

  /// Envia vídeo para seu backend personalizado
  static Future<String> _sendToCustomBackend(String videoPath) async {
    final url = Uri.parse('$_baseUrl/analyze-video');
    
    var request = http.MultipartRequest('POST', url);
    
    // Adicionar o arquivo de vídeo
    request.files.add(
      await http.MultipartFile.fromPath('video', videoPath),
    );
    
    // Adicionar headers se necessário
    request.headers.addAll({
      'Authorization': 'Bearer SEU_TOKEN_AQUI',
      'Content-Type': 'multipart/form-data',
    });

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['diagnosis'] ?? 'Diagnóstico não disponível';
    } else {
      throw Exception('Erro no backend: ${response.statusCode}');
    }
  }

  /// Converte áudio em texto (Speech-to-Text)
  static Future<String> transcribeAudio(String audioPath) async {
    final url = Uri.parse('$_baseUrl/audio/transcriptions');
    
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $_apiKey';
    
    request.files.add(
      await http.MultipartFile.fromPath('file', audioPath),
    );
    request.fields['model'] = 'whisper-1';

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'];
    } else {
      throw Exception('Erro na transcrição: ${response.statusCode}');
    }
  }

  /// Método para testar a conexão com a API
  static Future<bool> testConnection() async {
    try {
      final response = await _sendToOpenAI("Teste de conexão");
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Modelo para estruturar o diagnóstico
class DiagnosisResult {
  final String problem;
  final List<String> causes;
  final List<String> solutions;
  final String priority;
  final String estimatedTime;
  final String fullText;

  DiagnosisResult({
    required this.problem,
    required this.causes,
    required this.solutions,
    required this.priority,
    required this.estimatedTime,
    required this.fullText,
  });

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) {
    return DiagnosisResult(
      problem: json['problem'] ?? '',
      causes: List<String>.from(json['causes'] ?? []),
      solutions: List<String>.from(json['solutions'] ?? []),
      priority: json['priority'] ?? 'Média',
      estimatedTime: json['estimatedTime'] ?? '30-60 minutos',
      fullText: json['fullText'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problem': problem,
      'causes': causes,
      'solutions': solutions,
      'priority': priority,
      'estimatedTime': estimatedTime,
      'fullText': fullText,
    };
  }
}