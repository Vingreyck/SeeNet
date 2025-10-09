import 'package:get/get.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class AvaliacaoService extends GetxService {
  final ApiService _api = ApiService.instance;

  // ========== CRIAR AVALIAÇÃO ==========
  Future<int?> criarAvaliacao({
    String? titulo,
    String? descricao,
  }) async {
    try {
      print('📝 Criando avaliação...');
      
      final response = await _api.post(
        'criarAvaliacao', // Usar a key do endpoints map
        {
          if (titulo != null) 'titulo': titulo,
          if (descricao != null) 'descricao': descricao,
        },
      );

      print('📦 Response recebido: $response');

      if (response['success'] == true) {
        // ✅ CORREÇÃO: Backend retorna { success: true, data: { message, id } }
        final data = response['data'];
        
        print('📊 Data extraído: $data');
        print('📊 Tipo do data: ${data.runtimeType}');
        
        // O ID pode estar em diferentes locais
        dynamic avaliacaoIdDynamic;
        
        if (data is Map) {
          avaliacaoIdDynamic = data['id'];
          print('🔍 ID encontrado (raw): $avaliacaoIdDynamic (tipo: ${avaliacaoIdDynamic.runtimeType})');
        }
        
        // Converter para int de forma segura
        int? avaliacaoId;
        if (avaliacaoIdDynamic != null) {
          if (avaliacaoIdDynamic is int) {
            avaliacaoId = avaliacaoIdDynamic;
          } else if (avaliacaoIdDynamic is String) {
            avaliacaoId = int.tryParse(avaliacaoIdDynamic);
          } else if (avaliacaoIdDynamic is List && avaliacaoIdDynamic.isNotEmpty) {
            // Caso o Knex retorne array [id]
            avaliacaoId = avaliacaoIdDynamic[0] is int 
                ? avaliacaoIdDynamic[0] 
                : int.tryParse(avaliacaoIdDynamic[0].toString());
          }
        }
        
        if (avaliacaoId != null) {
          print('✅ Avaliação criada com ID: $avaliacaoId');
          return avaliacaoId;
        } else {
          print('⚠️ Avaliação criada, mas ID não pôde ser convertido');
          print('📦 Valor raw do ID: $avaliacaoIdDynamic');
          return null;
        }
      } else {
        print('❌ Erro ao criar avaliação: ${response['error']}');
        throw Exception(response['error'] ?? 'Erro ao criar avaliação');
      }
    } catch (e) {
      print('❌ Exceção ao criar avaliação: $e');
      rethrow;
    }
  }

  // ========== FINALIZAR AVALIAÇÃO ==========
  Future<bool> finalizarAvaliacao(int avaliacaoId) async {
    try {
      print('🏁 Finalizando avaliação $avaliacaoId...');
      
      // Construir URL manualmente com o ID
      final response = await _api.put(
        'avaliacoes/$avaliacaoId/finalizar', // URL customizada
        {},
      );

      if (response['success'] == true) {
        print('✅ Avaliação finalizada');
        return true;
      } else {
        print('❌ Erro ao finalizar: ${response['error']}');
        return false;
      }
    } catch (e) {
      print('❌ Exceção ao finalizar avaliação: $e');
      return false;
    }
  }

  // ========== SALVAR RESPOSTAS DE CHECKMARKS ==========
  Future<bool> salvarRespostas({
    required int avaliacaoId,
    required List<int> checkmarksMarcados,
  }) async {
    try {
      print('💾 Salvando ${checkmarksMarcados.length} respostas...');
      
      final response = await _api.post(
        'avaliacoes/$avaliacaoId/respostas',
        {
          'checkmarks_marcados': checkmarksMarcados,
        },
      );

      if (response['success'] == true) {
        print('✅ Respostas salvas');
        return true;
      } else {
        print('❌ Erro ao salvar respostas: ${response['error']}');
        return false;
      }
    } catch (e) {
      print('❌ Exceção ao salvar respostas: $e');
      return false;
    }
  }

  // ========== LISTAR MINHAS AVALIAÇÕES ==========
  Future<Map<String, dynamic>> listarMinhasAvaliacoes({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      print('📋 Listando avaliações (página $page)...');
      
      Map<String, String> params = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (status != null) {
        params['status'] = status;
      }

      final response = await _api.get(
        'minhasAvaliacoes',
        queryParams: params,
      );

      if (response['success'] == true) {
        final data = response['data'];
        print('✅ ${data['avaliacoes']?.length ?? 0} avaliações carregadas');
        return data;
      } else {
        print('❌ Erro ao listar: ${response['error']}');
        throw Exception(response['error']);
      }
    } catch (e) {
      print('❌ Exceção ao listar avaliações: $e');
      rethrow;
    }
  }

  // ========== VER AVALIAÇÃO ESPECÍFICA ==========
  Future<Map<String, dynamic>?> verAvaliacao(int avaliacaoId) async {
    try {
      print('🔍 Buscando avaliação $avaliacaoId...');
      
      final response = await _api.get('avaliacoes/$avaliacaoId');

      if (response['success'] == true) {
        final avaliacao = response['data']['avaliacao'];
        print('✅ Avaliação encontrada');
        return avaliacao;
      } else {
        print('❌ Erro ao buscar: ${response['error']}');
        return null;
      }
    } catch (e) {
      print('❌ Exceção ao buscar avaliação: $e');
      return null;
    }
  }

  // ========== CRIAR E SALVAR AVALIAÇÃO COMPLETA ==========
  // Método helper que combina criação + salvamento de respostas
  Future<int?> criarAvaliacaoCompleta({
    String? titulo,
    String? descricao,
    required List<int> checkmarksMarcados,
  }) async {
    try {
      // 1. Criar avaliação
      final avaliacaoId = await criarAvaliacao(
        titulo: titulo,
        descricao: descricao,
      );

      if (avaliacaoId == null) {
        throw Exception('Falha ao criar avaliação - ID não retornado');
      }

      // 2. Salvar respostas
      final respostasSalvas = await salvarRespostas(
        avaliacaoId: avaliacaoId,
        checkmarksMarcados: checkmarksMarcados,
      );

      if (!respostasSalvas) {
        print('⚠️ Avaliação criada, mas respostas não foram salvas');
      }

      return avaliacaoId;
    } catch (e) {
      print('❌ Erro ao criar avaliação completa: $e');
      rethrow;
    }
  }
}