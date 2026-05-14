// lib/seguranca/screens/perfil_tecnico_gestor_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/web_pdf_helper.dart' if (dart.library.io) '../widgets/web_pdf_helper_stub.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../services/seguranca_service.dart';
import '../controllers/seguranca_controller.dart';
import '../widgets/botao_pdf.dart';
import 'registro_manual_epi_screen.dart';
import '../../dds/screens/dds_calendario_tecnico_screen.dart';

class PerfilTecnicoGestorScreen extends StatefulWidget {
  final int tecnicoId;
  final String tecnicoNome;

  const PerfilTecnicoGestorScreen({
    super.key,
    required this.tecnicoId,
    required this.tecnicoNome,
  });

  @override
  State<PerfilTecnicoGestorScreen> createState() =>
      _PerfilTecnicoGestorScreenState();
}

class _PerfilTecnicoGestorScreenState
    extends State<PerfilTecnicoGestorScreen>
    with TickerProviderStateMixin {

  final _service    = Get.find<SegurancaService>();
  final _controller = Get.find<SegurancaController>();

  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _requisicoes = [];
  bool _isLoading = true;
  String? _erro;

  // Abas
  late TabController _tabCtrl;
  String _filtroStatus = 'todas';
  int? _filtroAno;
  int? _filtroMes;

  // Animações
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _headerCtrl, curve: Curves.easeOutCubic));

    _carregarPerfil();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  // ── Cor / Label por tipo ───────────────────────────────────
  Color _corTipo(String tipo) {
    switch (tipo) {
      case 'administrador':    return const Color(0xFFFF9800);
      case 'gestor_seguranca': return const Color(0xFF2196F3);
      case 'gestor':           return const Color(0xFF9C27B0);
      default:                 return const Color(0xFF00FF88);
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo) {
      case 'administrador':    return 'ADMINISTRADOR';
      case 'gestor_seguranca': return 'GESTOR DE SEGURANÇA';
      case 'gestor':           return 'GESTOR';
      default:                 return 'TÉCNICO';
    }
  }

  String _iniciais(String nome) {
    final p = nome.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[p.length - 1][0]}'.toUpperCase();
  }

  // ── Dados ──────────────────────────────────────────────────
  Future<void> _carregarPerfil() async {
    setState(() { _isLoading = true; _erro = null; });
    try {
      final data = await _service.buscarPerfilTecnico(widget.tecnicoId);
      if (data != null) {
        setState(() {
          _perfil = data['usuario'];
          _stats  = data['stats'];
          final List r = data['requisicoes'] ?? [];
          _requisicoes = r.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        _headerCtrl.forward(from: 0);
      } else {
        setState(() { _erro = 'Não foi possível carregar o perfil'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _erro = 'Erro: $e'; _isLoading = false; });
    }
  }

  // ════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: _isLoading
          ? _buildLoader()
          : _erro != null
          ? _buildErro()
          : _buildConteudo(),
    );
  }

  Widget _buildLoader() => const Center(
    child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2.5),
  );

  Widget _buildErro() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 56, color: Colors.red),
        const SizedBox(height: 12),
        Text(_erro!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _carregarPerfil,
          icon: const Icon(Icons.refresh, color: Colors.black),
          label: const Text('Tentar novamente', style: TextStyle(color: Colors.black)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
        ),
      ],
    ),
  );

  Widget _buildConteudo() {
    final tipo = _perfil?['tipo_usuario'] as String? ?? 'tecnico';
    final cor  = _corTipo(tipo);

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        _buildSliverHeader(cor, tipo),
      ],
      body: _buildBody(cor),
    );
  }

  // ── Sliver header ─────────────────────────────────────────
  SliverAppBar _buildSliverHeader(Color cor, String tipo) {
    final nome     = _perfil?['nome'] as String? ?? '';
    final iniciais = _iniciais(nome);

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: const Color(0xFF111111),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
          onPressed: _carregarPerfil,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradiente de fundo
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cor.withOpacity(0.20),
                    cor.withOpacity(0.05),
                    const Color(0xFF111111),
                  ],
                  stops: const [0, 0.6, 1],
                ),
              ),
            ),
            // Grade decorativa
            Positioned(
              top: 0, right: 0,
              child: _GradeDecorativa(cor: cor),
            ),
            // Conteúdo do header
            SafeArea(
              child: FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cor.withOpacity(0.35), cor.withOpacity(0.12)],
                          ),
                          border: Border.all(color: cor.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(color: cor.withOpacity(0.2), blurRadius: 20, spreadRadius: 2),
                          ],
                        ),
                        child: Center(
                          child: Text(iniciais,
                              style: TextStyle(
                                color: cor,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              )),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Nome
                      Text(nome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(height: 6),
                      // Badge de tipo
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: cor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cor.withOpacity(0.3)),
                        ),
                        child: Text(_labelTipo(tipo),
                            style: TextStyle(
                              color: cor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: TabBar(
        controller: _tabCtrl,
        indicatorColor: cor,
        labelColor: cor,
        unselectedLabelColor: Colors.white38,
        indicatorWeight: 2.5,
        tabs: const [
          Tab(text: 'EPI'),
          Tab(text: 'Documentos'),
          Tab(text: 'Info'),
        ],
      ),
    );
  }

  // ── Body com TabBarView ────────────────────────────────────
  Widget _buildBody(Color cor) {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildAbaEPI(cor),
        _buildAbaDocumentos(cor),
        _buildAbaInfo(cor),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // ABA 1: REQUISIÇÕES
  // ════════════════════════════════════════════════════════
  Widget _buildAbaEPI(Color cor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_stats != null) _buildStatsEPI(cor),
          const SizedBox(height: 14),
          // Botão de registrar EPI (único aqui)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Get.to(() => RegistroManualEpiScreen(
                  tecnicoIdFixo:   widget.tecnicoId,
                  tecnicoNomeFixo: widget.tecnicoNome,
                ));
                _carregarPerfil();
              },
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.black, size: 20),
              label: const Text('Registrar EPI Manual',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildListaRequisicoes(cor),
        ],
      ),
    );
  }

  Widget _buildAbaDocumentos(Color cor) {
    final temAssinatura = _perfil?['assinatura_admissao'] != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Ficha de EPI ───────────────────────────────────
          _buildDocCard(
            titulo: 'Ficha de EPI Completa',
            subtitulo: 'Histórico completo de equipamentos entregues',
            icone: Icons.description_outlined,
            cor: const Color(0xFF00BCD4),
            botaoLabel: 'Gerar PDF',
            botaoIcone: Icons.download_rounded,
            onTap: _gerarFichaEpi,
          ),

          const SizedBox(height: 12),

          // ── Assinatura de Admissão ─────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: temAssinatura
                    ? const Color(0xFF00FF88).withOpacity(0.25)
                    : Colors.orange.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (temAssinatura
                              ? const Color(0xFF00FF88)
                              : Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          temAssinatura ? Icons.check_circle_outline : Icons.draw_outlined,
                          color: temAssinatura ? const Color(0xFF00FF88) : Colors.orange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Assinatura de Admissão',
                                style: TextStyle(color: Colors.white, fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              temAssinatura
                                  ? 'Assinatura cadastrada'
                                  : 'Nenhuma assinatura cadastrada',
                              style: TextStyle(
                                color: temAssinatura
                                    ? const Color(0xFF00FF88).withOpacity(0.8)
                                    : Colors.orange.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Preview ou botão de upload
                      ElevatedButton.icon(
                        onPressed: _uploadAssinaturaAdmissao,
                        icon: Icon(
                          temAssinatura ? Icons.refresh_rounded : Icons.upload_rounded,
                          size: 16, color: Colors.black,
                        ),
                        label: Text(temAssinatura ? 'Atualizar' : 'Enviar',
                            style: const TextStyle(color: Colors.black, fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: temAssinatura
                              ? const Color(0xFF00FF88)
                              : Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Preview da assinatura se existir
                if (temAssinatura) ...[
                  Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Builder(builder: (_) {
                        try {
                          final clean = (_perfil!['assinatura_admissao'] as String)
                              .replaceFirst(RegExp(r'^data:image/\w+;base64,'), '');
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(base64Decode(clean), fit: BoxFit.contain),
                          );
                        } catch (_) {
                          return const Center(child: Text('Assinatura salva',
                              style: TextStyle(color: Colors.black38)));
                        }
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper para cards de documento
  Widget _buildDocCard({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Color cor,
    required String botaoLabel,
    required IconData botaoIcone,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, color: cor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.white,
                    fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitulo, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(botaoIcone, size: 15, color: Colors.black),
            label: Text(botaoLabel, style: const TextStyle(color: Colors.black,
                fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: cor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaInfo(Color cor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(cor),
          const SizedBox(height: 12),

          // Botão DDS
          GestureDetector(
            onTap: () => Get.to(() => DdsCalendarioTecnicoScreen(
              tecnicoId:   widget.tecnicoId,
              tecnicoNome: widget.tecnicoNome,
            )),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.health_and_safety_outlined,
                        color: Color(0xFF2196F3), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Histórico DDS',
                            style: TextStyle(color: Colors.white, fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('Ver presença nos Diálogos de Segurança',
                            style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF2196F3), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsEPI(Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: Colors.white38, size: 16),
              SizedBox(width: 6),
              Text('Requisições de EPI',
                  style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statEpi('${_stats?['total'] ?? 0}',     'Total',      Colors.white54),
              _dividerStat(),
              _statEpi('${_stats?['concluidas'] ?? 0}','Concluídas', const Color(0xFF00FF88)),
              _dividerStat(),
              _statEpi('${_stats?['pendentes'] ?? 0}', 'Pendentes',  Colors.orange),
              _dividerStat(),
              _statEpi('${_stats?['recusadas'] ?? 0}', 'Recusadas',  Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statEpi(String v, String l, Color c) => Expanded(
    child: Column(
      children: [
        Text(v, style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    ),
  );

  Widget _dividerStat() => Container(
    width: 1, height: 32,
    color: Colors.white.withOpacity(0.08),
  );

  Widget _buildListaRequisicoes(Color cor) {
    final historico = _requisicoes.where((r) => r['eh_fichario'] != true).toList();
    final fichario  = _requisicoes.where((r) => r['eh_fichario'] == true).toList();

    // Filtros de período
    var filtradas = _filtroStatus == 'todas'
        ? historico
        : _filtroStatus == 'aprovada'
        ? historico.where((r) => r['status'] == 'aprovada' || r['status'] == 'aguardando_confirmacao').toList()
        : historico.where((r) => r['status'] == _filtroStatus).toList();

    if (_filtroAno != null) {
      filtradas = filtradas.where((r) {
        try {
          final dt = DateTime.parse(r['data_entrega'] ?? r['data_criacao']).toLocal();
          if (dt.year != _filtroAno) return false;
          if (_filtroMes != null && dt.month != _filtroMes) return false;
          return true;
        } catch (_) { return false; }
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header lista
        Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.white38, size: 16),
            const SizedBox(width: 6),
            const Text('Histórico de Requisições',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${historico.length} registro(s)',
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),

        const SizedBox(height: 12),

        // Filtro status
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipFiltro('Todas',     'todas',    historico.length),
              const SizedBox(width: 6),
              _chipFiltro('Concluídas','concluida',historico.where((r) => r['status'] == 'concluida').length),
              const SizedBox(width: 6),
              _chipFiltro('Aprovadas', 'aprovada', historico.where((r) => r['status'] == 'aprovada' || r['status'] == 'aguardando_confirmacao').length),
              const SizedBox(width: 6),
              _chipFiltro('Pendentes', 'pendente', historico.where((r) => r['status'] == 'pendente').length),
              const SizedBox(width: 6),
              _chipFiltro('Recusadas', 'recusada', historico.where((r) => r['status'] == 'recusada').length),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _buildFiltroData(),
        const SizedBox(height: 12),

        if (filtradas.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 42, color: Colors.white.withOpacity(0.06)),
                const SizedBox(height: 10),
                const Text('Nenhuma requisição neste filtro',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          )
        else
          ...filtradas.map((req) => _buildCardRequisicao(req)),

        if (fichario.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.folder_special_outlined, color: Colors.purple, size: 16),
              const SizedBox(width: 6),
              Text('Fichário (${fichario.length})',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ...fichario.map((req) => _buildCardFichario(req)),
        ],
      ],
    );
  }

  Widget _chipFiltro(String label, String status, int count) {
    final sel = _filtroStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filtroStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF00FF88).withOpacity(0.12) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? const Color(0xFF00FF88) : Colors.white12,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Text('$label ($count)',
            style: TextStyle(
              color: sel ? const Color(0xFF00FF88) : Colors.white38,
              fontSize: 11,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _buildFiltroData() {
    final anos = _requisicoes.map((r) {
      try { return DateTime.parse(r['data_criacao']).toLocal().year; } catch (_) { return null; }
    }).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));

    const meses = ['','Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

    if (anos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              const Text('Filtrar por período',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              if (_filtroAno != null || _filtroMes != null)
                GestureDetector(
                  onTap: () => setState(() { _filtroAno = null; _filtroMes = null; }),
                  child: const Text('Limpar', style: TextStyle(color: Colors.red, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: anos.map((ano) {
                final sel = _filtroAno == ano;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _filtroAno = sel ? null : ano),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF00FF88).withOpacity(0.12) : const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? const Color(0xFF00FF88) : Colors.white12),
                      ),
                      child: Text('$ano',
                          style: TextStyle(
                            color: sel ? const Color(0xFF00FF88) : Colors.white54,
                            fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_filtroAno != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: List.generate(12, (i) {
                final mes = i + 1;
                final sel = _filtroMes == mes;
                final temDados = _requisicoes.any((r) {
                  try {
                    final dt = DateTime.parse(r['data_criacao']).toLocal();
                    return dt.year == _filtroAno && dt.month == mes;
                  } catch (_) { return false; }
                });
                return GestureDetector(
                  onTap: temDados ? () => setState(() => _filtroMes = sel ? null : mes) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF00FF88).withOpacity(0.12) : const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sel ? const Color(0xFF00FF88) : Colors.white12),
                    ),
                    child: Text(meses[mes],
                        style: TextStyle(
                          color: !temDados ? Colors.white12 : sel ? const Color(0xFF00FF88) : Colors.white54,
                          fontSize: 10,
                        )),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardRequisicao(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pendente';
    final cor    = _controller.statusColor(status);
    final label  = _controller.statusLabel(status);
    final epis   = req['epis_solicitados'];
    final List<String> episLista = epis is List
        ? epis.cast<String>()
        : (epis is String ? _parseEpis(epis) : []);
    final temFoto = req['foto_recebimento_base64'] != null;
    final temSig  = req['assinatura_recebimento_base64'] != null;
    final temPdf  = req['pdf_base64'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(label,
                      style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                if (req['registro_manual'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Manual',
                        style: TextStyle(color: Colors.blue, fontSize: 9)),
                  ),
                ],
                const Spacer(),
                Text('Req. #${req['id']}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // EPIs
                Wrap(
                  spacing: 5, runSpacing: 5,
                  children: episLista.take(6).map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(e,
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  )).toList(),
                ),
                if (episLista.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('+${episLista.length - 6} mais',
                        style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  ),

                const SizedBox(height: 8),

                // Datas
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: Colors.white24),
                    const SizedBox(width: 4),
                    Text(_formatarData(req['data_criacao']),
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    if (req['gestor_nome'] != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.person_outline_rounded, size: 12, color: Colors.white24),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(req['gestor_nome'],
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),

                if (req['id_requisicao_ixc'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFF00FF88)),
                      const SizedBox(width: 4),
                      Text('IXC Req. #${req['id_requisicao_ixc']}',
                          style: const TextStyle(color: Color(0xFF00FF88), fontSize: 10)),
                    ],
                  ),
                ],

                if (temFoto || temSig || temPdf) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (temFoto)
                        _buildMiniBtn('Foto', Icons.photo_camera_outlined, const Color(0xFF00FF88),
                                () => _verImagem(req['foto_recebimento_base64'], 'Foto de Recebimento')),
                      if (temFoto && temSig) const SizedBox(width: 6),
                      if (temSig)
                        _buildMiniBtn('Assinatura', Icons.draw_outlined, const Color(0xFF00FF88),
                                () => _verImagem(req['assinatura_recebimento_base64'], 'Assinatura Digital')),
                      const Spacer(),
                      if (temPdf)
                        BotaoPDF(requisicaoId: req['id'] as int, pdfBase64Cached: req['pdf_base64']),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBtn(String label, IconData icon, Color cor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cor, size: 12),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: cor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFichario(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List
        ? epis.cast<String>()
        : (epis is String ? _parseEpis(epis) : []);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_special_outlined, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatarData(req['data_entrega'] ?? req['data_criacao']),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${episLista.length} EPI(s): ${episLista.take(3).join(', ')}${episLista.length > 3 ? '...' : ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 2),
              ],
            ),
          ),
          if (req['pdf_base64'] != null)
            BotaoPDF(requisicaoId: req['id'] as int, pdfBase64Cached: req['pdf_base64']),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // ABA 2: INFORMAÇÕES
  // ════════════════════════════════════════════════════════

  Widget _buildInfoCard(Color cor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email_outlined, 'E-mail',
              _perfil?['email'] ?? '--',
              isFirst: true),
          _buildDivider(),
          _buildInfoRow(Icons.business_outlined, 'Empresa',
              _perfil?['empresa'] ?? '--'),
          _buildDivider(),
          _buildInfoRow(Icons.calendar_today_outlined, 'Membro desde',
              _formatarData(_perfil?['data_criacao'])),
          if (_perfil?['ultimo_login'] != null) ...[
            _buildDivider(),
            _buildInfoRow(Icons.access_time_rounded, 'Último acesso',
                _formatarData(_perfil?['ultimo_login'])),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isFirst = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 44);

  // ════════════════════════════════════════════════════════
  // AÇÕES
  // ════════════════════════════════════════════════════════
  Future<void> _gerarFichaEpi() async {
    Get.snackbar('Gerando...', 'Aguarde o PDF.',
        backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white);
    final pdfBase64 = await _service.buscarFichaEpi(widget.tecnicoId);
    if (pdfBase64 == null) {
      if (mounted) Get.snackbar('Erro', 'Falha ao gerar ficha',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (kIsWeb) {
      final clean = pdfBase64.replaceFirst(RegExp(r'^data:application/pdf;base64,'), '');
      abrirPdfNoNavegador(base64Decode(clean));
      return;
    }
    final clean = pdfBase64.replaceFirst(RegExp(r'^data:application/pdf;base64,'), '');
    final bytes = base64Decode(clean);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Ficha_EPI_${widget.tecnicoNome.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Ficha de EPI - ${widget.tecnicoNome}',
    );
  }

  Future<void> _uploadAssinaturaAdmissao() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final result = await _service.uploadAssinaturaAdmissao(widget.tecnicoId, b64);
    if (mounted) {
      Get.snackbar(
        result['success'] == true ? 'Salvo!' : 'Erro',
        result['message'] ?? 'Erro',
        backgroundColor: result['success'] == true ? const Color(0xFF00C853) : Colors.red,
        colorText: Colors.white,
      );
      if (result['success'] == true) _carregarPerfil();
    }
  }

  void _verImagem(String? base64Str, String titulo) {
    if (base64Str == null) return;
    try {
      final bytes = base64Decode(base64Str.split(',').last);
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(titulo,
                        style: const TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  List<String> _parseEpis(String epis) {
    try {
      final List p = jsonDecode(epis);
      return p.cast<String>();
    } catch (_) { return [epis]; }
  }

  String _formatarData(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return '--'; }
  }
}

// ── Decoração de grade ─────────────────────────────────────────
class _GradeDecorativa extends StatelessWidget {
  final Color cor;
  const _GradeDecorativa({required this.cor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140, height: 100,
      child: CustomPaint(painter: _GradePainter(cor: cor)),
    );
  }
}

class _GradePainter extends CustomPainter {
  final Color cor;
  const _GradePainter({required this.cor});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = cor.withOpacity(0.07)..strokeWidth = 1;
    const s = 18.0;
    for (double x = 0; x < size.width; x += s)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p1);
    for (double y = 0; y < size.height; y += s)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p1);
    final p2 = Paint()..color = cor.withOpacity(0.18)..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += s)
      for (double y = 0; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.5, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}