// lib/controllers/diagnostico_controller.dart - VERSÃO CORRIGIDA
import 'package:flutter/material.dart';
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
      statusMensagem.value = '🤖 Gerando diagnóstico com IA...';

      print('🚀 Gerando diagnóstico...');
      print('   Avaliação: $avaliacaoId');
      print('   Categoria: $categoriaId');
      print('   Checkmarks: $checkmarksMarcados');

      final response = await _api.post('/diagnostics/gerar', { // ✅ COM "s" para bater com backend
        'avaliacao_id': avaliacaoId,
        'categoria_id': categoriaId,
        'checkmarks_marcados': checkmarksMarcados,
      });

      print('📥 Response: $response');

      // ✅ Verificar se houve sucesso OU se retornou mensagem
      if (response['success'] == true || response['message'] != null) {
        statusMensagem.value = '✅ Diagnóstico gerado com sucesso!';
        
        // Limpar diagnósticos anteriores
        diagnosticos.clear();
        
        // Criar diagnóstico a partir da resposta
        // O backend retorna: { message, id, resumo, tokens_utilizados }
        final id = response['id'];
        final resumo = response['resumo'] ?? response['message'] ?? 'Diagnóstico gerado';
        final tokens = response['tokens_utilizados'];
        
        final novoDiagnostico = Diagnostico(
          id: id,
          avaliacaoId: avaliacaoId,
          categoriaId: categoriaId,
          promptEnviado: '',
          respostaChatgpt: resumo,
          resumoDiagnostico: resumo,
          statusApi: 'sucesso',
          tokensUtilizados: tokens,
          dataCriacao: DateTime.now(),
        );
        
        diagnosticos.add(novoDiagnostico);
        
        print('✅ Diagnóstico gerado via API');
        print('   ID: ${novoDiagnostico.id}');
        print('   Tokens: ${novoDiagnostico.tokensUtilizados}');
        
        Get.snackbar(
          'Sucesso',
          'Diagnóstico gerado com sucesso!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
          duration: const Duration(seconds: 2),
        );
        
        return true;
      } else {
        statusMensagem.value = '❌ Erro ao gerar diagnóstico';
        
        print('❌ Erro ao gerar diagnóstico: ${response['error']}');
        
        Get.snackbar(
          'Erro',
          response['error'] ?? 'Falha ao gerar diagnóstico',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        
        return false;
      }
    } catch (e) {
      statusMensagem.value = '❌ Erro de conexão';
      
      print('❌ Exceção ao gerar diagnóstico: $e');
      
      Get.snackbar(
        'Erro de Conexão',
        'Não foi possível gerar o diagnóstico: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
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

      final response = await _api.get('/diagnostics/avaliacao/$avaliacaoId'); // ✅ COM "s"

      if (response['success'] == true || response['diagnosticos'] != null) {
        final List<dynamic> data = response['diagnosticos'] ?? [];
        
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

      final response = await _api.get('/diagnostics/$diagnosticoId'); // ✅ COM "s"

      if (response['success'] == true) {
        final data = response['diagnostico'];
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