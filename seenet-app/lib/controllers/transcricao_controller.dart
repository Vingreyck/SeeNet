// lib/controllers/transcricao_controller.dart - VERSÃO API (CORRIGIDA)
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
        await _processarComIA(texto);
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
        statusMensagem.value = 'Processando com IA...';
        await _processarComIA(_textoCompleto);
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
💡 **Dica:** A IA está processando via API Node.js para melhor detalhamento.""";
  }

  // ========== SALVAR TRANSCRIÇÃO VIA API ==========
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

      final response = await _api.post('/transcriptions', {
        'titulo': titulo,
        'transcricao_original': textoTranscrito.value,
        'pontos_da_acao': textoProcessado.value,
        'duracao_segundos': _calcularDuracaoSegundos(),
        'descricao': 'Documentação técnica',
      });

      if (response['success']) {
        await carregarHistorico();
        print('✅ Transcrição salva na API');

        Get.snackbar(
          'Sucesso',
          'Documentação salva com sucesso!',
          duration: const Duration(seconds: 2),
        );

        return true;
      } else {
        print('❌ Erro ao salvar: ${response['error']}');
        Get.snackbar('Erro', 'Falha ao salvar documentação');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao salvar: $e');
      Get.snackbar('Erro', 'Erro de conexão ao salvar');
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

  List<TranscricaoTecnica> buscarNoHistorico(String termo) {
    if (termo.isEmpty) return historico;

    String termoBusca = termo.toLowerCase();

    return historico.where((transcricao) {
      return transcricao.titulo.toLowerCase().contains(termoBusca) ||
          transcricao.transcricaoOriginal.toLowerCase().contains(termoBusca) ||
          transcricao.pontosDaAcao.toLowerCase().contains(termoBusca);
    }).toList();
  }

  void debugInfo() {
    print('\n🔍 === TRANSCRIÇÃO DEBUG ===');
    print('🎤 Gravando: ${isGravando.value}');
    print('🤖 Processando: ${isProcessando.value}');
    print('📝 Texto: "${textoTranscrito.value}"');
    print('📊 Histórico: ${historico.length} itens');
    print('👤 Usuário: ${_usuarioController.idUsuario}');
    print('=============================\n');
  }
}