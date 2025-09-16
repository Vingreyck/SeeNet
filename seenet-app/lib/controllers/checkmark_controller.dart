import 'package:get/get.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../models/resposta_checkmark.dart';
import '../services/database_helper.dart';
import '../services/audit_service.dart';
import './usuario_controller.dart';

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
      print('📁 ${categorias.length} categorias carregadas');
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
        print('🚀 Avaliação iniciada: $avaliacaoId');
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
    print('✅ Checkmark $checkmarkId: $marcado');
  }

  // Salvar respostas no SQLite
  Future<bool> salvarRespostas() async {
    try {
      if (avaliacaoAtual.value == null) {
        print('⚠️ Nenhuma avaliação ativa');
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

      // Adicionar log de auditoria
      await AuditService.instance.log(
        action: AuditAction.evaluationCompleted,
        usuarioId: Get.find<UsuarioController>().idUsuario,
        tabelaAfetada: 'avaliacoes',
        registroId: avaliacaoAtual.value!.id,
      );
      
      print('💾 ${respostas.length} respostas salvas');
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
        print('🏁 Avaliação finalizada');
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

  // ✅ CORRIGIDO: Obter nome da categoria atual (com null safety)
  String get nomeCategoriaAtual {
    if (categoriaAtual.value == 0) return '';
    
    try {
      CategoriaCheckmark? categoria = categorias.firstWhereOrNull(
        (cat) => cat.id == categoriaAtual.value
      );
      
      // ✅ Verificação segura da categoria e do nome
      return categoria?.nome ?? 'Categoria não encontrada';
    } catch (e) {
      print('❌ Erro ao obter nome da categoria: $e');
      return 'Erro ao carregar categoria';
    }
  }

  // Verificar se há respostas marcadas
  bool get temRespostasMarcadas {
    return respostas.values.any((marcado) => marcado == true);
  }

  // Contar checkmarks marcados
  int get totalCheckmarksMarcados {
    return respostas.values.where((marcado) => marcado == true).length;
  }

  // ✅ CORRIGIDO: Verificar se categoria específica existe (com null safety)
  bool categoriaExiste(int categoriaId) {
    try {
      return categorias.any((cat) => cat.id == categoriaId);
    } catch (e) {
      print('❌ Erro ao verificar categoria: $e');
      return false;
    }
  }

  // ✅ CORRIGIDO: Obter categoria por ID (com null safety)
  CategoriaCheckmark? getCategoriaById(int categoriaId) {
    try {
      return categorias.firstWhereOrNull((cat) => cat.id == categoriaId);
    } catch (e) {
      print('❌ Erro ao buscar categoria por ID: $e');
      return null;
    }
  }

  // ✅ NOVO: Obter nome da categoria por ID (método auxiliar seguro)
  String getNomeCategoriaById(int categoriaId) {
    try {
      CategoriaCheckmark? categoria = getCategoriaById(categoriaId);
      return categoria?.nome ?? 'Categoria não encontrada';
    } catch (e) {
      print('❌ Erro ao obter nome da categoria por ID: $e');
      return 'Erro ao carregar categoria';
    }
  }

  // ✅ NOVO: Verificar se as categorias estão carregadas
  bool get categoriasCarregadas {
    return categorias.isNotEmpty;
  }

  // ✅ NOVO: Recarregar dados se necessário
  Future<void> recarregarDadosSeNecessario() async {
    if (!categoriasCarregadas) {
      await carregarCategorias();
    }
  }

  // ✅ NOVO: Obter estatísticas das respostas
  Map<String, dynamic> get estatisticasRespostas {
    int totalCheckmarks = checkmarksAtivos.length;
    int marcados = totalCheckmarksMarcados;
    double percentual = totalCheckmarks > 0 ? (marcados / totalCheckmarks) * 100 : 0;
    
    return {
      'total': totalCheckmarks,
      'marcados': marcados,
      'naoMarcados': totalCheckmarks - marcados,
      'percentualMarcados': percentual.round(),
    };
  }

  // ✅ NOVO: Debug - mostrar status atual
  void debugStatus() {
    print('\n📊 === CHECKMARK CONTROLLER STATUS ===');
    print('📁 Categorias carregadas: ${categorias.length}');
    print('✅ Checkmarks ativos: ${checkmarksAtivos.length}');
    print('📝 Respostas marcadas: $totalCheckmarksMarcados');
    print('🎯 Categoria atual: ${categoriaAtual.value}');
    print('📋 Nome categoria atual: "$nomeCategoriaAtual"');
    print('🚀 Avaliação ativa: ${avaliacaoAtual.value?.id ?? 'Nenhuma'}');
    
    if (categorias.isNotEmpty) {
      print('📂 Categorias disponíveis:');
      for (var categoria in categorias) {
        print('   • ID: ${categoria.id} - Nome: "${categoria.nome}"');
      }
    }
    
    print('════════════════════════════════════════\n');
  }

  // ✅ NOVO: Validar integridade dos dados
  Future<bool> validarIntegridade() async {
    try {
      // Verificar se categorias estão carregadas
      if (!categoriasCarregadas) {
        print('⚠️ Categorias não carregadas, tentando carregar...');
        await carregarCategorias();
      }

      // Verificar se categoria atual é válida
      if (categoriaAtual.value > 0 && !categoriaExiste(categoriaAtual.value)) {
        print('⚠️ Categoria atual inválida: ${categoriaAtual.value}');
        categoriaAtual.value = 0;
        checkmarksAtivos.clear();
        respostas.clear();
        return false;
      }

      // Verificar se checkmarks são da categoria correta
      if (categoriaAtual.value > 0) {
        bool todosValidos = checkmarksAtivos.every(
          (checkmark) => checkmark.categoriaId == categoriaAtual.value
        );
        
        if (!todosValidos) {
          print('⚠️ Checkmarks não correspondem à categoria atual');
          await carregarCheckmarks(categoriaAtual.value);
          return false;
        }
      }

      print('✅ Integridade dos dados validada');
      return true;
    } catch (e) {
      print('❌ Erro na validação de integridade: $e');
      return false;
    }
  }
}