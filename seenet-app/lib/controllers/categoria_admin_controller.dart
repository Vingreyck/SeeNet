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

    // ✅ POPUP DE SUCESSO COM AVISO DE REINÍCIO
    await Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 28),
            SizedBox(width: 12),
            Text(
              'Categoria Criada!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A categoria "$nome" foi criada com sucesso!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'IMPORTANTE',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Para ver a nova categoria na tela principal, você precisa fechar e reabrir o aplicativo.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Passos para ver a categoria:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            _buildStep('1', 'Feche completamente o aplicativo'),
            _buildStep('2', 'Abra o aplicativo novamente'),
            _buildStep('3', 'A categoria estará visível na tela principal'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Entendi',
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false, // Força o usuário a clicar em "Entendi"
    );

    // Recarregar CheckmarkController também
    if (Get.isRegistered<CheckmarkController>()) {
      await Get.find<CheckmarkController>().carregarCategorias();
    }

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
    // ✅ HELPER: Widget para os passos
  static Widget _buildStep(String numero, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                texto,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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