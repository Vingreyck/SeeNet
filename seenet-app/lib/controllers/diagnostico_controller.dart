// lib/controllers/diagnostico_controller.dart - VERSÃO CORRIGIDA COM PARSE CORRETO
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

      final response = await _api.post(
        '/diagnostics/gerar',
        {
          'avaliacao_id': avaliacaoId,
          'categoria_id': categoriaId,
          'checkmarks_marcados': checkmarksMarcados,
        },
        requireAuth: true,
      );

      print('📥 Response: $response');

      // ✅ CORREÇÃO CRÍTICA: Parse do nested data
      if (response['success'] == true) {
        // O backend retorna: { success: true, data: { success: true, data: {...} } }
        // Precisamos acessar response['data']['data']
        
        final outerData = response['data'];
        if (outerData == null) {
          throw Exception('Response data is null');
        }
        
        // Verificar se tem success interno
        if (outerData['success'] != true) {
          throw Exception(outerData['error'] ?? 'Erro desconhecido');
        }
        
        // Pegar o data interno
        final diagnosticoData = outerData['data'];
        if (diagnosticoData == null) {
          throw Exception('Diagnostico data is null');
        }
        
        statusMensagem.value = '✅ Diagnóstico gerado com sucesso!';
        
        print('\n📥 DADOS RECEBIDOS DA API:');
        print('ID: ${diagnosticoData['id']}');
        print('Status: ${diagnosticoData['status']}');
        print('Modelo: ${diagnosticoData['modelo']}');
        print('Tokens: ${diagnosticoData['tokens_utilizados']}');
        print('Resposta length: ${diagnosticoData['resposta']?.toString().length ?? 0}');
        
        // Limpar diagnósticos anteriores
        diagnosticos.clear();
        
        // ✅ CRIAR DIAGNÓSTICO COM DADOS CORRETOS
        final novoDiagnostico = Diagnostico(
          id: diagnosticoData['id'],
          avaliacaoId: avaliacaoId,
          categoriaId: categoriaId,
          promptEnviado: '', // Backend não retorna isso na geração
          respostaChatgpt: diagnosticoData['resposta'] ?? 'Diagnóstico não disponível',
          resumoDiagnostico: diagnosticoData['resumo'] ?? 'Resumo não disponível',
          statusApi: diagnosticoData['status'] ?? 'sucesso',
          tokensUtilizados: diagnosticoData['tokens_utilizados'] ?? 0,
          dataCriacao: DateTime.now(),
        );

        // Debug do diagnóstico criado
        print('\n🔍 DIAGNÓSTICO CRIADO:');
        print('ID: ${novoDiagnostico.id}');
        print('Status: ${novoDiagnostico.statusApi}');
        print('Tokens: ${novoDiagnostico.tokensUtilizados}');
        print('Resposta length: ${novoDiagnostico.respostaChatgpt.length}');
        print('Resposta preview: ${novoDiagnostico.respostaChatgpt.substring(0, novoDiagnostico.respostaChatgpt.length > 100 ? 100 : novoDiagnostico.respostaChatgpt.length)}...');
        
        diagnosticos.add(novoDiagnostico);
        
        print('✅ Diagnóstico adicionado à lista (total: ${diagnosticos.length})');
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
    } catch (e, stackTrace) {
      statusMensagem.value = '❌ Erro de conexão';
      
      print('❌ Exceção ao gerar diagnóstico: $e');
      print('Stack trace: $stackTrace');
      
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

      final response = await _api.get(
        '/diagnostics/avaliacao/$avaliacaoId',
        requireAuth: true,
      );

      if (response['success'] == true) {
        final List<dynamic> data = response['data']['diagnosticos'] ?? [];
        
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

      final response = await _api.get(
        '/diagnostics/$diagnosticoId',
        requireAuth: true,
      );

      if (response['success'] == true) {
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
    
    if (diagnosticos.isNotEmpty) {
      print('\n📋 Último diagnóstico:');
      final ultimo = ultimoDiagnostico!;
      print('   ID: ${ultimo.id}');
      print('   Status: ${ultimo.statusApi}');
      print('   Tokens: ${ultimo.tokensUtilizados}');
      print('   Resposta: ${ultimo.respostaChatgpt.substring(0, ultimo.respostaChatgpt.length > 50 ? 50 : ultimo.respostaChatgpt.length)}...');
    }
    
    print('============================\n');
  }
}