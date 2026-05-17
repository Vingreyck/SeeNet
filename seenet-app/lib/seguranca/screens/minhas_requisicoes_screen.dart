// lib/seguranca/screens/minhas_requisicoes_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../controllers/seguranca_controller.dart';
import '../widgets/botao_pdf.dart';
import 'confirmar_recebimento_screen.dart';

class MinhasRequisicoesScreen extends StatefulWidget {
  const MinhasRequisicoesScreen({super.key});

  @override
  State<MinhasRequisicoesScreen> createState() =>
      _MinhasRequisicoesScreenState();
}

class _MinhasRequisicoesScreenState extends State<MinhasRequisicoesScreen>
    with SingleTickerProviderStateMixin {
  final controller = Get.find<SegurancaController>();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    controller.carregarMinhasRequisicoes();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Color _corStatus(String status) => controller.statusColor(status);
  String _labelStatus(String status) => controller.statusLabel(status);

  String _formatarData(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '--';
    }
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16,
              left: 8,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2A), Color(0xFF111111)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minhas Requisições',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      Text('Histórico de EPIs',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white38, size: 20),
                  onPressed: controller.carregarMinhasRequisicoes,
                ),
              ],
            ),
          ),

          // ── Corpo ────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00FF88), strokeWidth: 2.5),
                );
              }

              return Column(
                children: [
                  // Banner bloqueio
                  if (controller.hasRequisicaoAguardando)
                    _buildBannerBloqueio(),

                  Expanded(
                    child: controller.minhasRequisicoes.isEmpty
                        ? _buildVazio()
                        : RefreshIndicator(
                      onRefresh: controller.carregarMinhasRequisicoes,
                      color: const Color(0xFF00FF88),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: controller.minhasRequisicoes.length,
                        itemBuilder: (context, i) {
                          final req = controller.minhasRequisicoes[i];
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(
                                milliseconds: 250 + i * 40),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, child) => Opacity(
                              opacity: v,
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - v)),
                                child: child,
                              ),
                            ),
                            child: _buildCard(req),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),

      // ── FAB Nova Requisição ─────────────────────────────────
      floatingActionButton: Obx(() => FloatingActionButton.extended(
        onPressed: controller.hasRequisicaoAguardando
            ? null
            : () => Get.toNamed('/seguranca/requisicao'),
        backgroundColor: controller.hasRequisicaoAguardando
            ? const Color(0xFF2A2A2A)
            : const Color(0xFF00FF88),
        icon: Icon(
          controller.hasRequisicaoAguardando
              ? Icons.lock_outline_rounded
              : Icons.add_rounded,
          color: controller.hasRequisicaoAguardando
              ? Colors.white38
              : Colors.black,
        ),
        label: Text(
          controller.hasRequisicaoAguardando
              ? 'Confirmação pendente'
              : 'Nova Requisição',
          style: TextStyle(
            color: controller.hasRequisicaoAguardando
                ? Colors.white38
                : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
    );
  }

  Widget _buildBannerBloqueio() {
    final req = controller.requisicaoAguardando!;
    final epis = req['epis_solicitados'];
    final List<String> episLista =
    epis is List ? epis.cast<String>() : [];

    return GestureDetector(
      onTap: () => Get.to(() => ConfirmarRecebimentoScreen(
        requisicaoId: req['id'] as int,
        epis: episLista,
      )),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00BFFF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF00BFFF).withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.touch_app_rounded,
                  color: Color(0xFF00BFFF), size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirmação de recebimento pendente!',
                      style: TextStyle(
                          color: Color(0xFF00BFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Seus EPIs chegaram — toque para confirmar.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF00BFFF), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pendente';
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List
        ? epis.cast<String>()
        : (epis is String ? [epis] : []);
    final cor = _corStatus(status);
    final label = _labelStatus(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header do card ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.06),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: cor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text('Req. #${req['id']}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 8),
                Text(_formatarData(req['data_criacao']),
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),

          // ── Corpo do card ────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // EPIs
                Wrap(
                  spacing: 5, runSpacing: 5,
                  children: episLista.take(4).map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(e,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  )).toList(),
                ),
                if (episLista.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('+${episLista.length - 4} mais',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 10)),
                  ),

                // Motivo recusa
                if (status == 'recusada' &&
                    req['observacao_gestor'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(req['observacao_gestor'],
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],

                // PDF
                if (status == 'concluida') ...[
                  const SizedBox(height: 10),
                  BotaoPDF(
                    requisicaoId: req['id'] as int,
                    pdfBase64Cached: req['pdf_base64'],
                  ),
                ],

                // Botão confirmar
                if (status == 'aguardando_confirmacao') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Get.to(() =>
                          ConfirmarRecebimentoScreen(
                            requisicaoId: req['id'] as int,
                            epis: episLista,
                          )),
                      icon: const Icon(Icons.verified_rounded,
                          color: Colors.black, size: 16),
                      label: const Text('Confirmar Recebimento',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
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

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined,
              size: 56,
              color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 14),
          const Text('Nenhuma requisição ainda',
              style: TextStyle(
                  color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Faça sua primeira requisição de EPI',
              style: TextStyle(
                  color: Colors.white24, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/seguranca/requisicao'),
            icon: const Icon(Icons.add_rounded, color: Colors.black),
            label: const Text('Nova Requisição',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
          ),
        ],
      ),
    );
  }
}