// lib/controllers/checkmark_controller.dart - VERSÃO CORRIGIDA SEM DUPLA CHAMADA
import 'package:get/get.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../controllers/diagnostico_controller.dart';
import '../services/api_service.dart';

class CheckmarkController extends GetxController {
  final ApiService _api = ApiService.instance;

  RxList<CategoriaCheckmark> categorias = <CategoriaCheckmark>[].obs;
  RxList<Checkmark> checkmarksAtivos = <Checkmark>[].obs;
  RxMap<int, bool> respostas = <int, bool>{}.obs;
  Rx<Avaliacao?> avaliacaoAtual = Rx<Avaliacao?>(null);
  RxInt categoriaAtual = 0.obs;
  RxBool isLoading = false.obs;
  
  // ✅ ADICIONAR FLAG PARA EVITAR CHAMADA DUPLICADA
  bool _gerandoDiagnostico = false;

  @override
  void onInit() {
    super.onInit();
    carregarCategorias();
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
        print('❌ Erro ao carregar categorias: ${response['error']}');
        Get.snackbar('Erro', 'Falha ao carregar categorias');
      }
    } catch (e) {
      print('❌ Erro ao carregar categorias: $e');
      Get.snackbar('Erro', 'Erro de conexão ao carregar categorias');
    } finally {
      isLoading.value = false;
    }
  }
  
  // ========== GERAR DIAGNÓSTICO COM GEMINI ==========
  Future<bool> gerarDiagnosticoComGemini() async {
    // ✅ PREVENIR CHAMADA DUPLICADA
    if (_gerandoDiagnostico) {
      print('⚠️ Diagnóstico já está sendo gerado, ignorando chamada duplicada');
      return false;
    }
    
    try {
      // ✅ MARCAR COMO GERANDO
      _gerandoDiagnostico = true;
      
      if (avaliacaoAtual.value == null) {
        print('❌ Nenhuma avaliação ativa');
        Get.snackbar('Erro', 'Nenhuma avaliação ativa');
        return false;
      }

      if (categoriaAtual.value == 0) {
        print('❌ Categoria não selecionada');
        Get.snackbar('Erro', 'Categoria não identificada');
        return false;
      }

      List<int> checkmarksMarcadosIds = checkmarksMarcados;

      if (checkmarksMarcadosIds.isEmpty) {
        print('⚠️ Nenhum checkmark marcado');
        Get.snackbar('Aviso', 'Marque pelo menos um problema');
        return false;
      }

      print('🤖 Iniciando geração de diagnóstico...');
      print('   Avaliação ID: ${avaliacaoAtual.value!.id}');
      print('   Categoria ID: ${categoriaAtual.value}');
      print('   Checkmarks marcados: $checkmarksMarcadosIds');

      // Usar o DiagnosticoController
      final diagnosticoController = Get.find<DiagnosticoController>();
      
      final sucesso = await diagnosticoController.gerarDiagnostico(
        avaliacaoAtual.value!.id!,
        categoriaAtual.value,
        checkmarksMarcadosIds,
      );

      return sucesso;
    } catch (e) {
      print('❌ Erro ao gerar diagnóstico: $e');
      Get.snackbar('Erro', 'Falha na comunicação com a IA: $e');
      return false;
    } finally {
      // ✅ LIBERAR FLAG
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
      
      // Debug: mostrar primeiro item
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
      print('❌ Erro ao carregar checkmarks: ${response['error']}');
      Get.snackbar('Erro', 'Falha ao carregar checkmarks');
    }
  } catch (e) {
    print('❌ Erro ao carregar checkmarks: $e');
    Get.snackbar('Erro', 'Erro de conexão ao carregar checkmarks');
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
        print('❌ Erro ao iniciar avaliação: ${response['error']}');
        Get.snackbar('Erro', 'Falha ao iniciar avaliação');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao iniciar avaliação: $e');
      Get.snackbar('Erro', 'Erro de conexão ao iniciar avaliação');
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
        Get.snackbar('Erro', 'Nenhuma avaliação ativa');
        return false;
      }

      List<int> checkmarksMarcados = respostas.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      if (checkmarksMarcados.isEmpty) {
        Get.snackbar('Aviso', 'Marque pelo menos um problema');
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
        print('❌ Erro ao salvar respostas: ${response['error']}');
        Get.snackbar('Erro', 'Falha ao salvar respostas');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao salvar respostas: $e');
      Get.snackbar('Erro', 'Erro de conexão ao salvar respostas');
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
        return true;
      } else {
        print('❌ Erro ao finalizar: ${response['error']}');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao finalizar avaliação: $e');
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
    _gerandoDiagnostico = false; // ✅ RESETAR FLAG
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
}