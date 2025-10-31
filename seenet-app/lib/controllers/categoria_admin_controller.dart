import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'checkmark_controller.dart';
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

    // Construir body com apenas os campos que foram alterados
    final Map<String, dynamic> body = {};
    if (nome != null) body['nome'] = nome;
    if (descricao != null) body['descricao'] = descricao;
    if (ativo != null) body['ativo'] = ativo; // ← Enviar como boolean

    print('📤 Atualizando categoria $id com body: $body');

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
    bool? confirmacao = await showDialog<bool>(
      context: Get.context!,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Confirmar exclusão',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Tem certeza que deseja deletar a categoria "$nome"?\n\n'
            'Esta ação não pode ser desfeita.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Deletar'),
            ),
          ],
        );
      },
    );

    if (confirmacao != true) return;

    isLoading.value = true;

    await _categoriaService.deletarCategoria(id);

    // ✅ REMOVER da lista local IMEDIATAMENTE
    categorias.removeWhere((cat) => cat['id'] == id);

    // ✅ ATUALIZAR CheckmarkController se estiver registrado
    if (Get.isRegistered<CheckmarkController>()) {
      final checkmarkController = Get.find<CheckmarkController>();
      // Recarregar categorias no CheckmarkController
      await checkmarkController.carregarCategorias();
    }

    Get.snackbar(
      'Sucesso',
      'Categoria deletada com sucesso',
      backgroundColor: const Color(0xFF00FF88),
      colorText: Colors.black,
    );

    // ✅ Recarregar para garantir sincronização
    await carregarCategorias();
  } catch (e) {
    print('❌ Erro ao deletar categoria: $e');
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