// lib/controllers/diagnostico_controller.dart - VERSÃO API
import 'package:get/get.dart';
import '../models/diagnostico.dart';
import '../services/api_service.dart';

class DiagnosticoController extends GetxController {
  final ApiService _api = ApiService.instance;
  
  RxList<Diagnostico> diagnosticos = <Diagnostico>[].obs;
  RxBool isLoading = false.obs;
  RxString statusMensagem = ''.obs;

  // ========== GERAR DIAGNÓSTICO VIA API ==========
  Future<bool> gerarDiagnostico(
    int avaliacaoId,
    int categoriaId,
    List<int> checkmarksMarcados,
  ) async {
    try {
      isLoading.value = true;
      statusMensagem.value = 'Gerando diagnóstico com IA...';

      final response = await _api.post('/diagnostics/gerar', {
        'avaliacao_id': avaliacaoId,
        'categoria_id': categoriaId,
        'checkmarks_marcados': checkmarksMarcados,
      });

      if (response['success']) {
        statusMensagem.value = 'Diagnóstico gerado com sucesso!';
        
        // Recarregar diagnósticos
        await carregarDiagnosticos(avaliacaoId);
        
        print('✅ Diagnóstico gerado via API');
        
        Get.snackbar(
          'Sucesso',
          'Diagnóstico gerado com sucesso!',
          duration: const Duration(seconds: 3),
        );
        
        return true;
      } else {
        statusMensagem.value = 'Erro ao gerar diagnóstico';
        
        print('❌ Erro ao gerar diagnóstico: ${response['error']}');
        
        Get.snackbar(
          'Erro',
          response['error'] ?? 'Falha ao gerar diagnóstico',
          duration: const Duration(seconds: 4),
        );
        
        return false;
      }
    } catch (e) {
      statusMensagem.value = 'Erro de conexão';
      
      print('❌ Erro ao gerar diagnóstico: $e');
      
      Get.snackbar(
        'Erro de Conexão',
        'Não foi possível gerar o diagnóstico',
        duration: const Duration(seconds: 4),
      );
      
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== CARREGAR DIAGNÓSTICOS DA API ==========
  Future<void> carregarDiagnosticos(int avaliacaoId) async {
    try {
      isLoading.value = true;

      final response = await _api.get('/diagnostics/avaliacao/$avaliacaoId');

      if (response['success']) {
        final List<dynamic> data = response['data']['diagnosticos'];
        
        diagnosticos.value = data
            .map((json) => Diagnostico.fromMap(json))
            .toList();

        print('✅ ${diagnosticos.length} diagnósticos carregados da API');
      } else {
        print('❌ Erro ao carregar diagnósticos: ${response['error']}');
      }
    } catch (e) {
      print('❌ Erro ao carregar diagnósticos: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ========== VER DIAGNÓSTICO COMPLETO ==========
  Future<Diagnostico?> verDiagnostico(int diagnosticoId) async {
    try {
      isLoading.value = true;

      final response = await _api.get('/diagnostics/$diagnosticoId');

      if (response['success']) {
        final data = response['data']['diagnostico'];
        return Diagnostico.fromMap(data);
      } else {
        print('❌ Erro ao buscar diagnóstico: ${response['error']}');
        return null;
      }
    } catch (e) {
      print('❌ Erro ao buscar diagnóstico: $e');
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== LIMPAR DIAGNÓSTICOS ==========
  void limparDiagnosticos() {
    diagnosticos.clear();
    statusMensagem.value = '';
    print('✅ Diagnósticos limpos');
  }

  // ========== LIMPAR STATUS ==========
  void limparStatus() {
    statusMensagem.value = '';
  }

  // ========== GETTERS ==========
  
  bool get temDiagnosticos => diagnosticos.isNotEmpty;

  Diagnostico? get ultimoDiagnostico {
    if (diagnosticos.isEmpty) return null;
    return diagnosticos.first;
  }

  int contarPorStatus(String status) {
    return diagnosticos.where((d) => d.statusApi == status).length;
  }

  // ========== INFO SOBRE SERVIÇO ==========
  
  Map<String, String> get infoServico {
    return {
      'Nome': 'Google Gemini via API',
      'Modo': 'Produção (API Node.js)',
      'Qualidade': 'Alta',
      'Status': 'Ativo',
    };
  }

  void debugInfo() {
    print('\n🔍 === DIAGNÓSTICO DEBUG ===');
    print('📊 Total diagnósticos: ${diagnosticos.length}');
    print('✅ Sucesso: ${contarPorStatus('sucesso')}');
    print('❌ Erro: ${contarPorStatus('erro')}');
    print('📡 Carregando: $isLoading');
    print('💬 Status: $statusMensagem');
    print('============================\n');
  }
}