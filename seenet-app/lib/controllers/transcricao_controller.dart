// lib/controllers/transcricao_controller.dart - VERSÃO 100% API
import 'package:get/get.dart';
import '../models/transcricao_tecnica.dart';
import '../services/transcricao_service.dart';
import '../services/api_service.dart';
import '../controllers/usuario_controller.dart';

class TranscricaoController extends GetxController {
  final TranscricaoService _transcricaoService = TranscricaoService.instance;
  final ApiService _api = ApiService.instance;
  final UsuarioController _usuarioController = Get.find<UsuarioController>();

  // Estados observáveis
  RxBool isGravando = false.obs;
  RxBool isProcessando = false.obs;
  RxBool isLoading = false.obs;
  RxString textoTranscrito = ''.obs;
  RxString textoProcessado = ''.obs;
  RxString statusMensagem = ''.obs;
  RxList<TranscricaoTecnica> historico = <TranscricaoTecnica>[].obs;

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

  void _configurarCallbacks() {
    _transcricaoService.onTranscriptionUpdate = (texto) {
      textoTranscrito.value = texto;
      _textoCompleto = texto;
    };

    _transcricaoService.onTranscriptionComplete = (texto) async {
      textoTranscrito.value = texto;
      _textoCompleto = texto;
      
      if (texto.isNotEmpty) {
        // Não processamos mais localmente - será processado ao salvar na API
        statusMensagem.value = 'Transcrição concluída! Pronto para salvar.';
        textoProcessado.value = _criarMensagemPreProcessamento();
      }
    };

    _transcricaoService.onError = (erro) {
      statusMensagem.value = 'Erro: $erro';
      Get.snackbar('Erro na Gravação', erro);
      isGravando.value = false;
      isProcessando.value = false;
    };
  }

  Future<bool> iniciarGravacao() async {
    try {
      limpar();
      statusMensagem.value = 'Iniciando gravação...';
      
      bool sucesso = await _transcricaoService.startListening();
      
      if (sucesso) {
        isGravando.value = true;
        _inicioGravacao = DateTime.now();
        statusMensagem.value = 'Gravando... Fale claramente';
        print('🎤 Gravação iniciada');
        return true;
      } else {
        statusMensagem.value = 'Falha ao iniciar gravação';
        return false;
      }
    } catch (e) {
      print('❌ Erro ao iniciar gravação: $e');
      statusMensagem.value = 'Erro: $e';
      return false;
    }
  }

  Future<void> pararGravacao() async {
    try {
      await _transcricaoService.stopListening();
      isGravando.value = false;
      
      if (_textoCompleto.isNotEmpty) {
        statusMensagem.value = 'Transcrição concluída! Salve para processar com IA.';
        textoProcessado.value = _criarMensagemPreProcessamento();
      } else {
        statusMensagem.value = 'Nenhum texto capturado';
      }
    } catch (e) {
      print('❌ Erro ao parar gravação: $e');
      statusMensagem.value = 'Erro ao finalizar gravação';
    }
  }

  Future<void> cancelarGravacao() async {
    try {
      await _transcricaoService.cancelListening();
      limpar();
      statusMensagem.value = 'Gravação cancelada';
    } catch (e) {
      print('❌ Erro ao cancelar: $e');
    }
  }

  /// Mensagem antes do processamento (não fazemos mais localmente)
  String _criarMensagemPreProcessamento() {
    DateTime agora = DateTime.now();
    
    return """📝 **Transcrição capturada com sucesso!**

**TEXTO GRAVADO:**
"${textoTranscrito.value}"

**INFORMAÇÕES:**
• Data/Hora: ${_formatarDataHora(agora)}
• Duração: ${_calcularDuracao()}

---

🤖 **Processamento Inteligente:**
Ao salvar esta documentação, nossa IA irá:
✅ Organizar as ações em pontos profissionais
✅ Identificar a categoria do problema
✅ Estruturar o relatório técnico
✅ Adicionar observações relevantes

💡 **Dica:** Clique em "Salvar Documentação" para processar com IA!""";
  }

  // ========== SALVAR TRANSCRIÇÃO VIA API (COM PROCESSAMENTO IA) ==========
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

      isLoading.value = true;
      statusMensagem.value = 'Salvando e processando com IA...';

      // A API fará o processamento com IA automaticamente
      final response = await _api.post('/transcriptions', {
        'titulo': titulo,
        'transcricao_original': textoTranscrito.value,
        'duracao_segundos': _calcularDuracaoSegundos(),
        'descricao': 'Documentação técnica',
      });

