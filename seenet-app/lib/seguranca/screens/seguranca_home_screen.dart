// lib/seguranca/screens/seguranca_home_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;
import '../services/seguranca_service.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../controllers/seguranca_controller.dart';
import 'confirmar_recebimento_screen.dart';
import 'package:seenet/widgets/app_snackbar.dart';
import '../../controllers/usuario_controller.dart';

class SegurancaHomeScreen extends StatefulWidget {
  const SegurancaHomeScreen({super.key});

  @override
  State<SegurancaHomeScreen> createState() => _SegurancaHomeScreenState();
}

class _SegurancaHomeScreenState extends State<SegurancaHomeScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _minhasDevolucoes = [];
  final controller = Get.find<SegurancaController>();
  final usuario = Get.find<UsuarioController>();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    controller.carregarMinhasRequisicoes();
    _carregarDevolucoes();

    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  Future<void> _carregarDevolucoes() async {
    final service = Get.find<SegurancaService>();
    final result = await service.buscarMinhasDevolucoes();
    if (mounted) setState(() => _minhasDevolucoes = result);
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final corTipo = usuario.isAdmin
        ? const Color(0xFFFF9800)
        : usuario.isGestorSeguranca
        ? const Color(0xFF2196F3)
        : const Color(0xFF00FF88);

    final corFundo = usuario.isAdmin
        ? const Color(0xFF2A1A08)
        : usuario.isGestorSeguranca
        ? const Color(0xFF0A1A2A)
        : const Color(0xFF0D2B1F);
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
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
                  // Gradiente shield-themed
                  Container(
                    decoration: BoxDecoration(             // ← sem const
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [corFundo, const Color(0xFF111111)],
                        stops: const [0.0, 0.8],
                      ),
                    ),
                  ),
                  // Padrão hexagonal decorativo (direita)
                  Positioned(
                    top: 0, right: 0,
                    child: _HexDecoration(),
                  ),
                  // Conteúdo
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, child) => Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: corTipo.withOpacity(0.1 + _pulseAnim.value * 0.08),

                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: corTipo.withOpacity(0.3 + _pulseAnim.value * 0.2),
                                        width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                          color: corTipo.withOpacity(_pulseAnim.value * 0.15),
                                          blurRadius: 12,
                                          spreadRadius: 1)
                                    ],
                                  ),
                                  child: Icon(Icons.health_and_safety_rounded, color: corTipo, size: 26),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Segurança do Trabalho',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.3)),
                                  SizedBox(height: 3),
                                  Text('EPIs e Equipamentos de Proteção',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Banners de status ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // Banner confirmação aguardando
                  Obx(() {
                    final reqAguardando =
                        controller.requisicaoAguardando;
                    if (reqAguardando == null) return const SizedBox.shrink();
                    final epis = reqAguardando['epis_solicitados'];
                    final List<String> episLista =
                    epis is List ? epis.cast<String>() : [];
                    return GestureDetector(
                      onTap: () => Get.to(() => ConfirmarRecebimentoScreen(
                        requisicaoId: reqAguardando['id'] as int,
                        epis: episLista,
                      )),
                      child: _buildBanner(
                        icon: Icons.pending_actions_rounded,
                        titulo: 'Confirmação pendente!',
                        subtitulo:
                        'EPIs chegaram — toque para confirmar recebimento',
                        cor: const Color(0xFF00BFFF),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF00BFFF), size: 20),
                      ),
                    );
                  }),

                  // Banner pendente de aprovação
                  Obx(() {
                    final reqPendente = controller.requisicaoPendente;
                    if (reqPendente == null ||
                        controller.requisicaoAguardando != null)
                      return const SizedBox.shrink();
                    return _buildBanner(
                      icon: Icons.hourglass_top_rounded,
                      titulo: 'Requisição enviada!',
                      subtitulo:
                      'Aguardando aprovação do gestor',
                      cor: const Color(0xFFFFAA00),
                    );
                  }),

                  // Banner devoluções pendentes
                  if (_minhasDevolucoes
                      .any((d) => d['status'] == 'pendente'))
                    _buildBannerDevolucoes(
                      icon: Icons.assignment_return_rounded,
                      titulo: 'Devoluções aguardando aprovação',
                      itens: _minhasDevolucoes
                          .where((d) => d['status'] == 'pendente')
                          .map((d) => d['epi_nome'] as String? ?? '')
                          .toList(),
                      cor: Colors.orange,
                    ),

                  // Banner devedores
                  if (_minhasDevolucoes
                      .any((d) => d['status'] == 'recusada'))
                    _buildBannerDevolucoes(
                      icon: Icons.warning_amber_rounded,
                      titulo: 'EPIs pendentes de devolução',
                      itens: _minhasDevolucoes
                          .where((d) => d['status'] == 'recusada')
                          .map((d) =>
                      '${d['epi_nome']} — ${d['observacao_gestor'] ?? ''}')
                          .toList(),
                      cor: Colors.red,
                    ),
                ],
              ),
            ),
          ),

          // ── Seção de ações ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  const Text('O que deseja fazer?',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  Container(
                      width: 30, height: 1,
                      color: Colors.white.withOpacity(0.08)),
                ],
              ),
            ),
          ),

          // ── Cards de ação ───────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Nova Requisição
                Obx(() {
                  final bloqueado = controller.hasRequisicaoAguardando;
                  final temAguardando =
                      controller.requisicaoAguardando != null;
                  final subtitleBloqueado = temAguardando
                      ? 'Confirme o recebimento antes de solicitar novos EPIs'
                      : 'Aguarde a aprovação da requisição atual';

                  return _buildCard(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Nova Requisição de EPI',
                    subtitle: bloqueado
                        ? subtitleBloqueado
                        : 'Solicite equipamentos para sua atividade',
                    color: bloqueado
                        ? Colors.white24
                        : corTipo,
                    locked: bloqueado,
                    onTap: bloqueado
                        ? () {
                      if (temAguardando) {
                        final req = controller.requisicaoAguardando!;
                        final epis = req['epis_solicitados'];
                        final List<String> episLista = epis is List
                            ? epis.cast<String>()
                            : [];
                        Get.to(() => ConfirmarRecebimentoScreen(
                          requisicaoId: req['id'] as int,
                          epis: episLista,
                        ));
                      } else {
                        AppSnackbar.show(
                          'Requisição pendente',
                          'Aguarde a aprovação antes de fazer uma nova.',
                          backgroundColor: const Color(0xFFFFAA00),
                          colorText: Colors.black,
                          snackPosition: SnackPosition.TOP,
                          duration: const Duration(seconds: 3),
                        );
                      }
                    }
                        : () => Get.toNamed('/seguranca/requisicao'),
                  );
                }),

                const SizedBox(height: 10),

                _buildCard(
                  icon: Icons.list_alt_rounded,
                  title: 'Minhas Requisições',
                  subtitle: 'Acompanhe o status das suas solicitações',
                  color: const Color(0xFF00BCD4),
                  onTap: () => Get.toNamed('/seguranca/minhas'),
                ),

                const SizedBox(height: 10),

                _buildCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Meu Perfil',
                  subtitle: 'Histórico de EPIs recebidos e documentos',
                  color: Colors.purple,
                  onTap: () => Get.toNamed('/seguranca/perfil'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets redesenhados ─────────────────────────────────────

  Widget _buildBanner({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color cor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        color: cor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBannerDevolucoes({
    required IconData icon,
    required String titulo,
    required List<String> itens,
    required Color cor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cor, size: 18),
              const SizedBox(width: 8),
              Text(titulo,
                  style: TextStyle(
                      color: cor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ...itens.map((item) => Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: cor, shape: BoxShape.circle)),
                Expanded(
                    child: Text(item,
                        style: TextStyle(
                            color: cor.withOpacity(0.8),
                            fontSize: 12))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.06),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Faixa lateral colorida
              Container(
                width: 3,
                height: 48,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: locked ? Colors.white12 : color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  locked ? Icons.lock_outline_rounded : icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: locked ? Colors.white38 : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                locked
                    ? Icons.arrow_forward_rounded
                    : Icons.chevron_right_rounded,
                color: color.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Decoração hexagonal ──────────────────────────────────────────
class _HexDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 130, height: 110,
          child: CustomPaint(painter: _HexPainter()));
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    void hex(double cx, double cy, double r) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = (i * 60 - 30) * math.pi / 180;
        final x = cx + r * math.cos(angle);
        final y = cy + r * math.sin(angle);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, p);
    }

    hex(size.width * 0.8, size.height * 0.3, 28);
    hex(size.width * 0.5, size.height * 0.7, 20);
    hex(size.width * 0.95, size.height * 0.75, 16);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}