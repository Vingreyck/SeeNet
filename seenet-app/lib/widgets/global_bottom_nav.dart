import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/nav_controller.dart';
import '../services/auth_service.dart';
import '../controllers/usuario_controller.dart';

class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({super.key});

  NavigatorState? get _rootNavigator => Get.key.currentState;

  // ── LÓGICA INALTERADA ──────────────────────────────────────────

  void _abrirMenuGlobal() {
    if (kDebugMode) debugPrint('🍔 [Menu] Botao Menu clicado');

    UsuarioController? usuario;
    NavController? nav;

    try {
      usuario = Get.find<UsuarioController>();
      nav = Get.find<NavController>();
    } catch (e) {
      if (kDebugMode) debugPrint('🍔 [Menu] ERRO ao buscar controllers: $e');
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '🍔 [Menu] OK. isAdmin=${usuario.isAdmin}, isGestorSeg=${usuario.isGestorSeguranca}',
      );
    }

    final navigator = _rootNavigator;
    if (navigator == null) {
      if (kDebugMode) debugPrint('🍔 [Menu] Navigator global NULL');
      return;
    }

    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.75),
        barrierLabel: 'Fechar menu',
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _buildDrawerContent(dialogContext, usuario!, nav!);
        },
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  void _fecharMenu(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _fecharMenuENavegar(BuildContext dialogContext, VoidCallback acao) {
    _fecharMenu(dialogContext);
    WidgetsBinding.instance.addPostFrameCallback((_) => acao());
  }

  // ── DRAWER REDESENHADO (visual only) ──────────────────────────

  Widget _buildDrawerContent(
      BuildContext dialogContext,
      UsuarioController usuario,
      NavController nav,
      ) {
    // Dados do usuário para o header
    final nome = usuario.nomeUsuario;
    final iniciais = nome.isNotEmpty
        ? nome.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : 'U';
    final corTipo = usuario.isAdmin
        ? const Color(0xFFFF9800)
        : usuario.isGestorSeguranca
        ? const Color(0xFF2196F3)
        : const Color(0xFF00FF88);
    final labelTipo = usuario.isAdmin
        ? 'ADMINISTRADOR'
        : usuario.isGestorSeguranca
        ? 'GESTOR SEG.'
        : 'TÉCNICO';

    return Stack(
      children: [
        // Fundo clicável para fechar
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _fecharMenu(dialogContext),
            child: const SizedBox.expand(),
          ),
        ),

        // Drawer lateral
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 285,
              height: double.infinity,
              color: const Color(0xFF111111),
              child: SafeArea(
                child: Column(
                  children: [
                    // ── Header com avatar e nome ─────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                              // Avatar com iniciais
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      corTipo.withOpacity(0.3),
                                      corTipo.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                      color: corTipo.withOpacity(0.5),
                                      width: 2),
                                ),
                                child: Center(
                                  child: Text(iniciais,
                                      style: TextStyle(
                                          color: corTipo,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                              const Spacer(),
                              // Indicador online
                              Container(
                                width: 9, height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF88),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFF00FF88)
                                            .withOpacity(0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1)
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(nome,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: corTipo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: corTipo.withOpacity(0.3)),
                            ),
                            child: Text(labelTipo,
                                style: TextStyle(
                                    color: corTipo,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),

                    // ── Itens de navegação ───────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            _menuItem(
                              Icons.home_outlined,
                              'Início',
                                  () => _fecharMenuENavegar(dialogContext, () {
                                nav.selecionarTabSafe(1);
                                Get.toNamed('/ordens-servico');
                              }),
                            ),
                            _menuItem(
                              Icons.troubleshoot,
                              'Diagnóstico',
                                  () => _fecharMenuENavegar(dialogContext,
                                      () => Get.toNamed('/checklist')),
                            ),
                            _menuItem(
                              Icons.health_and_safety_outlined,
                              'Solicitação de EPI/EPC',
                                  () => _fecharMenuENavegar(dialogContext,
                                      () => Get.toNamed('/seguranca')),
                            ),

                            if (usuario.isAdmin || usuario.isGestorSeguranca) ...[
                              _divider('Gestão'),
                              _menuItem(
                                Icons.health_and_safety_outlined,
                                'DDS',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/dds/gestor')),
                              ),
                              _menuItem(
                                Icons.history_edu,
                                'Histórico de DDS',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/dds/historico')),
                              ),
                              _menuItem(
                                Icons.inventory_2_outlined,
                                'Gestão de Requisições',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/seguranca/gestao')),
                              ),
                              _menuItem(
                                Icons.picture_as_pdf_outlined,
                                'Relatório de EPI',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/seguranca/relatorio-epi')),
                              ),
                              _menuItem(
                                Icons.people_outline,
                                'Usuários (Gestão)',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/usuarios-gestao')),
                              ),
                            ],

                            if (usuario.isAdmin) ...[
                              _divider('Administração'),
                              _menuItem(
                                Icons.people_outline,
                                'Usuários',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/admin/usuarios')),
                              ),
                              _menuItem(
                                Icons.checklist_outlined,
                                'Checkmarks',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/admin/checkmarks')),
                              ),
                              _menuItem(
                                Icons.category_outlined,
                                'Categorias',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/admin/categorias')),
                              ),
                              _menuItem(
                                Icons.gps_fixed,
                                'Acompanhar Técnicos',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/acompanhamento')),
                              ),
                              _menuItem(
                                Icons.bar_chart,
                                'Dashboard',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/admin/dashboard')),
                              ),
                              _menuItem(
                                Icons.security_outlined,
                                'Logs de Auditoria',
                                    () => _fecharMenuENavegar(dialogContext,
                                        () => Get.toNamed('/admin/logs')),
                              ),
                            ],

                            _divider(''),

                            _menuItem(
                              Icons.logout_rounded,
                              'Sair',
                                  () => _fecharMenuENavegar(dialogContext, () {
                                try {
                                  Get.find<AuthService>().logout();
                                } catch (e) {
                                  if (kDebugMode) {
                                    debugPrint('🍔 [Menu] Erro logout: $e');
                                  }
                                }
                              }),
                              danger: true,
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // ── Rodapé ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('SeeNet v1.0',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.15),
                              fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Item de menu redesenhado ───────────────────────────────────

  Widget _menuItem(
      IconData icon,
      String label,
      VoidCallback onTap, {
        bool danger = false,
      }) {
    final color = danger ? Colors.red : Colors.white60;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Divider de seção redesenhado ───────────────────────────────

  Widget _divider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 20, 4),
      child: Row(
        children: [
          if (label.isNotEmpty) ...[
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
                height: 0.5,
                color: Colors.white.withOpacity(0.08)),
          ),
        ],
      ),
    );
  }

  // ── BUILD (inalterado) ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavController>();

    return ValueListenableBuilder<bool>(
      valueListenable: nav.mostrarNavNotifier,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();

        return Container(
          height: 60 + MediaQuery.of(context).padding.bottom,
          decoration: const BoxDecoration(
            color: Color(0xFF232323),
            border: Border(
              top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: _navButton(
                    icon: Icons.menu_rounded,
                    label: 'Menu',
                    iconColor: Colors.white,
                    labelColor: Colors.white,
                    isSelected: false,
                    onTap: _abrirMenuGlobal,
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final selected = nav.selectedIndex.value == 1;
                    return _navButton(
                      icon: Icons.home_rounded,
                      label: 'Início',
                      iconColor: selected ? const Color(0xFF00FF88) : const Color(0xFF888888),
                      labelColor: selected ? const Color(0xFF00FF88) : const Color(0xFF888888),
                      isSelected: selected,
                      onTap: () {
                        Get.toNamed('/ordens-servico');
                        nav.selecionarTabSafe(1);
                      },
                    );
                  }),
                ),
                Expanded(
                  child: Obx(() {
                    final selected = nav.selectedIndex.value == 2;
                    return _navButton(
                      icon: Icons.health_and_safety_rounded,
                      label: 'EPI',
                      iconColor: selected ? const Color(0xFF00FF88) : const Color(0xFF888888),
                      labelColor: selected ? const Color(0xFF00FF88) : const Color(0xFF888888),
                      isSelected: selected,
                      onTap: () {
                        Get.toNamed('/seguranca');
                        nav.selecionarTabSafe(2);
                      },
                    );
                  }),
                ),
                Expanded(
                  child: Obx(() {
                    final selected = nav.selectedIndex.value == 3;
                    return _navButton(
                      icon: Icons.person_rounded,
                      label: 'Perfil',
                      iconColor: selected ? const Color(0xFF00FF88) : const Color(0xFF888888),
                      labelColor: selected ? const Color(0xFF00FF88) : const Color(0xFF888888),
                      isSelected: selected,
                      onTap: () {
                        Get.toNamed('/seguranca/perfil');
                        nav.selecionarTabSafe(3);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color labelColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00FF88).withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: labelColor)),
        ],
      ),
    );
  }
}