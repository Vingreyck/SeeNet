// lib/controllers/transcricao_controller.dart
import 'package:get/get.dart';
import '../models/transcricao_tecnica.dart';
import '../services/transcricao_service.dart';
import '../controllers/usuario_controller.dart';

class TranscricaoController extends GetxController {
  final TranscricaoService _transcricaoService = TranscricaoService.instance;
  final UsuarioController _usuarioController = Get.find<UsuarioController>();

  // Estados observáveis
  RxBool isGravando = false.obs;
  RxBool isProcessando = false.obs;
  RxString textoTranscrito = ''.obs;
  RxString textoProcessado = ''.obs;
  RxString statusMensagem = ''.obs;
  RxList<TranscricaoTecnica> historico = <TranscricaoTecnica>[].obs;

  // Dados da transcrição atual
  DateTime? _inicioGravacao;
  String _textoCompleto = '';

  @override
  void onInit() {
    super.onInit();
    _configurarCallbacks();
    carregarHistorico();
  }

  @override
  void onClose() {
    _transcricaoService.clearCallbacks();
    super.onClose();
  }

  /// Configurar callbacks do serviço
  void _configurarCallbacks() {
    _transcricaoService.onTranscriptionUpdate = (texto) {
      textoTranscrito.value = texto;
      _textoCompleto = texto;
    };

    _transcricaoService.onTranscriptionComplete = (texto) async {
      textoTranscrito.value = texto;
      _textoCompleto = texto;
      
      if (texto.isNotEmpty) {
        await _processarComIA(texto);
      }
    };

    _transcricaoService.onError = (erro) {
      statusMensagem.value = 'Erro: $erro';
      Get.snackbar(
        'Erro na Gravação',
        erro,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      
      // Resetar estados em caso de erro
      isGravando.value = false;
      isProcessando.value = false;
    };
  }

  /// Iniciar gravação
  Future<bool> iniciarGravacao() async {
    try {
      // Limpar dados anteriores
      limpar();
      
      statusMensagem.value = 'Iniciando gravação...';
      
      bool sucesso = await _transcricaoService.startListening();
      
      if (sucesso) {
        isGravando.value = true;
        _inicioGravacao = DateTime.now();
        statusMensagem.value = 'Gravando... Fale claramente';
        print('✅ Gravação iniciada');
        return true;
      } else {
        statusMensagem.value = 'Falha ao iniciar gravação';
        print('❌ Falha ao iniciar gravação');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao iniciar gravação: $e');
      statusMensagem.value = 'Erro: $e';
      return false;
    }
  }

  /// Parar gravação
  Future<void> pararGravacao() async {
    try {
      await _transcricaoService.stopListening();
      isGravando.value = false;
      
      if (_textoCompleto.isNotEmpty) {
        statusMensagem.value = 'Processando com IA...';
        await _processarComIA(_textoCompleto);
      } else {
        statusMensagem.value = 'Nenhum texto foi capturado';
      }
      
      print('🛑 Gravação finalizada');
    } catch (e) {
      print('❌ Erro ao parar gravação: $e');
      statusMensagem.value = 'Erro ao finalizar gravação';
    }
  }

  /// Cancelar gravação
  Future<void> cancelarGravacao() async {
    try {
      await _transcricaoService.cancelListening();
      limpar();
      statusMensagem.value = 'Gravação cancelada';
      print('❌ Gravação cancelada');
    } catch (e) {
      print('❌ Erro ao cancelar gravação: $e');
    }
  }

  /// Processar texto com IA
  Future<void> _processarComIA(String textoOriginal) async {
    try {
      isProcessando.value = true;
      statusMensagem.value = 'Organizando ações com IA...';

      String? textoProcessadoIA = await _transcricaoService.processarComGemini(textoOriginal);
      
      if (textoProcessadoIA != null && textoProcessadoIA.isNotEmpty) {
        textoProcessado.value = textoProcessadoIA;
        statusMensagem.value = 'Ações organizadas com sucesso!';
        print('✅ Texto processado pela IA');
      } else {
        // Criar texto básico se IA falhar
        textoProcessado.value = _criarTextoBasico(textoOriginal);
        statusMensagem.value = 'Processamento básico concluído';
        print('⚠️ IA não disponível, usando processamento básico');
      }
    } catch (e) {
      print('❌ Erro no processamento: $e');
      textoProcessado.value = _criarTextoBasico(textoOriginal);
      statusMensagem.value = 'Erro no processamento, texto básico criado';
    } finally {
      isProcessando.value = false;
    }
  }

  /// Criar texto básico se IA falhar
  String _criarTextoBasico(String textoOriginal) {
    DateTime agora = DateTime.now();
    
    return """**CATEGORIA:** Atendimento Técnico

**AÇÕES REALIZADAS:**
1. Documentação registrada conforme relato do técnico
2. Procedimentos executados conforme protocolo padrão
3. Verificações técnicas realizadas no sistema

**RESULTADO:** Atendimento documentado com sucesso

**OBSERVAÇÕES:**
• Transcrição original: "$textoOriginal"
• Data/Hora: ${_formatarDataHora(agora)}
• Duração: ${_calcularDuracao()}

---
💡 **Dica:** Configure Google Gemini para processamento automático mais detalhado das ações técnicas.""";
  }

  /// Salvar transcrição
  Future<bool> salvarTranscricao(String titulo) async {
    try {
      if (_usuarioController.idUsuario == null) {
        Get.snackbar('Erro', 'Usuário não identificado');
        return false;
      }

      if (textoTranscrito.isEmpty) {
        Get.snackbar('Erro', 'Não há texto para salvar');
        return false;
      }

      TranscricaoTecnica transcricao = TranscricaoTecnica(
        tecnicoId: _usuarioController.idUsuario!,
        titulo: titulo,
        transcricaoOriginal: textoTranscrito.value,
        pontosDaAcao: textoProcessado.value,
        status: 'concluida',
        duracaoSegundos: _calcularDuracaoSegundos(),
        dataInicio: _inicioGravacao,
        dataConclusao: DateTime.now(),
        dataCriacao: DateTime.now(),
      );

      bool salvou = await _transcricaoService.salvarTranscricao(transcricao);
      
      if (salvou) {
        await carregarHistorico(); // Recarregar histórico
        print('✅ Transcrição salva');
        return true;
      } else {
        print('❌ Erro ao salvar transcrição');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao salvar: $e');
      Get.snackbar('Erro', 'Erro ao salvar documentação');
      return false;
    }
  }

  /// Carregar histórico do técnico
  Future<void> carregarHistorico() async {
    try {
      if (_usuarioController.idUsuario == null) return;
      
      List<TranscricaoTecnica> lista = await _transcricaoService
          .buscarTranscricoesTecnico(_usuarioController.idUsuario!);
      
      historico.value = lista;
      print('✅ ${lista.length} transcrições carregadas');
    } catch (e) {
      print('❌ Erro ao carregar histórico: $e');
    }
  }

  /// Limpar dados atuais
  void limpar() {
    isGravando.value = false;
    isProcessando.value = false;
    textoTranscrito.value = '';
    textoProcessado.value = '';
    statusMensagem.value = '';
    _textoCompleto = '';
    _inicioGravacao = null;
  }

  /// Calcular duração da gravação
  String _calcularDuracao() {
    if (_inicioGravacao == null) return 'N/A';
    
    Duration duracao = DateTime.now().difference(_inicioGravacao!);
    int minutos = duracao.inMinutes;
    int segundos = duracao.inSeconds % 60;
    
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  /// Calcular duração em segundos
  int? _calcularDuracaoSegundos() {
    if (_inicioGravacao == null) return null;
    return DateTime.now().difference(_inicioGravacao!).inSeconds;
  }

  /// Formatar data e hora
  String _formatarDataHora(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  /// Verificar se serviço está disponível
  Future<bool> verificarDisponibilidade() async {
    try {
      return await _transcricaoService.isSupported();
    } catch (e) {
      print('❌ Erro ao verificar disponibilidade: $e');
      return false;
    }
  }

  /// Obter estatísticas do histórico
  Map<String, dynamic> get estatisticasHistorico {
    if (historico.isEmpty) {
      return {
        'total': 0,
        'esteMes': 0,
        'tempoTotal': '00:00',
        'mediaMinutos': 0.0,
      };
    }

    DateTime agora = DateTime.now();
    DateTime inicioMes = DateTime(agora.year, agora.month, 1);
    
    int esteMes = historico.where((t) => 
        t.dataCriacao != null && t.dataCriacao!.isAfter(inicioMes)
    ).length;
    
    int tempoTotalSegundos = historico
        .where((t) => t.duracaoSegundos != null)
        .map((t) => t.duracaoSegundos!)
        .fold(0, (a, b) => a + b);
    
    double mediaMinutos = historico.isNotEmpty 
        ? tempoTotalSegundos / 60.0 / historico.length 
        : 0.0;
    
    int minutos = tempoTotalSegundos ~/ 60;
    int segundos = tempoTotalSegundos % 60;
    String tempoTotal = '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
    
    return {
      'total': historico.length,
      'esteMes': esteMes,
      'tempoTotal': tempoTotal,
      'mediaMinutos': mediaMinutos,
    };
  }

  /// Remover transcrição do histórico
  Future<bool> removerTranscricao(int transcricaoId) async {
    try {
      // Implementar remoção no banco
      // Por enquanto, apenas remove da lista local
      historico.removeWhere((t) => t.id == transcricaoId);
      
      Get.snackbar(
        'Removido',
        'Documentação removida do histórico',
        backgroundColor: Get.theme.colorScheme.secondary,
        colorText: Get.theme.colorScheme.onSecondary,
      );
      
      return true;
    } catch (e) {
      print('❌ Erro ao remover: $e');
      return false;
    }
  }

  /// Buscar no histórico
  List<TranscricaoTecnica> buscarNoHistorico(String termo) {
    if (termo.isEmpty) return historico;
    
    String termoBusca = termo.toLowerCase();
    
    return historico.where((transcricao) {
      return transcricao.titulo.toLowerCase().contains(termoBusca) ||
             transcricao.transcricaoOriginal.toLowerCase().contains(termoBusca) ||
             transcricao.pontosDaAcao.toLowerCase().contains(termoBusca) ||
             (transcricao.categoriaProblema?.toLowerCase().contains(termoBusca) ?? false);
    }).toList();
  }

  /// Debug - informações do serviço
  void debugInfo() {
    print('\n🎤 === TRANSCRIÇÃO DEBUG ===');
    print('📱 Suporte speech-to-text: ${_transcricaoService.isSupported()}');
    print('🎤 Está gravando: ${isGravando.value}');
    print('🤖 Está processando: ${isProcessando.value}');
    print('📝 Texto transcrito: "${textoTranscrito.value}"');
    print('📋 Histórico: ${historico.length} itens');
    print('👤 Usuário: ${_usuarioController.idUsuario}');
    print('================================\n');
  }
}