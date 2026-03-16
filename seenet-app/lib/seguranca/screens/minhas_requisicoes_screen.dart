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

class _MinhasRequisicoesScreenState extends State<MinhasRequisicoesScreen> {
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
        title: const Text('Minhas Requisições',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: controller.carregarMinhasRequisicoes,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        return Column(
          children: [
            // Banner de bloqueio quando aguardando confirmação
            if (controller.hasRequisicaoAguardando) _buildBannerBloqueio(),

            Expanded(
              child: controller.minhasRequisicoes.isEmpty
                  ? _buildVazio()
                  : RefreshIndicator(
                onRefresh: controller.carregarMinhasRequisicoes,
                color: const Color(0xFF00FF88),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.minhasRequisicoes.length,
                  itemBuilder: (context, i) =>
                      _buildCard(controller.minhasRequisicoes[i]),
                ),
              ),
            ),
          ],
        );
      }),
      floatingActionButton: Obx(() => FloatingActionButton.extended(
        // Bloqueado se tiver aguardando confirmação
        onPressed: controller.hasRequisicaoAguardando
            ? null
            : () => Get.toNamed('/seguranca/requisicao'),
        backgroundColor: controller.hasRequisicaoAguardando
            ? Colors.white24
            : const Color(0xFF00FF88),
        icon: Icon(
          controller.hasRequisicaoAguardando ? Icons.lock_outline : Icons.add,
          color: controller.hasRequisicaoAguardando ? Colors.white54 : Colors.black,
        ),
        label: Text(
          controller.hasRequisicaoAguardando
              ? 'Confirmação pendente'
              : 'Nova Requisição',
          style: TextStyle(
            color: controller.hasRequisicaoAguardando ? Colors.white54 : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
    );
  }

  Widget _buildBannerBloqueio() {
    final req = controller.requisicaoAguardando!;
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];

    return GestureDetector(
      onTap: () => Get.to(() => ConfirmarRecebimentoScreen(
        requisicaoId: req['id'] as int,
        epis: episLista,
      )),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00BFFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00BFFF).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app,
                color: Color(0xFF00BFFF), size: 22),
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
                  Text(
                    'Seus EPIs chegaram. Toque para tirar foto e assinar.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF00BFFF), size: 20),
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
    final color = controller.statusColor(status);
    final label = controller.statusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(_formatarData(req['data_criacao']),
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Requisição #${req['id']}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            '${episLista.length} EPI(s): ${episLista.take(2).join(' • ')}${episLista.length > 2 ? ' +${episLista.length - 2} mais' : ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (status == 'recusada' && req['observacao_gestor'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(req['observacao_gestor'],
                        style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],

          // PDF para concluídas
          if (status == 'concluida') ...[
            const SizedBox(height: 10),
            BotaoPDF(
              requisicaoId: req['id'] as int,
              pdfBase64Cached: req['pdf_base64'],
            ),
          ],

          // Botão de confirmação para aguardando
          if (status == 'aguardando_confirmacao') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Get.to(() => ConfirmarRecebimentoScreen(
                  requisicaoId: req['id'] as int,
                  epis: episLista,
                )),
                icon: const Icon(Icons.verified,
                    color: Colors.black, size: 16),
                label: const Text('Confirmar Recebimento',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_outlined,
              size: 70, color: Colors.white12),
          const SizedBox(height: 16),
          const Text('Nenhuma requisição ainda',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Faça sua primeira requisição de EPI',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/seguranca/requisicao'),
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('Nova Requisição',
                style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88)),
          ),
        ],
      ),
    );
  }

  String _formatarData(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return '--'; }
  }
}