import 'package:flutter/material.dart';
import 'global_bottom_nav.dart';

/// Wrapper de Scaffold que adiciona automaticamente o GlobalBottomNav.
///
/// Use em vez de Scaffold em todas as telas que devem mostrar o bottom nav
/// (Checklist, Seguranca, Perfil, etc.).
///
/// Para telas que NÃO devem mostrar o bottom nav (ex: telas internas como
/// /checklist/items, /diagnostico, /transcricao, /web-admin),
/// continue usando Scaffold normal — ou passe `showBottomNav: false`.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool showBottomNav;
  final FloatingActionButton? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.showBottomNav = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFF1A1A1A),
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      bottomNavigationBar: showBottomNav ? const GlobalBottomNav() : null,
    );
  }
}