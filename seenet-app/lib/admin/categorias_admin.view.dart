import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/categoria_admin_controller.dart';

class CategoriasAdminView extends StatelessWidget {
  const CategoriasAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CategoriaAdminController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Categorias'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Obx(() {
        if (controller.isLoading.value && controller.categorias.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00FF88),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.carregarCategorias,
          color: const Color(0xFF00FF88),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(controller),
              const SizedBox(height: 20),
              ...controller.categorias.map((cat) => _buildCategoriaCard(cat, controller)),
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogNovaCategoria(context, controller),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria'),
      ),
    );
  }

  Widget _buildHeader(CategoriaAdminController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categorias de Checklist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${controller.categorias.length} categorias',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaCard(
    Map<String, dynamic> categoria,
    CategoriaAdminController controller,
  ) {
    final isAtivo = categoria['ativo'] == true || categoria['ativo'] == 1;
    final totalCheckmarks = categoria['total_checkmarks'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAtivo
              ? const Color(0xFF00FF88).withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          categoria['nome'] ?? '',
                          style: TextStyle(
                            color: isAtivo ? Colors.white : Colors.white54,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isAtivo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'INATIVO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (categoria['descricao'] != null &&
                        categoria['descricao'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          categoria['descricao'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalCheckmarks checkmarks',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF2A2A2A),
                onSelected: (value) {
                  switch (value) {
                    case 'editar':
                      _mostrarDialogEditarCategoria(
                        Get.context!,
                        controller,
                        categoria,
                      );
                      break;
                    case 'toggle':
                      controller.atualizarCategoria(
                        id: categoria['id'],
                        ativo: !isAtivo,
                      );
                      break;
                    case 'deletar':
                      controller.deletarCategoria(
                        categoria['id'],
                        categoria['nome'],
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Editar', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isAtivo ? Icons.visibility_off : Icons.visibility,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAtivo ? 'Desativar' : 'Ativar',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'deletar',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Deletar', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ ADICIONAR controller COMO PARÂMETRO
  void _mostrarDialogNovaCategoria(
    BuildContext context,
    CategoriaAdminController controller, // ← ADICIONADO
  ) {
    final nomeController = TextEditingController();
    final descricaoController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Nova Categoria',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nome da Categoria',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF88)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descricaoController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF88)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                final descricao = descricaoController.text.trim();

                if (nome.isEmpty) {
                  Get.snackbar(
                    'Erro',
                    'Nome da categoria é obrigatório',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                  return;
                }

                // ✅ FECHAR DIALOG ANTES
                Navigator.of(dialogContext).pop();

                // ✅ AGORA controller EXISTE
                await controller.criarCategoria(
                  nome: nome,
                  descricao: descricao.isEmpty ? null : descricao,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  // ✅ CORRIGIR TAMBÉM O DIALOG DE EDITAR
  void _mostrarDialogEditarCategoria(
    BuildContext context,
    CategoriaAdminController controller,
    Map<String, dynamic> categoria,
  ) {
    final nomeController = TextEditingController(text: categoria['nome']);
    final descricaoController =
        TextEditingController(text: categoria['descricao'] ?? '');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Editar Categoria',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nome da Categoria',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF88)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descricaoController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF88)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), // ✅ CORRIGIDO
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nomeController.text.trim().isEmpty) {
                  Get.snackbar(
                    'Erro',
                    'Nome da categoria é obrigatório',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(); // ✅ CORRIGIDO
                
                controller.atualizarCategoria(
                  id: categoria['id'],
                  nome: nomeController.text.trim(),
                  descricao: descricaoController.text.trim().isEmpty
                      ? null
                      : descricaoController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }
}