// lib/seguranca/screens/perfil_screen.dart — REDESIGN v2 (calendar)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../controllers/seguranca_controller.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../controllers/usuario_controller.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen>
    with SingleTickerProviderStateMixin {
  int? _anoFiltro;
  int? _mesFiltro;
  int _abaAtual = 0; // mantido para compatibilidade

  final controller = Get.find<SegurancaController>();
  final usuario = Get.find<UsuarioController>();

  late AnimationController _fadeCtrl;

  // Calendário
  int _anoSel = DateTime.now().year;
  int _mesSel = DateTime.now().month;
  String? _diaSelecionado;
  List<Map<String, dynamic>> _episNoDia = [];

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    controller.carregarPerfil();
    controller.carregarMinhasRequisicoes();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _historicoRecebidos =>
      controller.minhasRequisicoes
          .where((r) => r['status'] == 'concluida')
          .toList();

  String _formatarData(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '--';
    }
  }

  String _dia(String? data) {
    if (data == null) return '--';
    try {
      return DateTime.parse(data).toLocal().day.toString().padLeft(2, '0');
    } catch (_) {
      return '--';
    }
  }

  String _mesAno(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      const meses = ['Jan','Fev','Mar','Abr','Mai','Jun',
        'Jul','Ago','Set','Out','Nov','Dez'];
      return '${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '--';
    }
  }

  Future<void> _gerarPDFFiltrado() async {
    final auth = Get.find<AuthService>();
    final tecnicoId = controller.perfilData.value?['id'];
    if (tecnicoId == null) return;
    final params = <String>[];
    if (_mesFiltro != null) params.add('mes=$_mesFiltro');
    if (_anoFiltro != null) params.add('ano=$_anoFiltro');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final url =
        'https://seenet-production.up.railway.app/api/seguranca/relatorio-epi/$tecnicoId$query';
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gerando PDF do período...'),
      backgroundColor: Color(0xFF00FF88),
    ));
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer ${auth.token}',
        'X-Tenant-Code': auth.tenantCode ?? '',
      });
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF gerado! Compartilhando...'),
          backgroundColor: Color(0xFF00FF88),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _alterarFoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 70, maxWidth: 400);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final ok = await controller.atualizarFoto(base64);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Foto atualizada!' : 'Erro ao atualizar foto'),
          backgroundColor: ok ? const Color(0xFF00C853) : Colors.red,
        ));
      }
    }
  }

  // ── Calendário helpers ───────────────────────────────────────

  /// Datas com EPI recebido no formato 'YYYY-MM-DD'
  Set<String> get _datasComEpi {
    final datas = <String>{};
    for (final r in _historicoRecebidos) {
      final raw = r['data_entrega'] ?? r['data_criacao'];
      if (raw == null) continue;
      try {
        final dt = DateTime.parse(raw).toLocal();
        datas.add(
          '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}',
        );
      } catch (_) {}
    }
    return datas;
  }

  Set<int> get _diasComEpiNoMes {
    final dias = <int>{};
    for (final key in _datasComEpi) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final ano = int.tryParse(parts[0]);
        final mes = int.tryParse(parts[1]);
        final dia = int.tryParse(parts[2]);
        if (ano == _anoSel && mes == _mesSel && dia != null) dias.add(dia);
      }
    }
    return dias;
  }

  void _selecionarDia(int dia) {
    final key =
        '$_anoSel-${_mesSel.toString().padLeft(2,'0')}-${dia.toString().padLeft(2,'0')}';
    final lista = _historicoRecebidos.where((r) {
      final raw = r['data_entrega'] ?? r['data_criacao'];
      if (raw == null) return false;
      try {
        final dt = DateTime.parse(raw).toLocal();
        final k =
            '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
        return k == key;
      } catch (_) {
        return false;
      }
    }).toList();
    setState(() { _diaSelecionado = key; _episNoDia = lista; });
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final corTipo = usuario.isAdmin
        ? const Color(0xFFFF9800)
        : usuario.isGestorSeguranca
        ? const Color(0xFF2196F3)
        : const Color(0xFF00FF88);

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Obx(() {
        final perfil = controller.perfilData.value;
        final stats  = controller.statsData.value;

        if (perfil == null) {
          return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF00FF88), strokeWidth: 2.5),
          );
        }

        final nome     = perfil['nome'] as String? ?? '';
        final fotoB64  = perfil['foto_perfil'] as String?;
        final tipo     = perfil['tipo_usuario'] as String? ?? 'tecnico';
        final iniciais = nome.trim().split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0])
            .take(2)
            .join()
            .toUpperCase();

        return CustomScrollView(
          slivers: [
            // ── SliverAppBar ────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: const Color(0xFF111111),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            corTipo.withOpacity(0.22),
                            corTipo.withOpacity(0.05),
                            const Color(0xFF111111),
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: FadeTransition(
                        opacity: _fadeCtrl,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            GestureDetector(
                              onTap: _alterarFoto,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 78, height: 78,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [
                                        corTipo.withOpacity(0.3),
                                        corTipo.withOpacity(0.1),
                                      ]),
                                      border: Border.all(
                                          color: corTipo.withOpacity(0.5),
                                          width: 2),
                                    ),
                                    child: fotoB64 != null
                                        ? ClipOval(
                                      child: Image.memory(
                                          base64Decode(fotoB64.split(',').last),
                                          fit: BoxFit.cover),
                                    )
                                        : Center(
                                      child: Text(iniciais,
                                          style: TextStyle(
                                              color: corTipo,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                        color: corTipo,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF111111),
                                            width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded,
                                          size: 12, color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(nome,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: corTipo.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: corTipo.withOpacity(0.3)),
                              ),
                              child: Text(
                                tipo == 'administrador'
                                    ? 'ADMINISTRADOR'
                                    : tipo == 'gestor_seguranca'
                                    ? 'GESTOR DE SEGURANÇA'
                                    : 'TÉCNICO',
                                style: TextStyle(
                                    color: corTipo,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Info ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildInfoCard(perfil),
              ),
            ),

            // ── Stats ────────────────────────────────────────
            if (stats != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _buildStatsCard(stats, corTipo),
                ),
              ),

            // ── Calendário de EPIs ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildHeaderCalendario(corTipo),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildSeletorMes(corTipo),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildCalendario(corTipo),
              ),
            ),

            // ── Detalhe do dia selecionado ────────────────────
            if (_diaSelecionado != null && _episNoDia.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildDetalhesDia(corTipo),
                ),
              ),

            const SliverToBoxAdapter(
                child: SizedBox(height: 32)),
          ],
        );
      }),
    );
  }

  // ── Info card ────────────────────────────────────────────────

  Widget _buildInfoCard(Map<String, dynamic> perfil) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _infoRow(Icons.email_outlined, 'E-mail', perfil['email'] ?? '--', isFirst: true),
          _divider(),
          _infoRow(Icons.business_outlined, 'Empresa', perfil['empresa'] ?? '--'),
          _divider(),
          _infoRow(Icons.calendar_today_outlined, 'Membro desde',
              _formatarData(perfil['data_criacao'])),
          if (perfil['ultimo_login'] != null) ...[
            _divider(),
            _infoRow(Icons.access_time_rounded, 'Último acesso',
                _formatarData(perfil['ultimo_login'])),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool isFirst = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      color: Colors.white.withOpacity(0.05),
      height: 1, indent: 44);

  // ── Stats card ───────────────────────────────────────────────

  Widget _buildStatsCard(Map<String, dynamic> stats, Color cor) {
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
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined,
                  color: Colors.white38, size: 15),
              const SizedBox(width: 6),
              const Text('Requisições de EPI',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statItem('${stats['total'] ?? 0}', 'Total', Colors.white54),
              _dividerStat(),
              _statItem('${stats['aprovadas'] ?? 0}', 'Concluídas',
                  const Color(0xFF00FF88)),
              _dividerStat(),
              _statItem('${stats['pendentes'] ?? 0}', 'Pendentes',
                  Colors.orange),
              _dividerStat(),
              _statItem('${stats['recusadas'] ?? 0}', 'Recusadas',
                  Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
    child: Column(
      children: [
        Text(v, style: TextStyle(color: c, fontSize: 22,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(color: Colors.white38,
            fontSize: 10)),
      ],
    ),
  );

  Widget _dividerStat() => Container(
      width: 1, height: 30,
      color: Colors.white.withOpacity(0.08));

  // ── Calendário ───────────────────────────────────────────────

  Widget _buildHeaderCalendario(Color cor) {
    final total = _historicoRecebidos.length;
    final noAno = _historicoRecebidos.where((r) {
      final raw = r['data_entrega'] ?? r['data_criacao'];
      if (raw == null) return false;
      try { return DateTime.parse(raw).toLocal().year == _anoSel; }
      catch (_) { return false; }
    }).length;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cor.withOpacity(0.2)),
          ),
          child: Icon(Icons.calendar_month_rounded, color: cor, size: 17),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Histórico de EPIs',
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Text('$noAno entrega(s) em $_anoSel • $total total',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const Spacer(),
        // Seletor de ano
        Row(
          children: List.generate(3, (i) {
            final ano = DateTime.now().year - i;
            final sel = _anoSel == ano;
            return GestureDetector(
              onTap: () => setState(() {
                _anoSel = ano;
                _diaSelecionado = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(left: 5),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? cor.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? cor : Colors.white12),
                ),
                child: Text('$ano',
                    style: TextStyle(
                        color: sel ? cor : Colors.white38,
                        fontSize: 11,
                        fontWeight: sel
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSeletorMes(Color cor) {
    const meses = ['','Jan','Fev','Mar','Abr','Mai','Jun',
      'Jul','Ago','Set','Out','Nov','Dez'];

    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 12,
        itemBuilder: (_, i) {
          final mes = i + 1;
          final sel = _mesSel == mes;
          final temEpi = _historicoRecebidos.any((r) {
            final raw = r['data_entrega'] ?? r['data_criacao'];
            if (raw == null) return false;
            try {
              final dt = DateTime.parse(raw).toLocal();
              return dt.year == _anoSel && dt.month == mes;
            } catch (_) { return false; }
          });

          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: GestureDetector(
              onTap: () => setState(() {
                _mesSel = mes;
                _diaSelecionado = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: sel
                      ? cor.withOpacity(0.14)
                      : const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: sel ? cor : Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(meses[mes],
                        style: TextStyle(
                            color: sel ? cor : Colors.white54,
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    if (temEpi) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                            color: cor, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendario(Color cor) {
    const diasSemana = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];
    final primeiroDia = DateTime(_anoSel, _mesSel, 1);
    final ultimoDia = DateTime(_anoSel, _mesSel + 1, 0);
    final diasComEpi = _diasComEpiNoMes;
    final offset = primeiroDia.weekday % 7;
    final hoje = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Cabeçalho dias da semana
          Row(
            children: diasSemana.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),

          // Grid de dias
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: offset + ultimoDia.day,
            itemBuilder: (_, i) {
              if (i < offset) return const SizedBox.shrink();
              final dia = i - offset + 1;
              final temEpi = diasComEpi.contains(dia);
              final key =
                  '$_anoSel-${_mesSel.toString().padLeft(2,'0')}-${dia.toString().padLeft(2,'0')}';
              final isSel = _diaSelecionado == key;
              final isHoje = dia == hoje.day &&
                  _mesSel == hoje.month &&
                  _anoSel == hoje.year;

              return GestureDetector(
                onTap: temEpi ? () => _selecionarDia(dia) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSel
                        ? cor
                        : temEpi
                        ? cor.withOpacity(0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isHoje && !temEpi
                        ? Border.all(color: Colors.white24)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$dia',
                          style: TextStyle(
                              color: isSel
                                  ? Colors.black
                                  : temEpi
                                  ? cor
                                  : Colors.white38,
                              fontSize: 13,
                              fontWeight: temEpi || isHoje
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      if (temEpi)
                        Container(
                          width: 4, height: 4,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.black54
                                : cor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: cor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 5),
              Text('EPI recebido',
                  style: TextStyle(color: Colors.white38,
                      fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetalhesDia(Color cor) {
    final partes = _diaSelecionado!.split('-');
    final dataStr = '${partes[2]}/${partes[1]}/${partes[0]}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_rounded, color: cor, size: 16),
              const SizedBox(width: 8),
              Text('EPIs em $dataStr',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ..._episNoDia.map((req) {
            final epis = req['epis_solicitados'];
            final List<String> episLista =
            epis is List ? epis.cast<String>() : [];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 5, runSpacing: 5,
                    children: episLista.map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cor.withOpacity(0.2)),
                      ),
                      child: Text(e,
                          style: TextStyle(color: cor, fontSize: 11)),
                    )).toList(),
                  ),
                  if (req['id_requisicao_ixc'] != null) ...[
                    const SizedBox(height: 6),
                    Text('IXC Req. #${req['id_requisicao_ixc']}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}