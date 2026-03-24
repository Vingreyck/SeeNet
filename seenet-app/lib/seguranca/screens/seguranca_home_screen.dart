import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../controllers/seguranca_controller.dart';
import 'confirmar_recebimento_screen.dart';

class SegurancaHomeScreen extends StatefulWidget {
  const SegurancaHomeScreen({super.key});

  @override
  State<SegurancaHomeScreen> createState() => _SegurancaHomeScreenState();
}

class _SegurancaHomeScreenState extends State<SegurancaHomeScreen> {
  List<Map<String, dynamic>> _minhasDevolucoes = [];
  final controller = Get.find<SegurancaController>();

  @override
  void initState() {
    super.initState();
    controller.carregarMinhasRequisicoes();
    _carregarDevolucoes();
  }

  Future<void> _carregarDevolucoes() async {
    final service = Get.find<SegurancaService>();
    final result = await service.buscarMinhasDevolucoes();
    if (mounted) setState(() => _minhasDevolucoes = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Segurança do Trabalho',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A2F), Color(0xFF0D2B1F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.health_and_safety,
                        color: Color(0xFF00FF88), size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EPIs e Segurança',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Gerencie suas requisições\nde equipamentos de proteção',
                            style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Banner de confirmação pendente (aguardando_confirmacao) ──
            Obx(() {
              final reqAguardando = controller.requisicaoAguardando;
              if (reqAguardando == null) return const SizedBox.shrink();
              final epis = reqAguardando['epis_solicitados'];
              final List<String> episLista = epis is List ? epis.cast<String>() : [];
              return GestureDetector(
                onTap: () => Get.to(() => ConfirmarRecebimentoScreen(
                  requisicaoId: reqAguardando['id'] as int,
                  epis: episLista,
                )),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00BFFF).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions,
                          color: Color(0xFF00BFFF), size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Confirmação pendente!',
                                style: TextStyle(
                                    color: Color(0xFF00BFFF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Você tem EPIs aguardando confirmação de recebimento. Toque para confirmar.',
                                style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFF00BFFF), size: 20),
                    ],
                  ),
                ),
              );
            }),

            // ✅ NOVO: Banner de requisição pendente de aprovação (status pendente)
            Obx(() {
              final reqPendente = controller.requisicaoPendente;
              // Só mostra se NÃO tem aguardando_confirmacao (pra não duplicar banners)
              if (reqPendente == null || controller.requisicaoAguardando != null) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFAA00).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFAA00).withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top,
                        color: Color(0xFFFFAA00), size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Requisição enviada!',
                              style: TextStyle(
                                  color: Color(0xFFFFAA00),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Sua requisição está aguardando aprovação do gestor. Você será notificado quando for aprovada.',
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Banner de devoluções pendentes ──
            if (_minhasDevolucoes.any((d) => d['status'] == 'pendente'))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_return, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text('Devoluções aguardando aprovação',
                            style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._minhasDevolucoes
                        .where((d) => d['status'] == 'pendente')
                        .map((d) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${d['epi_nome']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    )),
                  ],
                ),
              ),

            // ── Banner de devoluções recusadas (DEVEDOR) ──
            if (_minhasDevolucoes.any((d) => d['status'] == 'recusada'))
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('EPIs pendentes de devolução',
                            style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('O gestor não confirmou a devolução destes itens:',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 6),
                    ..._minhasDevolucoes
                        .where((d) => d['status'] == 'recusada')
                        .map((d) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${d['epi_nome']} — ${d['observacao_gestor'] ?? ''}',
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    )),
                  ],
                ),
              ),

            Builder(builder: (_) {
              return const SizedBox.shrink();
            }),

            const Text('O que deseja fazer?',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),

            // Nova Requisição — bloqueada se tiver pendente OU aguardando confirmação
            Obx(() {
              final bloqueado = controller.hasRequisicaoAguardando;
              final temAguardando = controller.requisicaoAguardando != null;

              String subtitleBloqueado;
              if (temAguardando) {
                subtitleBloqueado = 'Confirme o recebimento pendente antes de solicitar novos EPIs';
              } else {
                subtitleBloqueado = 'Aguarde a aprovação da sua requisição atual';
              }

              return _buildCard(
                icon: Icons.add_circle_outline,
                title: 'Nova Requisição de EPI',
                subtitle: bloqueado
                    ? subtitleBloqueado
                    : 'Solicite os equipamentos necessários\npara sua atividade',
                color: bloqueado
                    ? Colors.white38
                    : const Color(0xFF00FF88),
                locked: bloqueado,
                onTap: bloqueado
                    ? () {
                  if (temAguardando) {
                    final req = controller.requisicaoAguardando!;
                    final epis = req['epis_solicitados'];
                    final List<String> episLista =
                    epis is List ? epis.cast<String>() : [];
                    Get.to(() => ConfirmarRecebimentoScreen(
                      requisicaoId: req['id'] as int,
                      epis: episLista,
                    ));
                  } else {
                    Get.snackbar(
                      'Requisição pendente',
                      'Aguarde a aprovação da sua requisição atual antes de fazer uma nova.',
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
            const SizedBox(height: 12),

            _buildCard(
              icon: Icons.list_alt,
              title: 'Minhas Requisições',
              subtitle: 'Acompanhe o status das suas\nsolicitações de EPI',
              color: Colors.blue,
              onTap: () => Get.toNamed('/seguranca/minhas'),
            ),
            const SizedBox(height: 12),

            _buildCard(
              icon: Icons.person_outline,
              title: 'Meu Perfil',
              subtitle: 'Visualize suas informações\ne histórico de EPIs recebidos',
              color: Colors.purple,
              onTap: () => Get.toNamed('/seguranca/perfil'),
            ),
          ],
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                locked ? Icons.lock_outline : icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: locked ? Colors.white54 : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              locked ? Icons.arrow_forward : Icons.chevron_right,
              color: color,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}