// lib/services/transcricao_service.dart
//import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../models/transcricao_tecnica.dart';
import '../services/gemini_service.dart';
import '../services/database_helper.dart';

class TranscricaoService {
  static TranscricaoService? _instance;
  static TranscricaoService get instance => _instance ??= TranscricaoService._();
  TranscricaoService._();

  /*final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  
  // Callbacks
  Function(String)? onTranscriptionUpdate;
  Function(String)? onTranscriptionComplete;
  Function(String)? onError;

  /// Inicializar o serviço de speech-to-text
  Future<bool> initialize() async {
    try {
      // Verificar permissões
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        onError?.call('Permissão de microfone negada');
        return false;
      }

      // Inicializar speech-to-text
      _isInitialized = await _speech.initialize(
        onError: (error) => onError?.call('Erro no reconhecimento: ${error.errorMsg}'),
        onStatus: (status) => print('🎤 Status do microfone: $status'),
      );

      if (_isInitialized) {
        print('✅ Serviço de transcrição inicializado');
        return true;
      } else {
        onError?.call('Falha ao inicializar reconhecimento de voz');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao inicializar transcrição: $e');
      onError?.call('Erro ao configurar reconhecimento de voz');
      return false;
    }
  }

  /// Verificar e solicitar permissões
  Future<bool> _checkPermissions() async {
    try {
      PermissionStatus permission = await Permission.microphone.status;
      
      if (permission.isDenied) {
        permission = await Permission.microphone.request();
      }
      
      return permission.isGranted;
    } catch (e) {
      print('❌ Erro ao verificar permissões: $e');
      return false;
    }
  }

  /// Iniciar gravação e transcrição
  Future<bool> startListening() async {
    if (!_isInitialized) {
      bool initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) {
      print('⚠️ Já está ouvindo');
      return false;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          String transcription = result.recognizedWords;
          print('🎤 Transcrição: $transcription');
          
          if (result.finalResult) {
            onTranscriptionComplete?.call(transcription);
          } else {
            onTranscriptionUpdate?.call(transcription);
          }
        },
        listenFor: const Duration(minutes: 10), // Máximo 10 minutos
        pauseFor: const Duration(seconds: 3), // Pausa após 3 segundos de silêncio
        partialResults: true, // Mostrar resultados parciais
        localeId: 'pt_BR', // Português brasileiro
        cancelOnError: false,
      );

      _isListening = true;
      print('🎤 Iniciou gravação');
      return true;
    } catch (e) {
      print('❌ Erro ao iniciar gravação: $e');
      onError?.call('Erro ao iniciar gravação');
      return false;
    }
  }

  /// Parar gravação
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      print('🛑 Parou gravação');
    }
  }

  /// Cancelar gravação
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
      print('❌ Cancelou gravação');
    }
  }

  /// Processar texto com Gemini IA
  Future<String?> processarComGemini(String transcricaoOriginal) async {
    try {
      String prompt = _montarPromptProcessamento(transcricaoOriginal);
      
      print('🤖 Enviando para Gemini...');
      String? resultado = await GeminiService.gerarDiagnostico(prompt);
      
      if (resultado != null) {
        print('✅ Texto processado pela IA');
        return resultado;
      } else {
        print('❌ Falha no processamento IA');
        return _criarProcessamentoSimulado(transcricaoOriginal);
      }
    } catch (e) {
      print('❌ Erro no processamento: $e');
      return _criarProcessamentoSimulado(transcricaoOriginal);
    }
  }

  /// Montar prompt específico para processamento de ações técnicas
  String _montarPromptProcessamento(String transcricao) {
    return '''
TAREFA: Transforme esta descrição técnica em pontos de ação organizados e profissionais.

TEXTO ORIGINAL:
"$transcricao"

INSTRUÇÕES:
1. Extraia as ações técnicas realizadas
2. Organize em pontos numerados
3. Use linguagem técnica e profissional
4. Inclua detalhes importantes (equipamentos, configurações, resultados)
5. Mantenha ordem cronológica das ações
6. Adicione categoria do problema se identificável

FORMATO DE SAÍDA:

**CATEGORIA:** [Tipo do problema identificado]

**AÇÕES REALIZADAS:**
1. [Primeira ação com detalhes técnicos]
2. [Segunda ação com resultados]
3. [Terceira ação e verificações]
...

**RESULTADO:** [Status final e observações]

**OBSERVAÇÕES:** [Informações adicionais relevantes]

Seja conciso mas completo. Foque nas ações técnicas específicas.
''';
  }

  /// Criar processamento simulado se Gemini falhar
  String _criarProcessamentoSimulado(String transcricao) {
    return '''
**CATEGORIA:** Atendimento Técnico

**AÇÕES REALIZADAS:**
1. Registrada solicitação do cliente conforme relato
2. Realizada análise inicial da situação reportada
3. Executados procedimentos técnicos conforme protocolo
4. Verificados resultados e funcionalidade do sistema

**RESULTADO:** Atendimento documentado com sucesso

**OBSERVAÇÕES:** 
• Texto original: "$transcricao"
• Processamento realizado em modo local (IA não disponível)
• Para melhor detalhamento, configure Google Gemini

---
💡 **Dica:** Configure a chave do Google Gemini para processamento automático mais detalhado das ações técnicas.
''';
  }

  /// Salvar transcrição no banco
  Future<bool> salvarTranscricao(TranscricaoTecnica transcricao) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.insert('transcricoes_tecnicas', transcricao.toMap());
      
      print('✅ Transcrição salva no banco');
      return true;
    } catch (e) {
      print('❌ Erro ao salvar transcrição: $e');
      return false;
    }
  }

  /// Buscar transcrições do técnico
  Future<List<TranscricaoTecnica>> buscarTranscricoesTecnico(int tecnicoId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      List<Map<String, dynamic>> results = await db.query(
        'transcricoes_tecnicas',
        where: 'tecnico_id = ?',
        whereArgs: [tecnicoId],
        orderBy: 'data_criacao DESC',
      );
      
      return results.map((map) => TranscricaoTecnica.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar transcrições: $e');
      return [];
    }
  }

  /// Verificar se está gravando
  bool get isListening => _isListening;
  
  /// Verificar se está inicializado
  bool get isInitialized => _isInitialized;

  /// Limpar callbacks
  void clearCallbacks() {
    onTranscriptionUpdate = null;
    onTranscriptionComplete = null;
    onError = null;
  }

  /// Verificar se dispositivo suporta speech-to-text
  Future<bool> isSupported() async {
    try {
      return await _speech.initialize();
    } catch (e) {
      return false;
    }
  }

  /// Obter idiomas disponíveis
  Future<List<stt.LocaleName>> getAvailableLanguages() async {
    try {
      if (!_isInitialized) await initialize();
      return await _speech.locales();
    } catch (e) {
      return [];
    }
  }*/
}