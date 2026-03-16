import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/seguranca_controller.dart';
import 'confirmar_recebimento_screen.dart';

class SegurancaHomeScreen extends StatefulWidget {
  const SegurancaHomeScreen({super.key});

  @override
  State<SegurancaHomeScreen> createState() => _SegurancaHomeScreenState();
}

class _SegurancaHomeScreenState extends State<SegurancaHomeScreen> {
  final controller = Get.find<SegurancaController>();

  @override
  void initState() {
    super.initState();
    controller.carregarMinhasRequisicoes();
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

            // ── Banner de bloqueio (quando aguardando confirmação) ──
            Obx(() {
              if (!controller.hasRequisicaoAguardando) return const SizedBox.shrink();
              final req = controller.requisicaoAguardando!;
              final epis = req['epis_solicitados'];
              final List<String> episLista = epis is List ? epis.cast<String>() : [];
              return GestureDetector(
                onTap: () => Get.to(() => ConfirmarRecebimentoScreen(
                  requisicaoId: req['id'] as int,
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

            const Text('O que deseja fazer?',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),

            // Nova Requisição — bloqueada se tiver aguardando confirmação
            Obx(() => _buildCard(
              icon: Icons.add_circle_outline,
              title: 'Nova Requisição de EPI',
              subtitle: controller.hasRequisicaoAguardando
                  ? 'Confirme o recebimento pendente antes de solicitar novos EPIs'
                  : 'Solicite os equipamentos necessários\npara sua atividade',
              color: controller.hasRequisicaoAguardando
                  ? Colors.white38
                  : const Color(0xFF00FF88),
              locked: controller.hasRequisicaoAguardando,
              onTap: controller.hasRequisicaoAguardando
                  ? () {
                final req = controller.requisicaoAguardando!;
                final epis = req['epis_solicitados'];
                final List<String> episLista =
                epis is List ? epis.cast<String>() : [];
                Get.to(() => ConfirmarRecebimentoScreen(
                  requisicaoId: req['id'] as int,
                  epis: episLista,
                ));
              }
                  : () => Get.toNamed('/seguranca/requisicao'),
            )),
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