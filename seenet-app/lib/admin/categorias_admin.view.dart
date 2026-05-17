// lib/admin/categorias_admin.view.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/categoria_admin_controller.dart';
import 'package:seenet/widgets/app_snackbar.dart';

class CategoriasAdminView extends StatelessWidget {
  const CategoriasAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CategoriaAdminController());

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16,
              left: 8,
              right: 16,
            ),
            color: const Color(0xFF111111),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.category_outlined,
                      color: Color(0xFF00FF88), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Categorias',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700)),
                      Text(
                        '${controller.categorias.length} categoria(s)',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  )),
                ),
              ],
            ),
          ),

          // ── Lista ────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.categorias.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00FF88), strokeWidth: 2.5),
                );
              }

              return RefreshIndicator(
                onRefresh: controller.carregarCategorias,
                color: const Color(0xFF00FF88),
                child: controller.categorias.isEmpty
                    ? _buildVazio(context, controller)
                    : ListView.builder(
                  padding:
                  const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: controller.categorias.length,
                  itemBuilder: (context, index) {
                    final cat = controller.categorias[index];
                    return _buildCategoriaCard(
                        context, cat, controller, index);
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _mostrarDialogNovaCategoria(context, controller),
        backgroundColor: const Color(0xFF00FF88),
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('Nova Categoria',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Cards ────────────────────────────────────────────────────

  Widget _buildCategoriaCard(
      BuildContext context,
      Map<String, dynamic> categoria,
      CategoriaAdminController controller,
      int index,
      ) {
    final isAtivo = categoria['ativo'] == true || categoria['ativo'] == 1;
    final totalCheckmarks = categoria['total_checkmarks'] ?? 0;
    final cores = [
      const Color(0xFF00FF88), const Color(0xFF00BFFF),
      Colors.orange, Colors.purple, Colors.pink, Colors.teal,
    ];
    final cor = cores[index % cores.length];
    final nome = categoria['nome'] as String? ?? '';
    final inicial = nome.isNotEmpty ? nome.substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAtivo ? cor.withOpacity(0.2) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: isAtivo ? cor.withOpacity(0.06) : Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAtivo ? cor.withOpacity(0.12) : Colors.white.withOpacity(0.05),
                    border: Border.all(
                        color: isAtivo ? cor.withOpacity(0.3) : Colors.white12),
                  ),
                  child: Center(
                    child: Text(inicial,
                        style: TextStyle(
                            color: isAtivo ? cor : Colors.white24,
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(                              // ← Expanded no nome
                            child: Text(nome,
                                style: TextStyle(
                                    color: isAtivo ? Colors.white : Colors.white38,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!isAtivo) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('INATIVO',
                                  style: TextStyle(color: Colors.grey,
                                      fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      if (categoria['descricao'] != null &&
                          categoria['descricao'].toString().isNotEmpty)
                        Text(categoria['descricao'],
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAtivo ? cor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$totalCheckmarks',
                      style: TextStyle(
                          color: isAtivo ? cor : Colors.white24,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Botões
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconBtn(Icons.edit_rounded, 'Editar', Colors.blue,
                        () => _mostrarDialogEditarCategoria(context, controller, categoria)),
                const SizedBox(width: 8),
                _iconBtn(
                  isAtivo ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  isAtivo ? 'Desativar' : 'Ativar',
                  Colors.orange,
                      () => controller.atualizarCategoria(
                      id: categoria['id'], ativo: !isAtivo),
                ),
                const SizedBox(width: 8),
                _iconBtn(Icons.delete_outline_rounded, 'Deletar', Colors.red,
                        () => controller.deletarCategoria(
                        categoria['id'], categoria['nome'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, Color cor, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: cor.withOpacity(0.3)),
          ),
          child: Icon(icon, color: cor, size: 17),
        ),
      ),
    );
  }

  Widget _botaoAcao(
      IconData icon, String label, Color cor, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13, color: cor),
        label: Text(label,
            style: TextStyle(color: cor, fontSize: 10)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cor.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }

  Widget _buildVazio(
      BuildContext context, CategoriaAdminController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined,
              size: 52, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 12),
          const Text('Nenhuma categoria cadastrada',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () =>
                _mostrarDialogNovaCategoria(context, controller),
            icon: const Icon(Icons.add_rounded, color: Colors.black),
            label: const Text('Criar Categoria',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs (lógica inalterada, visual atualizado) ────────────

  void _mostrarDialogNovaCategoria(
      BuildContext context,
      CategoriaAdminController controller,
      ) {
    final nomeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Nova Categoria',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _campo(nomeCtrl, 'Nome da Categoria *'),
              const SizedBox(height: 10),
              _campo(descCtrl, 'Descrição (opcional)', maxLines: 3),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final nome = nomeCtrl.text.trim();
                    final desc = descCtrl.text.trim();
                    if (nome.isEmpty) {
                      AppSnackbar.show(
                          'Erro', 'Nome é obrigatório',
                          backgroundColor: Colors.red,
                          colorText: Colors.white);
                      return;
                    }
                    Navigator.pop(context);
                    await controller.criarCategoria(
                        nome: nome,
                        descricao: desc.isEmpty ? null : desc);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Criar Categoria',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogEditarCategoria(
      BuildContext context,
      CategoriaAdminController controller,
      Map<String, dynamic> categoria,
      ) {
    final nomeCtrl =
    TextEditingController(text: categoria['nome']);
    final descCtrl =
    TextEditingController(text: categoria['descricao'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Editar Categoria',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _campo(nomeCtrl, 'Nome da Categoria *'),
              const SizedBox(height: 10),
              _campo(descCtrl, 'Descrição', maxLines: 3),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nomeCtrl.text.trim().isEmpty) {
                      AppSnackbar.show(
                          'Erro', 'Nome é obrigatório',
                          backgroundColor: Colors.red,
                          colorText: Colors.white);
                      return;
                    }
                    Navigator.pop(context);
                    controller.atualizarCategoria(
                      id: categoria['id'],
                      nome: nomeCtrl.text.trim(),
                      descricao:
                      descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Salvar',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF00FF88), width: 1.5)),
      ),
    );
  }
}