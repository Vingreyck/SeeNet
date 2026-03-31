// lib/checklist/checklist.view.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seenet/checklist/widgets/checklist_categoria_card.widget.dart';
import 'package:get/get.dart';
import '../controllers/usuario_controller.dart';
import 'package:seenet/services/auth_service.dart';
import '../controllers/checkmark_controller.dart';
import '../widgets/skeleton_loader.dart';

class Checklistview extends StatefulWidget {
  const Checklistview({super.key});

  @override
  State<Checklistview> createState() => _ChecklistviewState();
}

class _ChecklistviewState extends State<Checklistview>
    with SingleTickerProviderStateMixin {
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final CheckmarkController checkmarkController = Get.find<CheckmarkController>();
  final AuthService authService = Get.find<AuthService>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _navIndex = 0; // 0=Início, 1=EPI, 2=Perfil

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    await checkmarkController.carregarCategorias();
  }

  // ──────────────────────────────────────────────
  // DRAWER (esquerda → direita)
  // ──────────────────────────────────────────────

  Widget _buildDrawer() {
    final usuario = usuarioController.usuarioLogado.value;
    final iniciais = usuario != null && usuario.nome.isNotEmpty
        ? usuario.nome.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : 'U';

    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      width: 280,
      child: Column(
        children: [
          // ── Header verde
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00E87C), Color(0xFF00B05B)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      iniciais,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  usuarioController.nomeUsuario,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    usuarioController.isAdmin
                        ? 'Administrador'
                        : usuarioController.isGestorSeguranca
                        ? 'Gestor de Segurança'
                        : 'Técnico de Campo',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // ── Itens do menu
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Todos os usuários
                  _buildDrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Início',
                    onTap: () { Navigator.pop(context); setState(() => _navIndex = 0); },
                    active: _navIndex == 0,
                  ),
                  _buildDrawerItem(
                    icon: Icons.assignment_outlined,
                    label: 'Ordens de Serviço',
                    onTap: () { Navigator.pop(context); Get.toNamed('/ordens-servico'); },
                  ),
                  _buildDrawerItem(
                    icon: Icons.health_and_safety_outlined,
                    label: 'Segurança / EPI',
                    onTap: () { Navigator.pop(context); setState(() => _navIndex = 1); Get.toNamed('/seguranca'); },
                    active: _navIndex == 1,
                  ),

                  // Gestor de segurança
                  if (usuarioController.isAdmin || usuarioController.isGestorSeguranca) ...[
                    _buildDivider('Gestão'),
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

                  // Admin
                  if (usuarioController.isAdmin) ...[
                    _buildDivider('Administração'),
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
                    _buildDrawerItem(                          // ✅ NOVO — adiciona aqui
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

                  _buildDivider(''),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    label: 'Sair',
                    onTap: () { Navigator.pop(context); authService.logout(); },
                    danger: true,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Versão
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'SeeNet v1.0',
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
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
        : Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00FF88).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: active ? const Color(0xFF00FF88) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          if (label.isNotEmpty) ...[
            Text(label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                )),
            const SizedBox(width: 8),
          ],
          Expanded(child: Container(height: 0.5, color: Colors.white.withOpacity(0.1))),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // BOTTOM NAV ANIMADO
  // ──────────────────────────────────────────────

  Widget _buildBottomNav() {
    // ✅ 4 itens: Menu, Início, EPI, Perfil
    final labels = ['Menu', 'Início', 'EPI', 'Perfil'];
    final icons = [
      Icons.menu_rounded,
      Icons.home_rounded,
      Icons.health_and_safety_rounded,
      Icons.person_rounded,
    ];

    return Container(
      height: 60 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Color(0xFF232323),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          children: List.generate(4, (i) {
            // Menu (i=0) não tem estado "selecionado" — é sempre neutro
            final selected = i != 0 && _navIndex == i;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i == 0) {
                    // ✅ Abre o drawer
                    _scaffoldKey.currentState?.openDrawer();
                    return;
                  }
                  setState(() => _navIndex = i);
                  if (i == 2) Get.toNamed('/seguranca');
                  if (i == 3) Get.toNamed('/seguranca/perfil');
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF00FF88).withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icons[i],
                        color: i == 0
                            ? const Color(0xFF888888) // Menu sempre neutro
                            : selected
                            ? const Color(0xFF00FF88)
                            : const Color(0xFF555555),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: i == 0
                            ? const Color(0xFF888888)
                            : selected
                            ? const Color(0xFF00FF88)
                            : const Color(0xFF555555),
                      ),
                      child: Text(labels[i]),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1A1A1A),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // ── Header verde
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 100,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 15,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.32, 1.0],
                  colors: [Color(0xFF00E87C), Color(0xFF00B05B)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo + nome
                  Row(
                    children: [
                      SvgPicture.asset('assets/images/logo.svg', width: 48, height: 48),
                      const SizedBox(width: 3),
                      const Text(
                        'SeeNet',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: usuarioController.isAdmin
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: usuarioController.isAdmin
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                      child: Icon(
                        usuarioController.isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.person_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Título
          Positioned(
            top: MediaQuery.of(context).padding.top + 110,
            left: 24,
            right: 24,
            child: ShaderMask(
              shaderCallback: (Rect bounds) => const LinearGradient(
                colors: [Color(0xFF00FF88), Color(0xFFFFFFFF)],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: const Text(
                'Checklist Técnico',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // ── Subtítulo
          Positioned(
            top: MediaQuery.of(context).padding.top + 150,
            left: 24,
            right: 24,
            child: const Text(
              'Selecione a categoria para diagnóstico',
              style: TextStyle(color: Color(0xFF888888), fontSize: 16),
            ),
          ),

          // ── Lista de categorias
          Positioned(
            top: MediaQuery.of(context).padding.top + 195,
            left: 0,
            right: 0,
            bottom: 60 + MediaQuery.of(context).padding.bottom,
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
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      ...checkmarkController.categorias.map((categoria) {
                        return ChecklistCategoriaCardWidget(
                          title: categoria.nome,
                          description: categoria.descricao ?? 'Categoria de diagnóstico',
                          assetIcon: _getIconeParaCategoria(categoria.nome),
                          onTap: () async {
                            if (categoria.id != null) {
                              checkmarkController.categoriaAtual.value = categoria.id!;
                              await checkmarkController.carregarCheckmarks(categoria.id!);
                              final nome = categoria.nome.toLowerCase();
                              if (nome.contains('lentidão') || nome.contains('lentidao')) {
                                Get.toNamed('/checklist/lentidao');
                              } else if (nome.contains('iptv') || nome.contains('tv')) {
                                Get.toNamed('/checklist/iptv');
                              } else if (nome.contains('app') || nome.contains('aplicativo')) {
                                Get.toNamed('/checklist/apps');
                              } else {
                                Get.toNamed('/checklist/lentidao');
                              }
                            }
                          },
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            }),
          ),

          // ── Bottom nav no rodapé
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  String _getIconeParaCategoria(String nomeCategoria) {
    final nome = nomeCategoria.toLowerCase();
    if (nome.contains('lentidão') || nome.contains('lentidao')) return 'assets/images/snail.svg';
    if (nome.contains('iptv') || nome.contains('tv')) return 'assets/images/iptv.svg';
    if (nome.contains('app') || nome.contains('aplicativo')) return 'assets/images/app.svg';
    return 'assets/images/logo.svg';
  }

  Widget _buildEmptyStateNoCategorias() {
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
            const Icon(Icons.category_outlined, size: 80, color: Colors.white24),
            const SizedBox(height: 20),
            const Text('Nenhuma categoria criada',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Esta empresa ainda não possui categorias.\nAcesse o painel administrativo para criar.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (usuarioController.isAdmin) ...[
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => Get.toNamed('/admin/categorias'),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('Criar Categoria',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}