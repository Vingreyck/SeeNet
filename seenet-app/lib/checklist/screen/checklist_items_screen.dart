// lib/checklist/screen/checklist_items_screen.dart — REDESIGN
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

class _ChecklistItemsScreenState extends State<ChecklistItemsScreen>
    with SingleTickerProviderStateMixin {
  final CheckmarkController checkmarkController =
  Get.find<CheckmarkController>();
  final UsuarioController usuarioController =
  Get.find<UsuarioController>();

  late AnimationController _fadeCtrl;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _inicializarDados());
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _inicializarDados() async {
    if (usuarioController.usuarioLogado.value != null) {
      final categoriaNome =
      checkmarkController.nomeCategoriaAtual.isNotEmpty
          ? checkmarkController.nomeCategoriaAtual
          : 'Diagnóstico';
      await checkmarkController.iniciarAvaliacao(
        usuarioController.usuarioLogado.value!.id!,
        'Diagnóstico - $categoriaNome',
      );
    }
  }

  void _enviarDiagnostico() async {
    bool salvou = await checkmarkController.salvarRespostas();
    if (!salvou) {
      AppSnackbar.show(
        'Erro',
        '❌ Erro ao salvar respostas',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await checkmarkController.gerarDiagnosticoComGemini();
    await checkmarkController.finalizarAvaliacao();
    if (mounted) NavHelper.off('/diagnostico');
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2A1A), Color(0xFF111111)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.checklist_rounded,
                      color: Color(0xFF00FF88), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() {
                    final nome =
                    checkmarkController.nomeCategoriaAtual.isNotEmpty
                        ? checkmarkController.nomeCategoriaAtual
                        : 'Diagnóstico';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nome,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const Text('Selecione os problemas identificados',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),

          // ── Contador ────────────────────────────────────────
          Obx(() {
            final total =
                checkmarkController.checkmarksAtivos.length;
            final marcados = checkmarkController.checkmarksMarcados.length;
            if (total == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Text('$total problemas disponíveis',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                  const Spacer(),
                  if (marcados > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF00FF88)
                                .withOpacity(0.3)),
                      ),
                      child: Text('$marcados marcado(s)',
                          style: const TextStyle(
                              color: Color(0xFF00FF88),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    )
                  else
                    const Text('Nenhum selecionado',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 11)),
                ],
              ),
            );
          }),

          // ── Lista ────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (checkmarkController.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00FF88), strokeWidth: 2.5),
                );
              }

              if (checkmarkController.checkmarksAtivos.isEmpty) {
                return _buildEmptyState();
              }

              return FadeTransition(
                opacity: _fadeCtrl,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  itemCount:
                  checkmarkController.checkmarksAtivos.length,
                  itemBuilder: (context, index) {
                    final checkmark =
                    checkmarkController.checkmarksAtivos[index];
                    return Obx(() => CheckmarkItemWidget(
                      title: checkmark.titulo,
                      isChecked:
                      checkmarkController.respostas[checkmark.id] ??
                          false,
                      onChanged: (value) {
                        checkmarkController.toggleCheckmark(
                            checkmark.id!, value ?? false);
                      },
                    ));
                  },
                ),
              );
            }),
          ),

          // ── Botão enviar ────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.06))),
            ),
            child: // SUBSTITUIR o Container do rodapé inteiro:
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  border: Border(top: BorderSide(
                      color: Colors.white.withOpacity(0.06))),
                ),
                child: Obx(() {
                  final marcados = checkmarkController.checkmarksMarcados.length;
                  return GestureDetector(
                    onTap: _enviarDiagnostico,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF88).withOpacity(0.35),
                            blurRadius: 16, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.psychology_rounded,
                              color: Colors.black, size: 20),
                          const SizedBox(width: 10),
                          const Text('Gerar Diagnóstico',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2)),
                          if (marcados > 0) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$marcados',
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add_check_outlined,
                size: 56,
                color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 14),
            const Text('Nenhum checkmark disponível',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Esta categoria ainda não possui checkmarks.\nAcesse o painel administrativo para adicionar.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (usuarioController.isAdmin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Get.toNamed('/admin/checkmarks'),
                icon: const Icon(Icons.add_rounded,
                    color: Colors.black),
                label: const Text('Adicionar Checkmarks',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}