import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/botao_pdf.dart';
import '../controllers/seguranca_controller.dart';

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
        if (controller.minhasRequisicoes.isEmpty) {
          return _buildVazio();
        }
        return RefreshIndicator(
          onRefresh: controller.carregarMinhasRequisicoes,
          color: const Color(0xFF00FF88),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.minhasRequisicoes.length,
            itemBuilder: (context, i) =>
                _buildCard(controller.minhasRequisicoes[i]),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/seguranca/requisicao'),
        backgroundColor: const Color(0xFF00FF88),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nova Requisição',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pendente';
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List
        ? epis.cast<String>()
        : (epis is String ? List<String>.from([]..add(epis)) : []);

    final color = controller.statusColor(status);
    final label = controller.statusLabel(status);
    final data = _formatarData(req['data_criacao']);

    return GestureDetector(
      onTap: () => _mostrarDetalhe(req),
      child: Container(
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                Text(data,
                    style:
                    const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text('Requisição #${req['id']}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${episLista.length} EPI(s) solicitado(s)',
                style:
                const TextStyle(color: Colors.white54, fontSize: 13)),
            if (episLista.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                episLista.take(2).join(' • ') +
                    (episLista.length > 2
                        ? ' +${episLista.length - 2} mais'
                        : ''),
                style:
                const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
                    const Icon(Icons.info_outline,
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
            if (status == 'aprovada') ...[
              const SizedBox(height: 10),
              BotaoPDF(
                requisicaoId: req['id'] as int,
                pdfBase64Cached: req['pdf_base64'],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarDetalhe(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pendente';
    final color = controller.statusColor(status);
    final epis = req['epis_solicitados'];
    final List<String> episLista =
    epis is List ? epis.cast<String>() : [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Requisição #${req['id']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(controller.statusLabel(status),
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Enviada em: ${_formatarData(req['data_criacao'])}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            if (req['data_resposta'] != null)
              Text('Respondida em: ${_formatarData(req['data_resposta'])}',
                  style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
            if (req['gestor_nome'] != null)
              Text('Avaliado por: ${req['gestor_nome']}',
                  style:
                  const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('EPIs Solicitados:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...episLista.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.safety_check,
                      color: Color(0xFF00FF88), size: 16),
                  const SizedBox(width: 8),
                  Text(e,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            )),
            if (req['observacao_gestor'] != null) ...[
              const SizedBox(height: 16),
              Text(
                  status == 'recusada'
                      ? 'Motivo da Recusa:'
                      : 'Observação:',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(req['observacao_gestor'],
                    style:
                    TextStyle(color: color, fontSize: 13)),
              ),
            ],
          ],
        ),
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
    } catch (_) {
      return '--';
    }
  }
}