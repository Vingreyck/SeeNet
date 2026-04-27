import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/nav_controller.dart';
import '../services/auth_service.dart';
import '../controllers/usuario_controller.dart';

class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({super.key});

  void _abrirMenuGlobal(BuildContext context, NavController nav) {
    final usuario = Get.find<UsuarioController>();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
      // ✅ dialogContext = context do próprio dialog. Permite fechar via
      //    Navigator.pop direto (sem passar por Get.back, que internamente
      //    aciona closeCurrentSnackbar e gera o LateInitializationError).
      pageBuilder: (dialogContext, __, ___) => Align(
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

                    _menuItem(Icons.home_outlined, 'Início', () {
                      _fecharMenuENavegar(dialogContext, () {
                        nav.selecionarTabSafe(1);
                        Get.toNamed('/checklist');
                      });
                    }),
                    _menuItem(Icons.assignment_outlined, 'Ordens de Serviço', () {
                      _fecharMenuENavegar(dialogContext, () {
                        Get.toNamed('/ordens-servico');
                      });
                    }),
                    _menuItem(Icons.health_and_safety_outlined, 'Solicitação de EPI/EPC', () {
                      _fecharMenuENavegar(dialogContext, () {
                        Get.toNamed('/seguranca');
                      });
                    }),

                    if (usuario.isAdmin || usuario.isGestorSeguranca) ...[
                      _divider('Gestão'),
                      _menuItem(Icons.inventory_2_outlined, 'Gestão de Requisições', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/seguranca/gestao');
                        });
                      }),
                      _menuItem(Icons.picture_as_pdf_outlined, 'Relatório de EPI', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/seguranca/relatorio-epi');
                        });
                      }),
                    ],

                    if (usuario.isAdmin) ...[
                      _divider('Administração'),
                      _menuItem(Icons.people_outline, 'Usuários', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/admin/usuarios');
                        });
                      }),
                      _menuItem(Icons.checklist_outlined, 'Checkmarks', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/admin/checkmarks');
                        });
                      }),
                      _menuItem(Icons.category_outlined, 'Categorias', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/admin/categorias');
                        });
                      }),
                      _menuItem(Icons.gps_fixed, 'Acompanhar Técnicos', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/acompanhamento');
                        });
                      }),
                      _menuItem(Icons.bar_chart, 'Dashboard', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/admin/dashboard');
                        });
                      }),
                      _menuItem(Icons.security_outlined, 'Logs de Auditoria', () {
                        _fecharMenuENavegar(dialogContext, () {
                          Get.toNamed('/admin/logs');
                        });
                      }),
                    ],

                    _divider(''),
                    _menuItem(Icons.logout, 'Sair', () {
                      _fecharMenuENavegar(dialogContext, () {
                        Get.find<AuthService>().logout();
                      });
                    }, danger: true),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fecha o menu lateral usando Navigator.pop direto e agenda
  /// a navegação para o próximo frame.
  void _fecharMenuENavegar(BuildContext dialogContext, VoidCallback acao) {
    if (Navigator.canPop(dialogContext)) {
      Navigator.of(dialogContext).pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      acao();
    });
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.red : Colors.white70, size: 22),
      title: Text(
        label,
        style: TextStyle(color: danger ? Colors.red : Colors.white70, fontSize: 15),
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
          Expanded(child: Container(height: 0.5, color: Colors.white.withOpacity(0.1))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavController>();
    final labels = ['Menu', 'Início', 'EPI', 'Perfil'];
    final icons = [
      Icons.menu_rounded,
      Icons.home_rounded,
      Icons.health_and_safety_rounded,
      Icons.person_rounded,
    ];

    // ✅ Obx envolve TODO o nav (igual antes), reage a mostrarNav.
    //    Mas como o NavController só atualiza via addPostFrameCallback,
    //    esse rebuild acontece DEPOIS da transição de rota — sem conflito
    //    com os overlays internos do GetX.
    return Obx(() {
      if (!nav.mostrarNav) return const SizedBox.shrink();

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
              final selected = i != 0 && nav.selectedIndex.value == i;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i == 0) {
                      _abrirMenuGlobal(context, nav);
                      return;
                    }

                    // ✅ Navega PRIMEIRO; o índice é setado depois do frame
                    //    via selecionarTabSafe (evita rebuild durante a
                    //    transição).
                    if (i == 1) Get.toNamed('/checklist');
                    if (i == 2) Get.toNamed('/seguranca');
                    if (i == 3) Get.toNamed('/seguranca/perfil');
                    nav.selecionarTabSafe(i);
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
                              ? const Color(0xFF888888)
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
    });
  }
}