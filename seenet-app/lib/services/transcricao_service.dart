// lib/services/transcricao_service.dart - VERSÃO 100% API
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';


class TranscricaoService {
  static TranscricaoService? _instance;
  static TranscricaoService get instance => _instance ??= TranscricaoService._();
  TranscricaoService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
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

  /// Processar texto com IA
  /// NOTA: O processamento com IA agora é feito no BACKEND
  /// Este método retorna null para indicar que o processamento será feito na API
  Future<String?> processarComGemini(String transcricaoOriginal) async {
    // O processamento com IA agora é feito no backend quando salva a transcrição
    // Retornamos null para indicar que deve usar o processamento do servidor
    print('ℹ️ Processamento com IA será feito no backend');
    return null;
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
  }
}