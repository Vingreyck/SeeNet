// lib/seguranca/screens/usuarios_gestao_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';
import 'perfil_tecnico_gestor_screen.dart';

class UsuariosGestaoScreen extends StatefulWidget {
  const UsuariosGestaoScreen({super.key});

  @override
  State<UsuariosGestaoScreen> createState() => _UsuariosGestaoScreenState();
}

class _UsuariosGestaoScreenState extends State<UsuariosGestaoScreen>
    with TickerProviderStateMixin {

  // ── Dados ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _filtrados = [];
  bool _carregando = true;
  String _filtroTipo = 'todos';
  String _busca = '';

  // ── Animação ───────────────────────────────────────────────
  late AnimationController _headerCtrl;
  late AnimationController _listCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  final List<AnimationController> _itemCtrls = [];
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchAtivo = false;

  // ── Filtros disponíveis ────────────────────────────────────
  static const _filtros = [
    {'key': 'todos',            'label': 'Todos',    'icon': Icons.people},
    {'key': 'tecnico',          'label': 'Técnicos', 'icon': Icons.engineering},
    {'key': 'administrador',    'label': 'Admins',   'icon': Icons.admin_panel_settings},
    {'key': 'gestor_seguranca', 'label': 'Gestores', 'icon': Icons.security},
  ];

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _listCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _searchFocus.addListener(() => setState(() => _searchAtivo = _searchFocus.hasFocus));
    _searchCtrl.addListener(_aplicarFiltro);

    _carregar();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _listCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Dados ──────────────────────────────────────────────────
  Future<void> _carregar() async {
    setState(() => _carregando = true);
    for (final c in _itemCtrls) c.dispose();
    _itemCtrls.clear();

    final lista = await Get.find<SegurancaService>().buscarTecnicos();

    if (!mounted) return;
    setState(() {
      _todos = lista;
      _carregando = false;
    });

    _aplicarFiltro();
    _headerCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 200));
    _animarItens();
  }

  void _aplicarFiltro() {
    final busca = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _busca = busca;
      _filtrados = _todos.where((u) {
        final tipoOk = _filtroTipo == 'todos' || u['tipo_usuario'] == _filtroTipo;
        final buscaOk = busca.isEmpty ||
            (u['nome'] as String? ?? '').toLowerCase().contains(busca) ||
            (u['email'] as String? ?? '').toLowerCase().contains(busca);
        return tipoOk && buscaOk;
      }).toList();
    });
    _animarItens();
  }

  void _animarItens() {
    for (final c in _itemCtrls) c.dispose();
    _itemCtrls.clear();

    for (int i = 0; i < _filtrados.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      );
      _itemCtrls.add(ctrl);
      Future.delayed(Duration(milliseconds: 40 * i), () {
        if (mounted) ctrl.forward();
      });
    }
  }

  // ── Helpers visuais ────────────────────────────────────────
  static Color _corTipo(String tipo) {
    switch (tipo) {
      case 'administrador':    return const Color(0xFFFF9800);
      case 'gestor_seguranca': return const Color(0xFF2196F3);
      case 'gestor':           return const Color(0xFF9C27B0);
      default:                 return const Color(0xFF00FF88);
    }
  }

  static String _labelTipo(String tipo) {
    switch (tipo) {
      case 'administrador':    return 'ADMIN';
      case 'gestor_seguranca': return 'GESTOR SEG.';
      case 'gestor':           return 'GESTOR';
      default:                 return 'TÉCNICO';
    }
  }

  static IconData _iconeTipo(String tipo) {
    switch (tipo) {
      case 'administrador':    return Icons.admin_panel_settings_rounded;
      case 'gestor_seguranca': return Icons.security_rounded;
      case 'gestor':           return Icons.manage_accounts_rounded;
      default:                 return Icons.engineering_rounded;
    }
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '${partes[0][0]}${partes[partes.length - 1][0]}'.toUpperCase();
  }

  // ── Stats ──────────────────────────────────────────────────
  int _countTipo(String tipo) => _todos.where((u) => u['tipo_usuario'] == tipo).length;

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: _carregando
          ? _buildLoader()
          : RefreshIndicator(
        onRefresh: _carregar,
        color: const Color(0xFF00FF88),
        backgroundColor: const Color(0xFF1E1E1E),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildStats(),
            _buildSearchBar(),
            _buildFiltroChips(),
            _buildResultLabel(),
            _buildLista(),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── Loader ─────────────────────────────────────────────────
  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: Color(0xFF00FF88),
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 16),
          Text('Carregando usuários...',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF111111),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
          onPressed: _carregar,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
        title: SlideTransition(
          position: _headerSlide,
          child: FadeTransition(
            opacity: _headerFade,
            child: const Text(
              'Usuários',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2A1A), Color(0xFF111111)],
            ),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, right: 16),
              child: _GradeDecorativa(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats ──────────────────────────────────────────────────
  Widget _buildStats() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _headerFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              _buildStatCard('${_todos.length}', 'Total', const Color(0xFF00FF88), Icons.people_alt_rounded),
              const SizedBox(width: 10),
              _buildStatCard('${_countTipo("tecnico")}', 'Técnicos', const Color(0xFF00FF88), Icons.engineering_rounded),
              const SizedBox(width: 10),
              _buildStatCard('${_countTipo("administrador")}', 'Admins', const Color(0xFFFF9800), Icons.admin_panel_settings_rounded),
              const SizedBox(width: 10),
              _buildStatCard('${_countTipo("gestor_seguranca")}', 'Gestores', const Color(0xFF2196F3), Icons.security_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String valor, String label, Color cor, IconData icone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: cor, size: 18),
            const SizedBox(height: 4),
            Text(valor,
              style: TextStyle(
                color: cor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.3),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _searchAtivo
                  ? const Color(0xFF00FF88).withOpacity(0.5)
                  : Colors.white.withOpacity(0.07),
              width: 1.5,
            ),
            boxShadow: _searchAtivo
                ? [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.08), blurRadius: 16, spreadRadius: 1)]
                : [],
          ),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou e-mail...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
              prefixIcon: AnimatedRotation(
                turns: _searchAtivo ? 0.05 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.search_rounded,
                    color: _searchAtivo ? const Color(0xFF00FF88) : Colors.white38, size: 20),
              ),
              suffixIcon: _busca.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                onPressed: () { _searchCtrl.clear(); _searchFocus.unfocus(); },
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ── Filtro chips ───────────────────────────────────────────
  Widget _buildFiltroChips() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filtros.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = _filtros[i];
            final sel = _filtroTipo == f['key'];
            final cor = i == 0
                ? const Color(0xFF00FF88)
                : i == 1 ? const Color(0xFF00FF88)
                : i == 2 ? const Color(0xFFFF9800)
                : const Color(0xFF2196F3);

            return GestureDetector(
              onTap: () {
                setState(() => _filtroTipo = f['key'] as String);
                _aplicarFiltro();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? cor.withOpacity(0.15) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? cor : Colors.white12,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f['icon'] as IconData,
                        size: 13,
                        color: sel ? cor : Colors.white38),
                    const SizedBox(width: 5),
                    Text(f['label'] as String,
                        style: TextStyle(
                          color: sel ? cor : Colors.white38,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Label resultado ────────────────────────────────────────
  Widget _buildResultLabel() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Text(
              _busca.isNotEmpty
                  ? '${_filtrados.length} resultado(s) para "$_busca"'
                  : '${_filtrados.length} usuário(s)',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const Spacer(),
            if (_filtrados.isNotEmpty)
              Text(
                _filtroTipo == 'todos' ? 'Todos os perfis' : _labelTipo(_filtroTipo),
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  // ── Lista ──────────────────────────────────────────────────
  Widget _buildLista() {
    if (_filtrados.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              Icon(Icons.person_search_rounded,
                  size: 56, color: Colors.white.withOpacity(0.06)),
              const SizedBox(height: 14),
              Text(
                _busca.isNotEmpty ? 'Nenhum resultado para "$_busca"' : 'Nenhum usuário encontrado',
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, i) {
            if (i >= _itemCtrls.length) return const SizedBox.shrink();
            final user = _filtrados[i];
            final ctrl = _itemCtrls[i];

            return AnimatedBuilder(
              animation: ctrl,
              builder: (_, child) {
                final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: _buildCard(user, i),
            );
          },
          childCount: _filtrados.length,
        ),
      ),
    );
  }

  // ── Card ───────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> user, int index) {
    final tipo    = user['tipo_usuario'] as String? ?? 'tecnico';
    final nome    = user['nome'] as String? ?? '';
    final email   = user['email'] as String? ?? '';
    final cor     = _corTipo(tipo);
    final label   = _labelTipo(tipo);
    final icone   = _iconeTipo(tipo);
    final iniciais = _iniciais(nome);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.to(
                () => PerfilTecnicoGestorScreen(
              tecnicoId:   user['id'] as int,
              tecnicoNome: nome,
            ),
            transition: Transition.rightToLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          splashColor: cor.withOpacity(0.08),
          highlightColor: cor.withOpacity(0.04),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cor.withOpacity(0.15), width: 1),
            ),
            child: Row(
              children: [
                // ── Faixa colorida lateral ──
                Container(
                  width: 4,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ── Avatar com iniciais ─────
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cor.withOpacity(0.3), cor.withOpacity(0.1)],
                    ),
                    border: Border.all(color: cor.withOpacity(0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      iniciais,
                      style: TextStyle(
                        color: cor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ── Info ───────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── Badge tipo ─────────────
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cor.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icone, size: 10, color: cor),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: cor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                Icon(Icons.chevron_right_rounded,
                    color: Colors.white12, size: 18),

                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget decorativo de fundo ─────────────────────────────────
class _GradeDecorativa extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 80,
      child: CustomPaint(painter: _GradePainter()),
    );
  }
}

class _GradePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.06)
      ..strokeWidth = 1;

    const spacing = 18.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final dotPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}