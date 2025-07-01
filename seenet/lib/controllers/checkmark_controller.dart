import 'package:get/get.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../models/resposta_checkmark.dart';
import '../services/database_helper.dart';

class CheckmarkController extends GetxController {
  RxList<CategoriaCheckmark> categorias = <CategoriaCheckmark>[].obs;
  RxList<Checkmark> checkmarksAtivos = <Checkmark>[].obs;
  RxMap<int, bool> respostas = <int, bool>{}.obs;
  Rx<Avaliacao?> avaliacaoAtual = Rx<Avaliacao?>(null);
  RxInt categoriaAtual = 0.obs;

  @override
  void onInit() {
    super.onInit();
    carregarCategorias();
  }

  // Carregar categorias do SQLite
  Future<void> carregarCategorias() async {
    try {
      categorias.value = await DatabaseHelper.instance.getCategorias();
      print('✅ ${categorias.length} categorias carregadas');
    } catch (e) {
      print('❌ Erro ao carregar categorias: $e');
    }
  }

  // Carregar checkmarks de uma categoria
  Future<void> carregarCheckmarks(int categoriaId) async {
    try {
      categoriaAtual.value = categoriaId;
      checkmarksAtivos.value = await DatabaseHelper.instance.getCheckmarksPorCategoria(categoriaId);
      respostas.clear();
      print('✅ ${checkmarksAtivos.length} checkmarks carregados');
    } catch (e) {
      print('❌ Erro ao carregar checkmarks: $e');
    }
  }

  // Iniciar nova avaliação
  Future<bool> iniciarAvaliacao(int tecnicoId, String titulo) async {
    try {
      Avaliacao novaAvaliacao = Avaliacao(
        tecnicoId: tecnicoId,
        titulo: titulo,
        status: 'em_andamento',
      );
      
      int? avaliacaoId = await DatabaseHelper.instance.criarAvaliacao(novaAvaliacao);
      
      if (avaliacaoId != null) {
        avaliacaoAtual.value = Avaliacao(
          id: avaliacaoId,
          tecnicoId: tecnicoId,
          titulo: titulo,
          status: 'em_andamento',
        );
        print('✅ Avaliação iniciada: $avaliacaoId');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao iniciar avaliação: $e');
      return false;
    }
  }

  // Marcar/desmarcar checkmark
  void toggleCheckmark(int checkmarkId, bool marcado) {
    respostas[checkmarkId] = marcado;
    print('📝 Checkmark $checkmarkId: $marcado');
  }

  // Salvar respostas no SQLite
  Future<bool> salvarRespostas() async {
    try {
      if (avaliacaoAtual.value == null) {
        print('❌ Nenhuma avaliação ativa');
        return false;
      }

      for (var entry in respostas.entries) {
        if (entry.value) { // Só salva os marcados
          RespostaCheckmark resposta = RespostaCheckmark(
            avaliacaoId: avaliacaoAtual.value!.id!,
            checkmarkId: entry.key,
            marcado: entry.value,
          );
          
          await DatabaseHelper.instance.salvarResposta(resposta);
        }
      }
      
      print('✅ ${respostas.length} respostas salvas');
      return true;
    } catch (e) {
      print('❌ Erro ao salvar respostas: $e');
      return false;
    }
  }

  // Finalizar avaliação
  Future<bool> finalizarAvaliacao() async {
    try {
      if (avaliacaoAtual.value == null) return false;
      
      bool sucesso = await DatabaseHelper.instance.finalizarAvaliacao(avaliacaoAtual.value!.id!);
      
      if (sucesso) {
        print('✅ Avaliação finalizada');
      }
      
      return sucesso;
    } catch (e) {
      print('❌ Erro ao finalizar avaliação: $e');
      return false;
    }
  }

  // Limpar dados da avaliação
  void limparAvaliacao() {
    avaliacaoAtual.value = null;
    respostas.clear();
    checkmarksAtivos.clear();
    categoriaAtual.value = 0;
  }

  // Obter checkmarks marcados
  List<int> get checkmarksMarcados {
    return respostas.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  // Obter checkmarks marcados como objetos
  List<Checkmark> get checkmarksObjetosMarcados {
    List<int> idsMarcados = checkmarksMarcados;
    return checkmarksAtivos.where((checkmark) => 
        idsMarcados.contains(checkmark.id)).toList();
  }

  // Obter nome da categoria atual
  String get nomeCategoriaAtual {
    if (categoriaAtual.value == 0) return '';
    CategoriaCheckmark? categoria = categorias.firstWhereOrNull(
      (cat) => cat.id == categoriaAtual.value
    );
    return categoria?.nome ?? '';
  }

  // Verificar se há respostas marcadas
  bool get temRespostasMarcadas {
    return respostas.values.any((marcado) => marcado == true);
  }

  // Contar checkmarks marcados
  int get totalCheckmarksMarcados {
    return respostas.values.where((marcado) => marcado == true).length;
  }

  // Verificar se categoria específica existe
  bool categoriaExiste(int categoriaId) {
    return categorias.any((cat) => cat.id == categoriaId);
  }

  // Obter categoria por ID
  CategoriaCheckmark? getCategoriaById(int categoriaId) {
    try {
      return categorias.firstWhere((cat) => cat.id == categoriaId);
    } catch (e) {
      return null;
    }
  }
}
