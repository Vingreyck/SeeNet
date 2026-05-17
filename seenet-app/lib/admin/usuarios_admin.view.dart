// lib/admin/usuarios_admin.view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import 'package:seenet/widgets/app_snackbar.dart';

class UsuariosAdminView extends StatefulWidget {
  const UsuariosAdminView({super.key});

  @override
  State<UsuariosAdminView> createState() => _UsuariosAdminViewState();
}

class _UsuariosAdminViewState extends State<UsuariosAdminView>
    with TickerProviderStateMixin {

  final ApiService _api = ApiService.instance;

  List<Usuario> _todos = [];
  List<Usuario> _filtrados = [];
  bool _isLoading = true;
  String _filtroTipo = 'todos';
  String _filtroStatus = 'todos';
  String _busca = '';

  // Animações
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  final List<AnimationController> _itemCtrls = [];
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchAtivo = false;

  static const _filtrosTipo = [
    {'key': 'todos',            'label': 'Todos',    'icon': Icons.people_rounded},
    {'key': 'tecnico',          'label': 'Técnicos', 'icon': Icons.engineering_rounded},
    {'key': 'administrador',    'label': 'Admins',   'icon': Icons.admin_panel_settings_rounded},
    {'key': 'gestor_seguranca', 'label': 'Gestores', 'icon': Icons.security_rounded},
  ];

  bool _emailReal(String email) =>
      email.isNotEmpty && !email.endsWith('@seenet.local');

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _searchFocus.addListener(() => setState(() => _searchAtivo = _searchFocus.hasFocus));
    _searchCtrl.addListener(_aplicarFiltro);
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Dados ──────────────────────────────────────────────────
  Future<void> _carregarUsuarios() async {
    setState(() => _isLoading = true);
    for (final c in _itemCtrls) c.dispose();
    _itemCtrls.clear();

    try {
      final response = await _api.get('/admin/users');
      List<dynamic> usuariosData;
      if (response is List) {
        usuariosData = response;
      } else if (response is Map && response.containsKey('data')) {
        final d = response['data'];
        usuariosData = d is List ? d : [d];
      } else {
        throw Exception('Formato inválido');
      }

      final lista = <Usuario>[];
      for (var u in usuariosData) {
        try {
          lista.add(Usuario(
            id: u['id'] as int?,
            nome: u['nome'] as String? ?? '',
            email: u['email'] as String? ?? '',
            senha: '',
            tipoUsuario: u['tipo_usuario'] as String? ?? 'tecnico',
            ativo: u['ativo'] == 1 || u['ativo'] == true,
            dataCriacao: DateTime.tryParse(u['data_criacao'] as String? ?? ''),
          ));
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() { _todos = lista; _isLoading = false; });
      _aplicarFiltro();
      _headerCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackbar.error('Erro', 'Falha ao carregar usuários');
    }
  }

  void _aplicarFiltro() {
    final busca = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _busca = busca;
      _filtrados = _todos.where((u) {
        final tipoOk  = _filtroTipo == 'todos' || u.tipoUsuario == _filtroTipo;
        final statOk  = _filtroStatus == 'todos'
            || (_filtroStatus == 'ativo' && u.ativo)
            || (_filtroStatus == 'inativo' && !u.ativo);
        final buscaOk = busca.isEmpty ||
            u.nome.toLowerCase().contains(busca) ||
            u.email.toLowerCase().contains(busca);
        return tipoOk && statOk && buscaOk;
      }).toList();
    });
    _animarItens();
  }

  void _animarItens() {
    for (final c in _itemCtrls) c.dispose();
    _itemCtrls.clear();
    for (int i = 0; i < _filtrados.length; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 360));
      _itemCtrls.add(ctrl);
      Future.delayed(Duration(milliseconds: 36 * i), () {
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
    final p = nome.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[p.length - 1][0]}'.toUpperCase();
  }

  int _countTipo(String tipo) =>
      _todos.where((u) => u.tipoUsuario == tipo).length;

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: _isLoading ? _buildLoader() : _buildBody(),
    );
  }

  Widget _buildLoader() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 36, height: 36,
          child: CircularProgressIndicator(
              color: Color(0xFF00FF88), strokeWidth: 2.5),
        ),
        SizedBox(height: 16),
        Text('Carregando usuários...',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    ),
  );

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _carregarUsuarios,
      color: const Color(0xFF00FF88),
      backgroundColor: const Color(0xFF1E1E1E),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(),
          _buildStats(),
          _buildSearchBar(),
          _buildFiltrosTipo(),
          _buildFiltrosStatus(),
          _buildResultLabel(),
          _buildLista(),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF111111),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
          onPressed: _carregarUsuarios,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
        title: SlideTransition(
          position: _headerSlide,
          child: FadeTransition(
            opacity: _headerFade,
            child: const Text('Gerenciar Usuários',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                )),
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
    final ativos   = _todos.where((u) => u.ativo).length;
    final inativos = _todos.length - ativos;
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _headerFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              _statCard('${_todos.length}',                  'Total',      Colors.white54,              Icons.people_alt_rounded),
              const SizedBox(width: 8),
              _statCard('${_countTipo("tecnico")}',          'Técnicos',   const Color(0xFF00FF88),     Icons.engineering_rounded),
              const SizedBox(width: 8),
              _statCard('${_countTipo("administrador")}',    'Admins',     const Color(0xFFFF9800),     Icons.admin_panel_settings_rounded),
              const SizedBox(width: 8),
              _statCard('$ativos',                           'Ativos',     const Color(0xFF4CAF50),     Icons.check_circle_outline_rounded),
              const SizedBox(width: 8),
              _statCard('$inativos',                         'Inativos',   Colors.red,                  Icons.block_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String valor, String label, Color cor, IconData icone) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: cor, size: 15),
            const SizedBox(height: 3),
            Text(valor,
                style: TextStyle(color: cor, fontSize: 17,
                    fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 8.5),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                ? [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.08), blurRadius: 16)]
                : [],
          ),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou e-mail...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: _searchAtivo ? const Color(0xFF00FF88) : Colors.white38, size: 20),
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

  // ── Filtros tipo ───────────────────────────────────────────
  Widget _buildFiltrosTipo() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filtrosTipo.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, i) {
            final f = _filtrosTipo[i];
            final sel = _filtroTipo == f['key'];
            final cor = i == 0 ? Colors.white54
                : i == 1 ? const Color(0xFF00FF88)
                : i == 2 ? const Color(0xFFFF9800)
                : const Color(0xFF2196F3);
            return _chipFiltro(
              f['label'] as String, f['icon'] as IconData, sel, cor,
                  () { setState(() => _filtroTipo = f['key'] as String); _aplicarFiltro(); },
            );
          },
        ),
      ),
    );
  }

  // ── Filtros status ─────────────────────────────────────────
  Widget _buildFiltrosStatus() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            _chipFiltro('Todos', Icons.list_rounded, _filtroStatus == 'todos',
                Colors.white54, () { setState(() => _filtroStatus = 'todos'); _aplicarFiltro(); }),
            const SizedBox(width: 7),
            _chipFiltro('Ativos', Icons.check_circle_outline_rounded,
                _filtroStatus == 'ativo', const Color(0xFF4CAF50),
                    () { setState(() => _filtroStatus = 'ativo'); _aplicarFiltro(); }),
            const SizedBox(width: 7),
            _chipFiltro('Inativos', Icons.block_rounded,
                _filtroStatus == 'inativo', Colors.red,
                    () { setState(() => _filtroStatus = 'inativo'); _aplicarFiltro(); }),
          ],
        ),
      ),
    );
  }

  Widget _chipFiltro(String label, IconData icone, bool sel, Color cor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? cor.withOpacity(0.14) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel ? cor : Colors.white12, width: sel ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 12, color: sel ? cor : Colors.white38),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: sel ? cor : Colors.white38,
                    fontSize: 11.5,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  // ── Result label ───────────────────────────────────────────
  Widget _buildResultLabel() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            Text('${_filtrados.length} usuário(s)',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const Spacer(),
            GestureDetector(
              onTap: _abrirDialogNovoUsuario,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_rounded, size: 13, color: Color(0xFF00FF88)),
                    SizedBox(width: 5),
                    Text('Novo Usuário',
                        style: TextStyle(color: Color(0xFF00FF88), fontSize: 11.5,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
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
                  size: 56, color: Colors.white.withOpacity(0.05)),
              const SizedBox(height: 14),
              Text(
                  _busca.isNotEmpty
                      ? 'Nenhum resultado para "$_busca"'
                      : 'Nenhum usuário encontrado',
                  style: const TextStyle(color: Colors.white38, fontSize: 14)),
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
                        begin: const Offset(0, 0.2), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                );
              },
              child: _buildCard(user),
            );
          },
          childCount: _filtrados.length,
        ),
      ),
    );
  }

  // ── Card ───────────────────────────────────────────────────
  Widget _buildCard(Usuario u) {
    final cor      = _corTipo(u.tipoUsuario);
    final label    = _labelTipo(u.tipoUsuario);
    final icone    = _iconeTipo(u.tipoUsuario);
    final iniciais = _iniciais(u.nome);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetalhes(u),
          borderRadius: BorderRadius.circular(18),
          splashColor: cor.withOpacity(0.08),
          highlightColor: cor.withOpacity(0.04),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: u.ativo
                      ? cor.withOpacity(0.15)
                      : Colors.red.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                // Faixa lateral
                Container(
                  width: 4,
                  height: 72,
                  decoration: BoxDecoration(
                    color: u.ativo ? cor : Colors.grey.withOpacity(0.4),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        bottomLeft: Radius.circular(18)),
                  ),
                ),
                const SizedBox(width: 14),

                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [
                            (u.ativo ? cor : Colors.grey).withOpacity(0.3),
                            (u.ativo ? cor : Colors.grey).withOpacity(0.1),
                          ],
                        ),
                        border: Border.all(
                            color: (u.ativo ? cor : Colors.grey).withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: Center(
                        child: Text(iniciais,
                            style: TextStyle(
                                color: u.ativo ? cor : Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                      ),
                    ),
                    // Indicador ativo/inativo
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: u.ativo
                              ? const Color(0xFF4CAF50)
                              : Colors.red.withOpacity(0.8),
                          border: Border.all(
                              color: const Color(0xFF181818), width: 2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(u.nome,
                          style: TextStyle(
                              color: u.ativo ? Colors.white : Colors.white54,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          _emailReal(u.email) ? u.email : 'Sem e-mail cadastrado',
                          style: TextStyle(
                              color: _emailReal(u.email)
                                  ? Colors.white38
                                  : Colors.white24,
                              fontSize: 11,
                              fontStyle: _emailReal(u.email)
                                  ? FontStyle.normal
                                  : FontStyle.italic),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Badge tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(u.ativo ? 0.10 : 0.05),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: cor.withOpacity(u.ativo ? 0.25 : 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icone, size: 9,
                          color: u.ativo ? cor : cor.withOpacity(0.5)),
                      const SizedBox(width: 3),
                      Text(label,
                          style: TextStyle(
                              color: u.ativo ? cor : cor.withOpacity(0.5),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2)),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // Menu
                _buildMenuCard(u),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(Usuario u) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white24, size: 18),
      color: const Color(0xFF242424),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      onSelected: (v) {
        switch (v) {
          case 'detalhes': _mostrarDetalhes(u); break;
          case 'editar':   _editarUsuario(u); break;
          case 'senha':    _resetarSenha(u); break;
          case 'status':   _alternarStatus(u); break;
          case 'remover':  _removerUsuario(u); break;
        }
      },
      itemBuilder: (_) => [
        _menuItem('detalhes', Icons.info_outline_rounded,    'Ver Detalhes',  Colors.blue),
        _menuItem('editar',   Icons.edit_outlined,           'Editar',        Colors.orange),
        _menuItem('senha',    Icons.lock_reset_rounded,      'Resetar Senha', Colors.purple),
        _menuItem('status',
            u.ativo ? Icons.block_rounded : Icons.check_circle_outline_rounded,
            u.ativo ? 'Desativar' : 'Ativar',
            u.ativo ? Colors.red : const Color(0xFF4CAF50)),
        const PopupMenuDivider(height: 1),
        _menuItem('remover',  Icons.delete_outline_rounded,  'Remover',       Colors.red),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icone, String texto, Color cor) {
    return PopupMenuItem(
      value: val,
      height: 42,
      child: Row(
        children: [
          Icon(icone, color: cor, size: 18),
          const SizedBox(width: 10),
          Text(texto, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // DIALOGS
  // ════════════════════════════════════════════════════════

  // ── Detalhes ───────────────────────────────────────────────
  void _mostrarDetalhes(Usuario u) {
    final cor      = _corTipo(u.tipoUsuario);
    final iniciais = _iniciais(u.nome);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),

            // Avatar
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [cor.withOpacity(0.3), cor.withOpacity(0.1)],
                ),
                border: Border.all(color: cor.withOpacity(0.4), width: 2),
              ),
              child: Center(child: Text(iniciais,
                  style: TextStyle(color: cor, fontSize: 22,
                      fontWeight: FontWeight.w800))),
            ),
            const SizedBox(height: 12),
            Text(u.nome,
                style: const TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cor.withOpacity(0.3)),
              ),
              child: Text(_labelTipo(u.tipoUsuario),
                  style: TextStyle(color: cor, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),

            // Info
            _detalheRow(Icons.badge_outlined,       'ID',       '#${u.id}'),
            if (_emailReal(u.email))
              _detalheRow(Icons.email_outlined,     'E-mail',   u.email),
            _detalheRow(
              u.ativo
                  ? Icons.check_circle_outline_rounded
                  : Icons.block_rounded,
              'Status',
              u.ativo ? 'Ativo' : 'Inativo',
              cor: u.ativo ? const Color(0xFF4CAF50) : Colors.red,
            ),
            if (u.dataCriacao != null)
              _detalheRow(Icons.calendar_today_outlined, 'Criado em',
                  _formatarData(u.dataCriacao!)),

            const SizedBox(height: 20),

            // Ações rápidas
            Row(
              children: [
                _atalhoDialog('Editar', Icons.edit_outlined, Colors.orange,
                        () { Navigator.pop(context); _editarUsuario(u); }),
                const SizedBox(width: 10),
                _atalhoDialog('Senha', Icons.lock_reset_rounded, Colors.purple,
                        () { Navigator.pop(context); _resetarSenha(u); }),
                const SizedBox(width: 10),
                _atalhoDialog(
                    u.ativo ? 'Desativar' : 'Ativar',
                    u.ativo ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                    u.ativo ? Colors.red : const Color(0xFF4CAF50),
                        () { Navigator.pop(context); _alternarStatus(u); }),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _detalheRow(IconData icone, String label, String valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icone, color: cor ?? Colors.white24, size: 16),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 13)),
          Expanded(
            child: Text(valor,
                style: TextStyle(
                    color: cor ?? Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _atalhoDialog(String label, IconData icone, Color cor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cor.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icone, color: cor, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(color: cor, fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Editar ─────────────────────────────────────────────────
  void _editarUsuario(Usuario u) {
    final nomeCtrl  = TextEditingController(text: u.nome);
    final emailCtrl = TextEditingController(
        text: _emailReal(u.email) ? u.email : '');
    String tipoSel  = u.tipoUsuario;
    bool   ativoSel = u.ativo;

    _dialogDark(
      titulo: 'Editar Usuário',
      icone:  Icons.edit_rounded,
      cor:    Colors.orange,
      conteudo: StatefulBuilder(
        builder: (ctx, setD) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _inputDark('Nome', nomeCtrl, icone: Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _inputDark('E-mail (opcional)', emailCtrl,
                icone: Icons.email_outlined,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _dropdownDark(
              label: 'Tipo',
              valor: tipoSel,
              items: const [
                DropdownMenuItem(value: 'tecnico',          child: Text('Técnico')),
                DropdownMenuItem(value: 'gestor_seguranca', child: Text('Gestor de Segurança')),
                DropdownMenuItem(value: 'administrador',    child: Text('Administrador')),
              ],
              onChanged: (v) => setD(() => tipoSel = v!),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.circle, size: 10, color: Colors.white38),
                const SizedBox(width: 10),
                const Text('Usuário ativo',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(),
                Switch(
                  value: ativoSel,
                  activeColor: const Color(0xFF00FF88),
                  onChanged: (v) => setD(() => ativoSel = v),
                ),
              ],
            ),
          ],
        ),
      ),
      acoes: [
        _botaoDialog('Cancelar', Colors.white24, () => Navigator.pop(context), outline: true),
        const SizedBox(width: 10),
        _botaoDialog('Salvar', Colors.orange, () async {
          Navigator.pop(context);
          await _salvarEdicao(u.id!, nomeCtrl.text.trim(),
              emailCtrl.text.trim(), tipoSel, ativoSel);
        }),
      ],
    );
  }

  Future<void> _salvarEdicao(
      int id, String nome, String email, String tipo, bool ativo) async {
    try {
      final payload = <String, dynamic>{'nome': nome, 'tipo_usuario': tipo, 'ativo': ativo};
      if (email.isNotEmpty) payload['email'] = email.toLowerCase();
      final r = await _api.put('/auth/usuarios/$id', payload);
      if (r['success'] == true) {
        AppSnackbar.success('Sucesso', 'Usuário atualizado!');
        await _carregarUsuarios();
      } else { throw Exception(r['error']); }
    } catch (e) { AppSnackbar.error('Erro', '$e'); }
  }

  // ── Reset senha ────────────────────────────────────────────
  void _resetarSenha(Usuario u) {
    final novaCtrl  = TextEditingController();
    final confCtrl  = TextEditingController();

    _dialogDark(
      titulo: 'Resetar Senha',
      icone:  Icons.lock_reset_rounded,
      cor:    Colors.purple,
      conteudo: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: Colors.purple, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(u.nome,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _inputDark('Nova Senha', novaCtrl,
              icone: Icons.lock_outlined, obscure: true),
          const SizedBox(height: 12),
          _inputDark('Confirmar Senha', confCtrl,
              icone: Icons.lock_outline_rounded, obscure: true),
        ],
      ),
      acoes: [
        _botaoDialog('Cancelar', Colors.white24, () => Navigator.pop(context), outline: true),
        const SizedBox(width: 10),
        _botaoDialog('Resetar', Colors.purple, () async {
          if (novaCtrl.text.length < 6) {
            AppSnackbar.warning('Atenção', 'Mínimo 6 caracteres'); return;
          }
          if (novaCtrl.text != confCtrl.text) {
            AppSnackbar.warning('Atenção', 'Senhas não coincidem'); return;
          }
          Navigator.pop(context);
          await _confirmarReset(u.id!, novaCtrl.text);
        }),
      ],
    );
  }

  Future<void> _confirmarReset(int id, String senha) async {
    try {
      final r = await _api.put('/auth/usuarios/$id/resetar-senha', {'nova_senha': senha});
      if (r['success'] == true) {
        AppSnackbar.success('Sucesso', '🔐 Senha resetada com sucesso!');
      } else { throw Exception(r['error']); }
    } catch (e) { AppSnackbar.error('Erro', 'Falha ao resetar senha'); }
  }

  // ── Ativar/Desativar ───────────────────────────────────────
  void _alternarStatus(Usuario u) {
    final novoStatus = !u.ativo;
    final cor = novoStatus ? const Color(0xFF4CAF50) : Colors.red;

    _dialogDark(
      titulo: novoStatus ? 'Ativar Usuário' : 'Desativar Usuário',
      icone:  novoStatus ? Icons.check_circle_outline_rounded : Icons.block_rounded,
      cor:    cor,
      conteudo: Text(
        novoStatus
            ? 'Deseja ativar "${u.nome}"?\nEle poderá fazer login normalmente.'
            : 'Deseja desativar "${u.nome}"?\nEle não conseguirá fazer login.',
        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        textAlign: TextAlign.center,
      ),
      acoes: [
        _botaoDialog('Cancelar', Colors.white24, () => Navigator.pop(context), outline: true),
        const SizedBox(width: 10),
        _botaoDialog(novoStatus ? 'Ativar' : 'Desativar', cor, () async {
          Navigator.pop(context);
          await _aplicarStatus(u.id!, novoStatus);
        }),
      ],
    );
  }

  Future<void> _aplicarStatus(int id, bool ativo) async {
    try {
      final r = await _api.put('/auth/usuarios/$id/status', {'ativo': ativo});
      if (r['success'] == true) {
        AppSnackbar.success('Sucesso', 'Status ${ativo ? "ativado" : "desativado"}!');
        await _carregarUsuarios();
      } else { throw Exception(r['error']); }
    } catch (e) { AppSnackbar.error('Erro', 'Falha ao atualizar status'); }
  }

  // ── Remover ────────────────────────────────────────────────
  void _removerUsuario(Usuario u) {
    _dialogDark(
      titulo: 'Remover Usuário',
      icone:  Icons.delete_outline_rounded,
      cor:    Colors.red,
      conteudo: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tem certeza que deseja remover?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(u.nome,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.bold)),
                if (_emailReal(u.email)) ...[
                  const SizedBox(height: 2),
                  Text(u.email,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                SizedBox(width: 6),
                Text('Esta ação não pode ser desfeita.',
                    style: TextStyle(color: Colors.red, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      acoes: [
        _botaoDialog('Cancelar', Colors.white24, () => Navigator.pop(context), outline: true),
        const SizedBox(width: 10),
        _botaoDialog('Remover', Colors.red, () async {
          Navigator.pop(context);
          await _confirmarRemocao(u.id!);
        }),
      ],
    );
  }

  Future<void> _confirmarRemocao(int id) async {
    try {
      final r = await _api.delete('/auth/usuarios/$id');
      if (r['success'] == true) {
        AppSnackbar.success('Sucesso', 'Usuário removido!');
        await _carregarUsuarios();
      } else { throw Exception(r['error']); }
    } catch (e) { AppSnackbar.error('Erro', 'Falha ao remover'); }
  }

  // ── Novo usuário ───────────────────────────────────────────
  void _abrirDialogNovoUsuario() {
    final nomeCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    String tipoSel  = 'tecnico';

    _dialogDark(
      titulo: 'Novo Usuário',
      icone:  Icons.person_add_rounded,
      cor:    const Color(0xFF00FF88),
      conteudo: StatefulBuilder(
        builder: (ctx, setD) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _inputDark('Nome *', nomeCtrl, icone: Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _inputDark('E-mail (opcional)', emailCtrl,
                icone: Icons.email_outlined,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _inputDark('Senha *', senhaCtrl,
                icone: Icons.lock_outlined, obscure: true),
            const SizedBox(height: 12),
            _dropdownDark(
              label: 'Tipo',
              valor: tipoSel,
              items: const [
                DropdownMenuItem(value: 'tecnico',          child: Text('Técnico')),
                DropdownMenuItem(value: 'gestor_seguranca', child: Text('Gestor de Segurança')),
                DropdownMenuItem(value: 'administrador',    child: Text('Administrador')),
              ],
              onChanged: (v) => setD(() => tipoSel = v!),
            ),
          ],
        ),
      ),
      acoes: [
        _botaoDialog('Cancelar', Colors.white24, () => Navigator.pop(context), outline: true),
        const SizedBox(width: 10),
        _botaoDialog('Criar', const Color(0xFF00FF88), () async {
          if (nomeCtrl.text.trim().isEmpty || senhaCtrl.text.length < 6) {
            AppSnackbar.warning('Atenção', 'Preencha nome e senha (mín. 6 chars)');
            return;
          }
          Navigator.pop(context);
          await _criarUsuario(nomeCtrl.text.trim(),
              emailCtrl.text.trim(), senhaCtrl.text, tipoSel);
        }, textColor: Colors.black),
      ],
    );
  }

  Future<void> _criarUsuario(
      String nome, String email, String senha, String tipo) async {
    try {
      final payload = <String, dynamic>{
        'nome': nome, 'senha': senha, 'tipo_usuario': tipo,
      };
      if (email.isNotEmpty) payload['email'] = email.toLowerCase();
      final r = await _api.post('/auth/register', payload);
      if (r['success'] == true) {
        AppSnackbar.success('Sucesso', 'Usuário criado com sucesso!');
        await _carregarUsuarios();
      } else { throw Exception(r['error']); }
    } catch (e) { AppSnackbar.error('Erro', '$e'); }
  }

  // ════════════════════════════════════════════════════════
  // HELPERS DE UI
  // ════════════════════════════════════════════════════════
  void _dialogDark({
    required String titulo,
    required IconData icone,
    required Color cor,
    required Widget conteudo,
    required List<Widget> acoes,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icone, color: cor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(titulo,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              conteudo,
              const SizedBox(height: 20),
              Row(
                children: acoes.map((w) => w is SizedBox ? w : Expanded(child: w)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputDark(String label, TextEditingController ctrl, {
    IconData? icone,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: icone != null
            ? Icon(icone, color: Colors.white24, size: 18) : null,
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dropdownDark({
    required String label,
    required String valor,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: valor,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      dropdownColor: const Color(0xFF242424),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00FF88), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _botaoDialog(String label, Color cor, VoidCallback onTap, {
    bool outline = false,
    Color textColor = Colors.white,
  }) {
    if (outline) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: cor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label,
            style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
      );
    }
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

// ── Grade decorativa ───────────────────────────────────────────
class _GradeDecorativa extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120, height: 80,
    child: CustomPaint(painter: _GradePainter()),
  );
}

class _GradePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.06)
      ..strokeWidth = 1;
    const s = 18.0;
    for (double x = 0; x < size.width; x += s)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p1);
    for (double y = 0; y < size.height; y += s)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p1);
    final p2 = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += s)
      for (double y = 0; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.5, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}