import 'package:get/get.dart';
import 'api_service.dart';

class CategoriaService extends GetxService {
  final ApiService _apiService = Get.find<ApiService>();

  // Listar categorias
  Future<List<Map<String, dynamic>>> listarCategorias() async {
    try {
      final response = await _apiService.get('/admin/categorias');
      
      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['data'] ?? []);
      }
      
      throw Exception(response['error'] ?? 'Erro ao listar categorias');
    } catch (e) {
      print('Erro ao listar categorias: $e');
      rethrow;
    }
  }

  // Criar categoria
  Future<Map<String, dynamic>> criarCategoria({
    required String nome,
    String? descricao,
    int? ordem,
  }) async {
    try {
      final response = await _apiService.post(
        '/admin/categorias',
        {
          'nome': nome,
          'descricao': descricao,
          'ordem': ordem,
        },
      );

      if (response['success'] == true) {
        return response['data'];
      }

      throw Exception(response['error'] ?? 'Erro ao criar categoria');
    } catch (e) {
      print('Erro ao criar categoria: $e');
      rethrow;
    }
  }

  // Atualizar categoria
  Future<Map<String, dynamic>> atualizarCategoria({
    required int id,
    String? nome,
    String? descricao,
    int? ordem,
    bool? ativo,
  }) async {
    try {
      // Construir body apenas com campos não-nulos
      final Map<String, dynamic> body = {};
      if (nome != null) body['nome'] = nome;
      if (descricao != null) body['descricao'] = descricao;
      if (ordem != null) body['ordem'] = ordem;
      if (ativo != null) body['ativo'] = ativo; // ← Boolean direto

      print('🌐 PUT /admin/categorias/$id');
      print('📦 Body: $body');

      final response = await _apiService.put(
        '/admin/categorias/$id',
        body,
      );

      if (response['success'] == true) {
        return response['data'];
      }

      throw Exception(response['error'] ?? 'Erro ao atualizar categoria');
    } catch (e) {
      print('❌ Erro ao atualizar categoria: $e');
      rethrow;
    }
  }

  // Deletar categoria
  Future<void> deletarCategoria(int id) async {
    try {
      final response = await _apiService.delete('/admin/categorias/$id');

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Erro ao deletar categoria');
      }
    } catch (e) {
      print('Erro ao deletar categoria: $e');
      rethrow;
    }
  }

  // Reordenar categorias
  Future<void> reordenarCategorias(
    List<Map<String, dynamic>> categorias,
  ) async {
    try {
      final response = await _apiService.post(
        '/admin/categorias/reordenar',
        {'categorias': categorias},
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Erro ao reordenar categorias');
      }
    } catch (e) {
      print('Erro ao reordenar categorias: $e');
      rethrow;
    }
  }
}