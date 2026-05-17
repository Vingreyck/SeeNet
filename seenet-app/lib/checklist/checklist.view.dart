// lib/checklist/checklist.view.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seenet/checklist/widgets/checklist_categoria_card.widget.dart';
import 'package:get/get.dart';
import '../controllers/usuario_controller.dart';
import 'package:seenet/services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controllers/nav_controller.dart';
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

class _ChecklistviewState extends State<Checklistview>
    with TickerProviderStateMixin {
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final CheckmarkController checkmarkController = Get.find<CheckmarkController>();
  final AuthService authService = Get.find<AuthService>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
    Get.find<NavController>().scaffoldKey = _scaffoldKey;

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
            CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerCtrl.forward();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
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

  // ── DRAWER REDESENHADO ────────────────────────────────────────

  Widget _buildDrawer() {
    final usuario = usuarioController.usuarioLogado.value;
    final iniciais = usuario != null && usuario.nome.isNotEmpty
        ? usuario.nome.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : 'U';

    final tipo = usuarioController.tipoUsuario;
    final corTipo = usuarioController.isAdmin
        ? const Color(0xFFFF9800)
        : usuarioController.isGestorSeguranca
        ? const Color(0xFF2196F3)
        : const Color(0xFF00FF88);
    final labelTipo = usuarioController.isAdmin
        ? 'ADMINISTRADOR'
        : usuarioController.isGestorSeguranca
        ? 'GESTOR SEG.'
        : 'TÉCNICO';

    return Drawer(
      backgroundColor: const Color(0xFF111111),
      width: 285,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20, right: 20, bottom: 24,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                bottom: BorderSide(
                    color: corTipo.withOpacity(0.2), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [corTipo.withOpacity(0.3), corTipo.withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: corTipo.withOpacity(0.5), width: 2),
                      ),
                      child: Center(
                        child: Text(iniciais,
                            style: TextStyle(
                                color: corTipo,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const Spacer(),
                    // Badge online
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF00FF88).withOpacity(0.5),
                              blurRadius: 6, spreadRadius: 1)
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(usuarioController.nomeUsuario,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: corTipo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: corTipo.withOpacity(0.3)),
                  ),
                  child: Text(labelTipo,
                      style: TextStyle(
                          color: corTipo, fontSize: 10,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),

          // ── Itens ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildDrawerItem(
                      icon: Icons.home_outlined,
                      label: 'Início',
                      onTap: () {
                        Navigator.pop(context);
                        Get.find<NavController>().selectedIndex.value = 1;
                      },
                      active: Get.find<NavController>().selectedIndex.value == 1,
                    ),
                    _buildDrawerItem(
                      icon: Icons.assignment_outlined,
                      label: 'Ordens de Serviço',
                      onTap: () { Navigator.pop(context); Get.toNamed('/ordens-servico'); },
                    ),
                    if (kIsWeb)
                      _buildDrawerItem(
                        icon: Icons.camera_alt_outlined,
                        label: 'Diagnóstico por Foto',
                        onTap: () { Navigator.pop(context); _diagnosticarPorFoto(); },
                      ),
                    _buildDrawerItem(
                      icon: Icons.health_and_safety_outlined,
                      label: 'Solicitação de EPI/EPC',
                      onTap: () {
                        Navigator.pop(context);
                        Get.find<NavController>().selectedIndex.value = 2;
                        Get.toNamed('/seguranca');
                      },
                      active: Get.find<NavController>().selectedIndex.value == 2,
                    ),

                    if (usuarioController.isAdmin || usuarioController.isGestorSeguranca) ...[
                      _buildSectionHeader('Gestão'),
                      _buildDrawerItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Gestão de Requisições',
                        onTap: () { Navigator.pop(context); Get.toNamed('/seguranca/gestao'); },
                      ),
                      _buildDrawerItem(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'Relatório de EPI',
                        onTap: () { Navigator.pop(context); Get.toNamed('/seguranca/relatorio-epi'); },
                      ),
                    ],

                    if (usuarioController.isAdmin) ...[
                      _buildSectionHeader('Administração'),
                      _buildDrawerItem(
                        icon: Icons.people_outline,
                        label: 'Usuários',
                        onTap: () { Navigator.pop(context); Get.toNamed('/admin/usuarios'); },
                      ),
                      _buildDrawerItem(
                        icon: Icons.checklist_outlined,
                        label: 'Checkmarks',
                        onTap: () { Navigator.pop(context); Get.toNamed('/admin/checkmarks'); },
                      ),
                      _buildDrawerItem(
                        icon: Icons.category_outlined,
                        label: 'Categorias',
                        onTap: () { Navigator.pop(context); Get.toNamed('/admin/categorias'); },
                      ),
                      _buildDrawerItem(
                        icon: Icons.gps_fixed,
                        label: 'Acompanhar Técnicos',
                        onTap: () { Navigator.pop(context); Get.toNamed('/acompanhamento'); },
                      ),
                      _buildDrawerItem(
                        icon: Icons.bar_chart,
                        label: 'Dashboard',
                        onTap: () { Navigator.pop(context); Get.toNamed('/admin/dashboard'); },
                      ),
                      _buildDrawerItem(
                        icon: Icons.security_outlined,
                        label: 'Logs de Auditoria',
                        onTap: () { Navigator.pop(context); Get.toNamed('/admin/logs'); },
                      ),
                    ],

                    const SizedBox(height: 8),
                    Divider(color: Colors.white.withOpacity(0.07), height: 1),
                    const SizedBox(height: 8),

                    _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      label: 'Sair',
                      onTap: () { Navigator.pop(context); authService.logout(); },
                      danger: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // ── Rodapé ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset('assets/images/logo.svg', width: 16, height: 16),
                const SizedBox(width: 6),
                Text('SeeNet v1.0',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    bool danger = false,
  }) {
    final color = danger
        ? Colors.red
        : active
        ? const Color(0xFF00FF88)
        : Colors.white60;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF00FF88).withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: active
                    ? const Color(0xFF00FF88)
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight:
                      active ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 20, 4),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Expanded(
              child: Container(
                  height: 0.5,
                  color: Colors.white.withOpacity(0.08))),
        ],
      ),
    );
  }

  // ── BUILD PRINCIPAL ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final corTipo = usuarioController.isAdmin
        ? const Color(0xFFFF9800)
        : usuarioController.isGestorSeguranca
        ? const Color(0xFF2196F3)
        : const Color(0xFF00FF88);

    final corFundo = usuarioController.isAdmin
        ? const Color(0xFF2A1A08)
        : usuarioController.isGestorSeguranca
        ? const Color(0xFF0A1A2A)
        : const Color(0xFF1A2A1A);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF111111),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── SliverAppBar ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF111111),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradiente de fundo
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [corFundo, const Color(0xFF111111)],
                      ),
                    ),
                  ),
                  // Grade decorativa
                  Positioned(
                    top: 0, right: 0,
                    child: _GradeDecorativa(cor: corTipo),                  ),
                  // Conteúdo
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: SlideTransition(
                          position: _headerSlide,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SvgPicture.asset('assets/images/logo.svg', width: 60, height: 60),
                              const SizedBox(width: 5),
                              const Text('SeeNet',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,                    // ← maior
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5)),
                              const Spacer(),
                              _buildUserAvatar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Título da seção ────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(
                            colors: [Color(0xFF00FF88), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.centerRight,
                          ).createShader(bounds),
                      child: const Text('Checklist Técnico',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5)),
                    ),
                    const SizedBox(height: 4),
                    const Text('Selecione a categoria para diagnóstico',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          // ── Lista de categorias ────────────────────────────
          Obx(() {
            if (checkmarkController.isLoading.value) {
              return const SliverToBoxAdapter(
                child: CategoriasSkeleton(itemCount: 4),
              );
            }
            if (checkmarkController.categorias.isEmpty) {
              return SliverToBoxAdapter(
                child: _buildEmptyStateNoCategorias(),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final categoria =
                  checkmarkController.categorias[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                        milliseconds: 300 + index * 60),
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
                childCount: checkmarkController.categorias.length,
              ),
            );
          }),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    final usuario = usuarioController.usuarioLogado.value;
    final iniciais = usuario != null && usuario.nome.isNotEmpty
        ? usuario.nome.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : 'U';
    final cor = usuarioController.isAdmin
        ? const Color(0xFFFF9800)
        : usuarioController.isGestorSeguranca
        ? const Color(0xFF2196F3)
        : const Color(0xFF00FF88);

    return GestureDetector(
      onTap: () => Get.toNamed('/seguranca/perfil'),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [cor.withOpacity(0.3), cor.withOpacity(0.1)],
          ),
          border: Border.all(color: cor.withOpacity(0.5), width: 1.5),
        ),
        child: Center(
          child: Text(iniciais,
              style: TextStyle(
                  color: cor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ),
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

// ── Grade decorativa ────────────────────────────────────────────
class _GradeDecorativa extends StatelessWidget {
  final Color cor;                          // ← adicionar
  const _GradeDecorativa({required this.cor}); // ← adicionar
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    height: 100,
    child: CustomPaint(painter: _GradePainter(cor: cor)),
  );
}

class _GradePainter extends CustomPainter {
  final Color cor;                          // ← adicionar
  const _GradePainter({required this.cor}); // ← adicionar
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = cor.withOpacity(0.06)       // ← era hardcoded verde
      ..strokeWidth = 1;
    const s = 18.0;
    for (double x = 0; x < size.width; x += s)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p1);
    for (double y = 0; y < size.height; y += s)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p1);
    final p2 = Paint()
      ..color = cor.withOpacity(0.15)       // ← era hardcoded verde
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += s)
      for (double y = 0; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.5, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}