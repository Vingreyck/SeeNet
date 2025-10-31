import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/categoria_service.dart';

class CategoriaAdminController extends GetxController {
  final CategoriaService _categoriaService = Get.find<CategoriaService>();

  var categorias = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var statusMensagem = ''.obs;

  @override
  void onInit() {
    super.onInit();
    carregarCategorias();
  }

  Future<void> carregarCategorias() async {
    try {
      isLoading.value = true;
      statusMensagem.value = 'Carregando categorias...';

      categorias.value = await _categoriaService.listarCategorias();

      statusMensagem.value = '';
    } catch (e) {
      statusMensagem.value = 'Erro ao carregar categorias';
      Get.snackbar(
        'Erro',
        'Não foi possível carregar as categorias: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> criarCategoria({
    required String nome,
    String? descricao,
  }) async {
    try {
      isLoading.value = true;

      await _categoriaService.criarCategoria(
        nome: nome,
        descricao: descricao,
      );

      Get.snackbar(
        'Sucesso',
        'Categoria criada com sucesso',
        backgroundColor: const Color(0xFF00FF88),
        colorText: Colors.black,
      );

      await carregarCategorias();
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Não foi possível criar a categoria: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> atualizarCategoria({
    required int id,
    String? nome,
    String? descricao,
    bool? ativo,
  }) async {
    try {
      isLoading.value = true;

      await _categoriaService.atualizarCategoria(
        id: id,
        nome: nome,
        descricao: descricao,
        ativo: ativo,
      );

      Get.snackbar(
        'Sucesso',
        'Categoria atualizada com sucesso',
        backgroundColor: const Color(0xFF00FF88),
        colorText: Colors.black,
      );

      await carregarCategorias();
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Não foi possível atualizar a categoria: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deletarCategoria(int id, String nome) async {
    try {
      final confirmacao = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Confirmar exclusão'),
          content: Text(
            'Tem certeza que deseja deletar a categoria "$nome"?\n\n'
            'Esta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Deletar'),
            ),
          ],
        ),
      );

      if (confirmacao != true) return;

      isLoading.value = true;

      await _categoriaService.deletarCategoria(id);

      Get.snackbar(
        'Sucesso',
        'Categoria deletada com sucesso',
        backgroundColor: const Color(0xFF00FF88),
        colorText: Colors.black,
      );

      await carregarCategorias();
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Não foi possível deletar a categoria: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}