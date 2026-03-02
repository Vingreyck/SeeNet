// lib/controllers/checkmark_controller.dart - COM ERROR HANDLER (ROUND 9)
import 'package:get/get.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../controllers/diagnostico_controller.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart'; // ✅ IMPORTAR

class CheckmarkController extends GetxController {
  final ApiService _api = ApiService.instance;

  RxList<CategoriaCheckmark> categorias = <CategoriaCheckmark>[].obs;
  RxList<Checkmark> checkmarksAtivos = <Checkmark>[].obs;
  RxMap<int, bool> respostas = <int, bool>{}.obs;
  Rx<Avaliacao?> avaliacaoAtual = Rx<Avaliacao?>(null);
  RxInt categoriaAtual = 0.obs;
  RxBool isLoading = false.obs;
  
  bool _gerandoDiagnostico = false;

Worker? _categoriasWorker;
Worker? _checkmarksWorker;

  @override
  void onInit() {
    super.onInit();
    //carregarCategorias();
  }

  // ========== CARREGAR CATEGORIAS DA API ==========
  Future<void> carregarCategorias() async {
    try {
      isLoading.value = true;

      final response = await _api.get('/checkmark/categorias');

      if (response['success']) {
        final List<dynamic> data = response['data']['categorias'];
        categorias.value = data
            .map((json) => CategoriaCheckmark.fromMap(json))
            .toList();

        print('✅ ${categorias.length} categorias carregadas da API');
      } else {
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handle(
          response['error'] ?? 'Erro ao carregar categorias',
          context: 'carregarCategorias',
        );
      }
    } catch (e) {
      // ✅ USAR ERROR HANDLER
      ErrorHandler.handle(e, context: 'carregarCategorias');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== SETUP WORKERS ==========
  void _setupWorkers() {
  // Worker 1: Só reagir quando categorias realmente mudarem
  _categoriasWorker = ever(categorias, (callback) {
    print('🔄 Categorias atualizadas: ${categorias.length} itens');
  });

  // Worker 2: Reagir quando categoria atual mudar
  _checkmarksWorker = ever(categoriaAtual, (categoriaId) {
    if (categoriaId > 0) {
      print('🔄 Categoria selecionada: $categoriaId');
    }
  });

  // Worker 3: Debounce para respostas (evitar múltiplos rebuilds)
  debounce(
    respostas,
    (_) {
      print('📊 Total de checkmarks marcados: $totalCheckmarksMarcados');
    },
    time: const Duration(milliseconds: 300),
  );
}
  
  // ========== GERAR DIAGNÓSTICO COM GEMINI ==========
  Future<bool> gerarDiagnosticoComGemini() async {
    if (_gerandoDiagnostico) {
      print('⚠️ Diagnóstico já está sendo gerado, ignorando chamada duplicada');
      return false;
    }
    
    try {
      _gerandoDiagnostico = true;
      
      if (avaliacaoAtual.value == null) {
        print('❌ Nenhuma avaliação ativa');
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handleValidationError('Nenhuma avaliação ativa');
        return false;
      }

      if (categoriaAtual.value == 0) {
        print('❌ Categoria não selecionada');
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handleValidationError('Categoria não identificada');
        return false;
      }

      List<int> checkmarksMarcadosIds = checkmarksMarcados;

      if (checkmarksMarcadosIds.isEmpty) {
        print('⚠️ Nenhum checkmark marcado');
        // ✅ USAR ERROR HANDLER
        ErrorHandler.showWarning('Marque pelo menos um problema');
        return false;
      }

      print('🤖 Iniciando geração de diagnóstico...');
      print('   Avaliação ID: ${avaliacaoAtual.value!.id}');
      print('   Categoria ID: ${categoriaAtual.value}');
      print('   Checkmarks marcados: $checkmarksMarcadosIds');

      final diagnosticoController = Get.find<DiagnosticoController>();
      
      final sucesso = await diagnosticoController.gerarDiagnostico(
        avaliacaoAtual.value!.id!,
        categoriaAtual.value,
        checkmarksMarcadosIds,
      );

      return sucesso;
    } catch (e) {
      print('❌ Erro ao gerar diagnóstico: $e');
      // ✅ USAR ERROR HANDLER
      ErrorHandler.handle(e, context: 'gerarDiagnosticoComGemini');
      return false;
    } finally {
      _gerandoDiagnostico = false;
    }
  }

  // ========== CARREGAR CHECKMARKS DE UMA CATEGORIA ==========
  Future<void> carregarCheckmarks(int categoriaId) async {
    try {
      isLoading.value = true;
      categoriaAtual.value = categoriaId;

      print('📥 Carregando checkmarks da categoria: $categoriaId');

      final response = await _api.get('/checkmark/categoria/$categoriaId');

      print('📦 Response completo: $response');

      if (response['success']) {
        final List<dynamic> data = response['data']['checkmarks'];
        
        print('📋 Total de checkmarks recebidos: ${data.length}');
        
        if (data.isNotEmpty) {
          print('🔍 Primeiro checkmark: ${data.first}');
        }
        
        checkmarksAtivos.value = data.map((json) {
          try {
            return Checkmark.fromMap(json);
          } catch (e) {
            print('❌ Erro ao converter checkmark: $json');
            print('❌ Erro: $e');
            rethrow;
          }
        }).toList();

        respostas.clear();
        print('✅ ${checkmarksAtivos.length} checkmarks carregados');
      } else {
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handle(
          response['error'] ?? 'Erro ao carregar checkmarks',
          context: 'carregarCheckmarks',
        );
      }
    } catch (e) {
      // ✅ USAR ERROR HANDLER
      ErrorHandler.handle(e, context: 'carregarCheckmarks');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== INICIAR NOVA AVALIAÇÃO NA API ==========
  Future<bool> iniciarAvaliacao(int tecnicoId, String titulo) async {
    try {
      isLoading.value = true;

      final response = await _api.post('/avaliacoes', {
        'titulo': titulo,
        'descricao': 'Avaliação técnica',
      });

      if (response['success']) {
        final int avaliacaoId = response['data']['id'];

        avaliacaoAtual.value = Avaliacao(
          id: avaliacaoId,
          tecnicoId: tecnicoId,
          titulo: titulo,
          status: 'em_andamento',
        );

        print('✅ Avaliação iniciada na API: $avaliacaoId');
        return true;
      } else {
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handle(
          response['error'] ?? 'Erro ao iniciar avaliação',
          context: 'iniciarAvaliacao',
        );
        return false;
      }
    } catch (e) {
      // ✅ USAR ERROR HANDLER
      ErrorHandler.handle(e, context: 'iniciarAvaliacao');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== MARCAR/DESMARCAR CHECKMARK ==========
  void toggleCheckmark(int checkmarkId, bool marcado) {
    respostas[checkmarkId] = marcado;
    print('✅ Checkmark $checkmarkId: $marcado');
  }

  // ========== SALVAR RESPOSTAS NA API ==========
  Future<bool> salvarRespostas() async {
    try {
      if (avaliacaoAtual.value == null) {
        print('❌ Nenhuma avaliação ativa');
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handleValidationError('Nenhuma avaliação ativa');
        return false;
      }

      List<int> checkmarksMarcados = respostas.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      if (checkmarksMarcados.isEmpty) {
        // ✅ USAR ERROR HANDLER
        ErrorHandler.showWarning('Marque pelo menos um problema');
        return false;
      }

      print('📤 Salvando respostas:');
      print('   Avaliação ID: ${avaliacaoAtual.value!.id}');
      print('   Total marcados: ${checkmarksMarcados.length}');
      print('   IDs marcados: $checkmarksMarcados');

      isLoading.value = true;

      final payload = {'checkmarks_marcados': checkmarksMarcados};
      print('   Payload: $payload');

      final response = await _api.post(
        '/avaliacoes/${avaliacaoAtual.value!.id}/respostas',
        payload,
      );

      print('📥 Resposta:');
      print('   Success: ${response['success']}');
      print('   Response completo: $response');

      if (response['success']) {
        print('✅ ${checkmarksMarcados.length} respostas salvas na API');
        return true;
      } else {
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handle(
          response['error'] ?? 'Erro ao salvar respostas',
          context: 'salvarRespostas',
        );
        return false;
      }
    } catch (e) {
      // ✅ USAR ERROR HANDLER
      ErrorHandler.handle(e, context: 'salvarRespostas');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== FINALIZAR AVALIAÇÃO NA API ==========
  Future<bool> finalizarAvaliacao() async {
    try {
      if (avaliacaoAtual.value == null) return false;

      isLoading.value = true;

      final response = await _api.put(
        '/avaliacoes/${avaliacaoAtual.value!.id}/finalizar',
        {},
      );

      if (response['success']) {
        print('✅ Avaliação finalizada na API');
        // ✅ USAR ERROR HANDLER PARA SUCESSO
        ErrorHandler.showSuccess('Avaliação finalizada com sucesso');
        return true;
      } else {
        // ✅ USAR ERROR HANDLER
        ErrorHandler.handle(
          response['error'] ?? 'Erro ao finalizar avaliação',
          context: 'finalizarAvaliacao',
        );
        return false;
      }
    } catch (e) {
      // ✅ USAR ERROR HANDLER
      ErrorHandler.handle(e, context: 'finalizarAvaliacao');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== LIMPAR DADOS DA AVALIAÇÃO ==========
  void limparAvaliacao() {
    avaliacaoAtual.value = null;
    respostas.clear();
    checkmarksAtivos.clear();
    categoriaAtual.value = 0;
    _gerandoDiagnostico = false;
    print('✅ Avaliação limpa');
  }

  // ========== GETTERS ÚTEIS ==========

  List<int> get checkmarksMarcados {
    return respostas.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  List<Checkmark> get checkmarksObjetosMarcados {
    List<int> idsMarcados = checkmarksMarcados;
    return checkmarksAtivos
        .where((checkmark) => idsMarcados.contains(checkmark.id))
        .toList();
  }

  String get nomeCategoriaAtual {
    if (categoriaAtual.value == 0) return '';
    CategoriaCheckmark? categoria = categorias.firstWhereOrNull(
            (cat) => cat.id == categoriaAtual.value
    );
    return categoria?.nome ?? '';
  }

  bool get temRespostasMarcadas {
    return respostas.values.any((marcado) => marcado == true);
  }

  int get totalCheckmarksMarcados {
    return respostas.values.where((marcado) => marcado == true).length;
  }

  bool categoriaExiste(int categoriaId) {
    return categorias.any((cat) => cat.id == categoriaId);
  }

  CategoriaCheckmark? getCategoriaById(int categoriaId) {
    try {
      return categorias.firstWhere((cat) => cat.id == categoriaId);
    } catch (e) {
      return null;
    }
    
  }
    @override
  void onClose() {
    _categoriasWorker?.dispose();
    _checkmarksWorker?.dispose();
    super.onClose();
  }
}
