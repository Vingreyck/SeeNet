// lib/checklist/checklist.view.dart — REDESIGN (tela secundária, padrão OS)
import 'package:flutter/material.dart';
import 'package:seenet/checklist/widgets/checklist_categoria_card.widget.dart';
import 'package:get/get.dart';
import '../controllers/usuario_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controllers/checkmark_controller.dart';
import '../widgets/skeleton_loader.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../services/api_service.dart';
import 'package:seenet/widgets/app_snackbar.dart';

class Checklistview extends StatefulWidget {
  const Checklistview({super.key});

  @override
  State<Checklistview> createState() => _ChecklistviewState();
}

class _ChecklistviewState extends State<Checklistview> {
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final CheckmarkController checkmarkController = Get.find<CheckmarkController>();

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
  }

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  Future<void> _carregarCategorias() async {
    await checkmarkController.carregarCategorias();
  }

  String _getIconeParaCategoria(String nomeCategoria) {
    final nome = nomeCategoria.toLowerCase();
    if (nome.contains('lentidão') || nome.contains('lentidao')) return 'assets/images/snail.svg';
    if (nome.contains('iptv') || nome.contains('tv')) return 'assets/images/iptv.svg';
    if (nome.contains('app') || nome.contains('aplicativo')) return 'assets/images/app.svg';
    return 'assets/images/logo.svg';
  }

  Future<void> _diagnosticarPorFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (foto == null) return;
    Get.dialog(
      const Center(
        child: Card(
          color: Color(0xFF1E1E1E),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00FF88)),
                SizedBox(height: 16),
                Text('🤖 Analisando imagem...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    try {
      final bytes = await foto.readAsBytes();
      final base64Img = base64Encode(bytes);
      final api = ApiService.instance;
      final response = await api.post('/diagnostics/foto', {'imagem_base64': base64Img});
      Get.back();
      if (response['success'] == true) {
        Get.toNamed('/diagnostico', arguments: {
          'resposta': response['resposta'],
          'diagnosticoId': response['id'],
          'via_foto': true,
        });
      } else {
        AppSnackbar.show('Erro', 'Não foi possível analisar a imagem',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.back();
      AppSnackbar.show('Erro', 'Falha ao processar imagem',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ── BUILD PRINCIPAL (padrão da tela de OS) ────────────────────

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
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF111111)],
              ),
            ),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 6),
                ],
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diagnóstico',
                          style: TextStyle(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      SizedBox(height: 2),
                      Text('Selecione a categoria para diagnóstico',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: Color(0xFF00FF88), size: 20),
                    tooltip: 'Diagnóstico por Foto',
                    onPressed: _diagnosticarPorFoto,
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white54, size: 20),
                  onPressed: _carregarCategorias,
                ),
              ],
            ),
          ),

          // ── Lista de categorias ─────────────────────────────
          Expanded(
            child: Obx(() {
              if (checkmarkController.isLoading.value) {
                return const CategoriasSkeleton(itemCount: 4);
              }
              if (checkmarkController.categorias.isEmpty) {
                return _buildEmptyStateNoCategorias();
              }
              return RefreshIndicator(
                onRefresh: _carregarCategorias,
                color: const Color(0xFF00FF88),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: checkmarkController.categorias.length,
                  itemBuilder: (context, index) {
                    final categoria = checkmarkController.categorias[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + index * 60),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - v)),
                          child: child,
                        ),
                      ),
                      child: ChecklistCategoriaCardWidget(
                        title: categoria.nome,
                        description: categoria.descricao ??
                            'Categoria de diagnóstico',
                        assetIcon: _getIconeParaCategoria(categoria.nome),
                        onTap: () async {
                          if (categoria.id != null) {
                            checkmarkController.categoriaAtual.value =
                                categoria.id!;
                            await checkmarkController
                                .carregarCheckmarks(categoria.id!);
                            Get.toNamed('/checklist/items');
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateNoCategorias() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 16),
            const Text('Nenhuma categoria criada',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Acesse o painel administrativo\npara criar categorias.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (usuarioController.isAdmin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Get.toNamed('/admin/categorias'),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Criar Categoria',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
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
