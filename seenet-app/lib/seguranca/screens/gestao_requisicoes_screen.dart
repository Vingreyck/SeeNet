import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../controllers/seguranca_controller.dart';
import '../widgets/botao_pdf.dart'; // ← NOVO

class GestaoRequisicoesScreen extends StatefulWidget {
  const GestaoRequisicoesScreen({super.key});

  @override
  State<GestaoRequisicoesScreen> createState() =>
      _GestaoRequisicoesScreenState();
}

class _GestaoRequisicoesScreenState extends State<GestaoRequisicoesScreen>
    with SingleTickerProviderStateMixin {
  final controller = Get.find<SegurancaController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    controller.carregarPendentes();
    controller.carregarTodas();
    _tabController.addListener(() {
      if (_tabController.index == 1) controller.carregarTodas(status: 'aprovada');
      if (_tabController.index == 2) controller.carregarTodas(status: 'recusada');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Gestão de Requisições',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // ← NOVO: botões no topo
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Color(0xFF00FF88)),
            tooltip: 'Registro Manual',
            onPressed: () => Get.toNamed('/seguranca/registro-manual'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              controller.carregarPendentes();
              controller.carregarTodas();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF88),
          labelColor: const Color(0xFF00FF88),
          unselectedLabelColor: Colors.white38,
          tabs: [
            Obx(() => Tab(
                text: 'Pendentes (${controller.requisicoesPendentes.length})')),
            const Tab(text: 'Aprovadas'),
            const Tab(text: 'Recusadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListaPendentes(),
          _buildListaStatus('aprovada'),
          _buildListaStatus('recusada'),
        ],
      ),
    );
  }

  Widget _buildListaPendentes() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FF88)));
      }
      if (controller.requisicoesPendentes.isEmpty) {
        return _buildVazio('Nenhuma requisição pendente', Icons.check_circle_outline);
      }
      return RefreshIndicator(
        onRefresh: controller.carregarPendentes,
        color: const Color(0xFF00FF88),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.requisicoesPendentes.length,
          itemBuilder: (context, i) =>
              _buildCardPendente(controller.requisicoesPendentes[i]),
        ),
      );
    });
  }

  Widget _buildListaStatus(String status) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FF88)));
      }
      final lista = controller.todasRequisicoes
          .where((r) => r['status'] == status)
          .toList();
      if (lista.isEmpty) {
        return _buildVazio('Nenhuma requisição $status', Icons.inbox_outlined);
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (context, i) => _buildCardSimples(lista[i]),
      );
    });
  }

  Widget _buildCardPendente(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista =
    epis is List ? epis.cast<String>() : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.orange.withOpacity(0.15),
                  child: const Icon(Icons.person, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['tecnico_nome'] ?? 'Técnico',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Text(req['tecnico_email'] ?? '',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PENDENTE',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${episLista.length} EPI(s) solicitado(s):',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: episLista
                      .map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(e,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildBotaoVisualizar(
                  'Ver Foto',
                  Icons.photo,
                      () => _verImagem(req['foto_base64'], 'Foto de Confirmação'),
                ),
                const SizedBox(width: 8),
                _buildBotaoVisualizar(
                  'Ver Assinatura',
                  Icons.draw,
                      () => _verImagem(
                      req['assinatura_base64'], 'Assinatura Digital'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmarRecusa(req['id'] as int),
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text('Recusar',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => ElevatedButton.icon(
                    onPressed: controller.isSending.value
                        ? null
                        : () => _confirmarAprovacao(req['id'] as int),
                    icon: const Icon(Icons.check,
                        size: 16, color: Colors.black),
                    label: const Text('Aprovar',
                        style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoVisualizar(
      String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: Colors.white54),
        label: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ← ATUALIZADO: agora com botão PDF, tag de registro manual
  Widget _buildCardSimples(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pendente';
    final color = controller.statusColor(status);
    final epis = req['epis_solicitados'];
    final List<String> episLista =
    epis is List ? epis.cast<String>() : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(req['tecnico_nome'] ?? 'Técnico',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
              // ← NOVO: botão PDF
              if (status == 'aprovada')
                BotaoPDF(requisicaoId: req['id'] as int),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${episLista.length} EPI(s)  •  ${_formatarData(req['data_resposta'])}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (req['observacao_gestor'] != null) ...[
            const SizedBox(height: 6),
            Text(req['observacao_gestor'],
                style: TextStyle(color: color, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          // ← NOVO: tag de registro manual
          if (req['registro_manual'] == true) ...[
            const SizedBox(height: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Text('📋 Registro manual',
                  style: TextStyle(color: Colors.blue, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  void _verImagem(String? base64, String titulo) {
    if (base64 == null) return;
    try {
      final bytes = base64Decode(base64.split(',').last);
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  void _confirmarAprovacao(int id) {
    final obsController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aprovar Requisição',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Deseja aprovar esta requisição de EPI?',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Observação (opcional)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await controller.aprovar(id,
                  observacao: obsController.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? ''),
                  backgroundColor: result['success'] == true
                      ? const Color(0xFF00C853)
                      : Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88)),
            child: const Text('Aprovar',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _confirmarRecusa(int id) {
    final obsController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recusar Requisição',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe o motivo da recusa:',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: obsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Motivo da recusa *',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (obsController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o motivo da recusa'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              final result = await controller.recusar(id,
                  observacao: obsController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? ''),
                  backgroundColor: result['success'] == true
                      ? Colors.orange
                      : Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Recusar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white12),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(color: Colors.white38, fontSize: 15)),
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