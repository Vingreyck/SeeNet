// lib/controllers/diagnostico_controller.dart - VERSÃO CORRIGIDA COM PARSE CORRETO
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/diagnostico.dart';
import '../utils/error_handler.dart';
import '../services/api_service.dart';

class DiagnosticoController extends GetxController {
  final ApiService _api = ApiService.instance;
  
  RxList<Diagnostico> diagnosticos = <Diagnostico>[].obs;
  RxBool isLoading = false.obs;
  RxString statusMensagem = ''.obs;

Worker? _diagnosticosWorker;
Worker? _loadingWorker;

@override
void onInit() {
  super.onInit();
  _setupWorkers();
}

void _setupWorkers() {
  // Worker 1: Notificar quando novos diagnósticos forem adicionados
  _diagnosticosWorker = ever(diagnosticos, (callback) {
    if (diagnosticos.isNotEmpty) {
      print('🤖 Total de diagnósticos: ${diagnosticos.length}');
    }
  });

  // Worker 2: Monitorar mudanças de loading
  _loadingWorker = ever(isLoading, (loading) {
    if (loading) {
      print('⏳ Diagnóstico: Carregando...');
    } else {
      print('✅ Diagnóstico: Carregamento concluído');
    }
  });
}


  // ========== GERAR DIAGNÓSTICO VIA API ==========
Future<bool> gerarDiagnostico(
  int avaliacaoId,
  int categoriaId,
  List<int> checkmarksMarcadosIds,
) async {
  try {
    isLoading.value = true;
    statusMensagem.value = 'Gerando diagnóstico com IA...';

    print('🚀 Gerando diagnóstico...');
    print('   Avaliação: $avaliacaoId');
    print('   Categoria: $categoriaId');
    print('   Checkmarks: $checkmarksMarcadosIds');

    if (checkmarksMarcadosIds.isEmpty) {
      statusMensagem.value = 'Nenhum problema selecionado';
      ErrorHandler.showWarning('Selecione pelo menos um problema');
      return false;
    }

    final response = await _api.post(
      '/diagnostics/gerar',
      {
        'avaliacao_id': avaliacaoId,
        'categoria_id': categoriaId,
        'checkmarks_marcados': checkmarksMarcadosIds,
      },
    );

    print('📥 Response: $response');

    if (response['success'] == true) {
      // Verificar estrutura da resposta
      final data = response['data'];
      
      if (data == null) {
        print('❌ Resposta sem data');
        statusMensagem.value = 'Erro: resposta inválida';
        return false;
      }

      // Criar objeto Diagnostico
      final diagnostico = Diagnostico(
        id: data['id'],
        avaliacaoId: avaliacaoId,
        categoriaId: categoriaId,
        promptEnviado: 'Checkmarks: $checkmarksMarcadosIds',
        respostaChatgpt: data['resposta'] ?? data['respostaChatgpt'] ?? '',
        resumoDiagnostico: data['resumo'] ?? data['resumoDiagnostico'],
        statusApi: data['status'] ?? 'sucesso',
        tokensUtilizados: data['tokens_utilizados'],
        dataCriacao: DateTime.now(),
      );

      // Verificar se resposta não está vazia
      if (diagnostico.respostaChatgpt.isEmpty) {
        print('❌ Diagnóstico sem conteúdo');
        statusMensagem.value = 'Erro: diagnóstico vazio';
        return false;
      }

      // Adicionar à lista
      diagnosticos.add(diagnostico);
      
      statusMensagem.value = 'Diagnóstico gerado com sucesso!';
      print('✅ Diagnóstico adicionado à lista');
      print('   Total de diagnósticos: ${diagnosticos.length}');
      
      return true;
    } else {
      final errorMsg = response['error'] ?? 'Erro desconhecido';
      print('❌ Erro na API: $errorMsg');
      statusMensagem.value = 'Erro: $errorMsg';
      
      ErrorHandler.handle(errorMsg, context: 'gerarDiagnostico');
      
      return false;
    }
  } catch (e, stackTrace) {
    print('❌ Exceção ao gerar diagnóstico: $e');
    print('Stack trace: $stackTrace');
    
    statusMensagem.value = 'Erro ao conectar com servidor';
    
    ErrorHandler.handle(e, context: 'gerarDiagnostico');
    
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

    @override
  void onClose() {
    _diagnosticosWorker?.dispose();
    _loadingWorker?.dispose();
    super.onClose();
  }
}