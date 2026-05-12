import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/nav_controller.dart';
import '../services/auth_service.dart';
import '../controllers/usuario_controller.dart';

class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({super.key});

  /// ✅ Navigator global correto do GetMaterialApp
  NavigatorState? get _rootNavigator {
    return Get.key.currentState;
  }

  /// Abre o menu lateral usando a navigatorKey global do Get.
  void _abrirMenuGlobal() {
    if (kDebugMode) debugPrint('🍔 [Menu] Botao Menu clicado');

    UsuarioController? usuario;
    NavController? nav;

    try {
      usuario = Get.find<UsuarioController>();
      nav = Get.find<NavController>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🍔 [Menu] ERRO ao buscar controllers: $e');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '🍔 [Menu] OK. isAdmin=${usuario.isAdmin}, isGestorSeg=${usuario.isGestorSeguranca}',
      );
    }

    final navigator = _rootNavigator;

    if (navigator == null) {
      if (kDebugMode) {
        debugPrint('🍔 [Menu] Navigator global NULL');
      }
      return;
    }

    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        barrierLabel: 'Fechar menu',
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _buildDrawerContent(dialogContext, usuario!, nav!);
        },
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildDrawerContent(
      BuildContext dialogContext,
      UsuarioController usuario,
      NavController nav,
      ) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _fecharMenu(dialogContext),
            child: const SizedBox.expand(),
          ),
        ),

        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: const Color(0xFF1A1A1A),
            child: SizedBox(
              width: 280,
              height: double.infinity,
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _menuItem(
                        Icons.home_outlined,
                        'Início',
                            () {
                          _fecharMenuENavegar(dialogContext, () {
                            nav.selecionarTabSafe(1);
                            Get.toNamed('/checklist');
                          });
                        },
                      ),

                      _menuItem(
                        Icons.assignment_outlined,
                        'Ordens de Serviço',
                            () {
                          _fecharMenuENavegar(dialogContext, () {
                            Get.toNamed('/ordens-servico');
                          });
                        },
                      ),

                      _menuItem(
                        Icons.health_and_safety_outlined,
                        'Solicitação de EPI/EPC',
                            () {
                          _fecharMenuENavegar(dialogContext, () {
                            Get.toNamed('/seguranca');
                          });
                        },
                      ),

                      if (usuario.isAdmin || usuario.isGestorSeguranca) ...[
                        _divider('Gestão'),

                        _menuItem(
                          Icons.health_and_safety_outlined,
                          'DDS',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/dds/gestor');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.history_edu,
                          'Histórico de DDS',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/dds/historico');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.inventory_2_outlined,
                          'Gestão de Requisições',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/seguranca/gestao');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.picture_as_pdf_outlined,
                          'Relatório de EPI',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/seguranca/relatorio-epi');
                            });
                          },
                        ),
                      ],

                      if (usuario.isAdmin) ...[
                        _divider('Administração'),

                        _menuItem(
                          Icons.people_outline,
                          'Usuários',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/admin/usuarios');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.checklist_outlined,
                          'Checkmarks',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/admin/checkmarks');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.category_outlined,
                          'Categorias',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/admin/categorias');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.gps_fixed,
                          'Acompanhar Técnicos',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/acompanhamento');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.bar_chart,
                          'Dashboard',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/admin/dashboard');
                            });
                          },
                        ),

                        _menuItem(
                          Icons.security_outlined,
                          'Logs de Auditoria',
                              () {
                            _fecharMenuENavegar(dialogContext, () {
                              Get.toNamed('/admin/logs');
                            });
                          },
                        ),
                      ],

                      _divider(''),

                      _menuItem(
                        Icons.logout,
                        'Sair',
                            () {
                          _fecharMenuENavegar(dialogContext, () {
                            try {
                              Get.find<AuthService>().logout();
                            } catch (e) {
                              if (kDebugMode) {
                                debugPrint('🍔 [Menu] Erro logout: $e');
                              }
                            }
                          });
                        },
                        danger: true,
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _fecharMenu(BuildContext context) {
    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _fecharMenuENavegar(
      BuildContext dialogContext,
      VoidCallback acao,
      ) {
    _fecharMenu(dialogContext);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      acao();
    });
  }

  Widget _menuItem(
      IconData icon,
      String label,
      VoidCallback onTap, {
        bool danger = false,
      }) {
    return ListTile(
      leading: Icon(
        icon,
        color: danger ? Colors.red : Colors.white70,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: danger ? Colors.red : Colors.white70,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _divider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
          ],

          Expanded(
            child: Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavController>();

    return ValueListenableBuilder<bool>(
      valueListenable: nav.mostrarNavNotifier,
      builder: (context, visible, _) {
        if (!visible) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 60 + MediaQuery.of(context).padding.bottom,
          decoration: const BoxDecoration(
            color: Color(0xFF232323),
            border: Border(
              top: BorderSide(
                color: Color(0xFF2A2A2A),
                width: 1,
              ),
            ),
          ),

          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),

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
                      iconColor: selected
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF888888),
                      labelColor: selected
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF888888),
                      isSelected: selected,
                      onTap: () {
                        Get.toNamed('/checklist');
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
                      iconColor: selected
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF888888),
                      labelColor: selected
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF888888),
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
                      iconColor: selected
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF888888),
                      labelColor: selected
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF888888),
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

            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),

            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00FF88).withOpacity(0.15)
                  : Colors.transparent,

              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight:
              isSelected ? FontWeight.bold : FontWeight.normal,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}