      if (response['success']) {
        // Recarregar histórico para pegar a transcrição processada
        await carregarHistorico();
        
        // Pegar a última transcrição (recém-criada) para mostrar o resultado processado
        if (historico.isNotEmpty) {
          final transcricaoSalva = historico.first;
          textoProcessado.value = transcricaoSalva.pontosDaAcao;
        }
        
        print('✅ Transcrição salva e processada pela API');
        
        Get.snackbar(
          'Sucesso',
          'Documentação salva e processada com IA!',
          duration: const Duration(seconds: 3),
        );
        
        statusMensagem.value = 'Documentação salva com sucesso!';
        return true;
      } else {
        print('❌ Erro ao salvar: ${response['error']}');
        Get.snackbar('Erro', 'Falha ao salvar documentação');
        statusMensagem.value = 'Erro ao salvar';
        return false;
      }
    } catch (e) {
      print('❌ Erro ao salvar: $e');
      Get.snackbar('Erro', 'Erro de conexão ao salvar');
      statusMensagem.value = 'Erro de conexão';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== CARREGAR HISTÓRICO DA API ==========
  Future<void> carregarHistorico() async {
    try {
      if (_usuarioController.idUsuario == null) return;
      
      isLoading.value = true;

      final response = await _api.get('/transcriptions/minhas');

      if (response['success']) {
        final List<dynamic> data = response['data']['transcricoes'];
        
        historico.value = data
            .map((json) => TranscricaoTecnica.fromMap(json))
            .toList();

        print('✅ ${historico.length} transcrições carregadas da API');
      } else {
        print('❌ Erro ao carregar histórico: ${response['error']}');
      }
    } catch (e) {
      print('❌ Erro ao carregar histórico: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== BUSCAR TRANSCRIÇÃO ESPECÍFICA ==========
  Future<TranscricaoTecnica?> buscarTranscricao(int transcricaoId) async {
    try {
      final response = await _api.get('/transcriptions/$transcricaoId');
      
      if (response['success']) {
        return TranscricaoTecnica.fromMap(response['data']['transcricao']);
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar transcrição: $e');
      return null;
    }
  }

  // ========== REMOVER TRANSCRIÇÃO ==========
  Future<bool> removerTranscricao(int transcricaoId) async {
    try {
      final response = await _api.delete('/transcriptions/$transcricaoId');
      
      if (response['success']) {
        historico.removeWhere((t) => t.id == transcricaoId);
        Get.snackbar('Removido', 'Documentação removida');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao remover: $e');
      return false;
    }
  }

  // ========== BUSCAR NO HISTÓRICO (LOCAL) ==========
  List<TranscricaoTecnica> buscarNoHistorico(String termo) {
    if (termo.isEmpty) return historico;
    
    String termoBusca = termo.toLowerCase();
    
    return historico.where((transcricao) {
      return transcricao.titulo.toLowerCase().contains(termoBusca) ||
             transcricao.transcricaoOriginal.toLowerCase().contains(termoBusca) ||
             transcricao.pontosDaAcao.toLowerCase().contains(termoBusca);
    }).toList();
  }

  // ========== ESTATÍSTICAS ==========
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

  // ========== ESTATÍSTICAS DA API ==========
  Future<Map<String, dynamic>> buscarEstatisticasCompletas() async {
    try {
      final response = await _api.get('/transcriptions/stats/resumo');
      
      if (response['success']) {
        return response['data'];
      }
      return {};
    } catch (e) {
      print('❌ Erro ao buscar estatísticas: $e');
      return {};
    }
  }

  // ========== UTILITÁRIOS ==========
  
  void limpar() {
    isGravando.value = false;
    isProcessando.value = false;
    textoTranscrito.value = '';
    textoProcessado.value = '';
    statusMensagem.value = '';
    _textoCompleto = '';
    _inicioGravacao = null;
  }

  String _calcularDuracao() {
    if (_inicioGravacao == null) return 'N/A';
    
    Duration duracao = DateTime.now().difference(_inicioGravacao!);
    int minutos = duracao.inMinutes;
    int segundos = duracao.inSeconds % 60;
    
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  int? _calcularDuracaoSegundos() {
    if (_inicioGravacao == null) return null;
    return DateTime.now().difference(_inicioGravacao!).inSeconds;
  }

  String _formatarDataHora(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> verificarDisponibilidade() async {
    try {
      return await _transcricaoService.isSupported();
    } catch (e) {
      print('❌ Erro ao verificar disponibilidade: $e');
      return false;
    }
  }

  void debugInfo() {
    print('\n🔍 === TRANSCRIÇÃO DEBUG (API) ===');
    print('🎤 Gravando: ${isGravando.value}');
    print('🤖 Processando: ${isProcessando.value}');
    print('📝 Texto: "${textoTranscrito.value}"');
    print('📊 Histórico: ${historico.length} itens');
    print('👤 Usuário: ${_usuarioController.idUsuario}');
    print('🌐 Modo: 100% API (Backend processa IA)');
    print('==================================\n');
  }
}