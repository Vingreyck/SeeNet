import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/checkmark_item_widget.dart';
import '../widgets/checkmark_enviar.widget.dart';
import '../../utils/nav_helper.dart';
import '../../controllers/checkmark_controller.dart';
import '../../controllers/usuario_controller.dart';
import 'package:seenet/widgets/app_snackbar.dart';

class ChecklistItemsScreen extends StatefulWidget {
  const ChecklistItemsScreen({super.key});

  @override
  State<ChecklistItemsScreen> createState() => _ChecklistItemsScreenState();
}

class _ChecklistItemsScreenState extends State<ChecklistItemsScreen> {
  final CheckmarkController checkmarkController = Get.find<CheckmarkController>();
  final UsuarioController usuarioController = Get.find<UsuarioController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializarDados());
  }

  void _inicializarDados() async {
    if (usuarioController.usuarioLogado.value != null) {
      final categoriaNome = checkmarkController.nomeCategoriaAtual.isNotEmpty
          ? checkmarkController.nomeCategoriaAtual
          : 'Diagnóstico';
      await checkmarkController.iniciarAvaliacao(
        usuarioController.usuarioLogado.value!.id!,
        'Diagnóstico - $categoriaNome',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          // ── Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00E87C), Color(0xFF00B05B)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(() {
                    final nome = checkmarkController.nomeCategoriaAtual.isNotEmpty
                        ? checkmarkController.nomeCategoriaAtual
                        : 'Diagnóstico';
                    return Text(
                      'Problemas de $nome',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── Lista
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Obx(() {
                    if (checkmarkController.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                      );
                    }
                    if (checkmarkController.checkmarksAtivos.isEmpty) {
                      return _buildEmptyState();
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: checkmarkController.checkmarksAtivos.length,
                      itemBuilder: (context, index) {
                        final checkmark = checkmarkController.checkmarksAtivos[index];
                        return Obx(() => CheckmarkItemWidget(
                          title: checkmark.titulo,
                          isChecked: checkmarkController.respostas[checkmark.id] ?? false,
                          onChanged: (value) {
                            checkmarkController.toggleCheckmark(checkmark.id!, value ?? false);
                          },
                        ));
                      },
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: CheckmarkEnviarWidget(onPressed: _enviarDiagnostico),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_add_check_outlined, size: 80, color: Colors.white24),
            const SizedBox(height: 20),
            const Text(
              'Nenhum checkmark disponível',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta categoria ainda não possui checkmarks cadastrados.\nAcesse o painel administrativo para adicionar.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (usuarioController.isAdmin) ...[
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => Get.toNamed('/admin/checkmarks'),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  'Adicionar Checkmarks',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _enviarDiagnostico() async {
    bool salvou = await checkmarkController.salvarRespostas();
    if (!salvou) {
      // ✅ Snackbar aqui é seguro: só dispara em caso de erro e retorna logo depois
      // (não há navegação na sequência, então não conflita com o overlay).
      AppSnackbar.show(
        'Erro',
        '❌ Erro ao salvar respostas',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // ✅ Sem snackbar antes de navegar — evita o crash de animação
    await checkmarkController.gerarDiagnosticoComGemini();
    await checkmarkController.finalizarAvaliacao();

    if (mounted) NavHelper.off('/diagnostico');
  }
}