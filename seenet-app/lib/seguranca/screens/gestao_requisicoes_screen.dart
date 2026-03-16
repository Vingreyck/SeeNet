import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../controllers/seguranca_controller.dart';
import '../widgets/botao_pdf.dart';

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
    _tabController = TabController(length: 4, vsync: this);
    controller.carregarPendentes();
    controller.carregarTodas();
    controller.carregarHistorico();
    _tabController.addListener(() {
      if (_tabController.index == 1) controller.carregarTodas(status: 'aguardando_confirmacao');
      if (_tabController.index == 2) controller.carregarTodas(status: 'recusada');
      if (_tabController.index == 3) controller.carregarHistorico();
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
              controller.carregarHistorico();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF88),
          labelColor: const Color(0xFF00FF88),
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabs: [
            Obx(() => Tab(
                text: 'Pendentes (${controller.requisicoesPendentes.length})')),
            const Tab(text: 'Aprovadas'),
            const Tab(text: 'Recusadas'),
            Obx(() => Tab(
                text: 'Histórico (${controller.historicoRequisicoes.length})')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListaPendentes(),
          _buildListaStatus('aguardando_confirmacao'),
          _buildListaStatus('recusada'),
          _buildHistorico(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ABA 1: PENDENTES
  // ══════════════════════════════════════════════════════════════
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

  Widget _buildCardPendente(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Cabeçalho — técnico
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
                      Text(_formatarData(req['data_criacao']),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // EPIs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${episLista.length} EPI(s) solicitado(s):',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
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

          // NOTA: Sem botões de Ver Foto / Ver Assinatura aqui.
          // A foto e assinatura são coletadas pelo técnico APÓS receber os EPIs.
          // Elas ficam disponíveis na aba Histórico.

          const SizedBox(height: 12),

          // Botões Aprovar / Recusar
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
                        : () => _confirmarAprovacao(req),
                    icon: const Icon(Icons.check, size: 16, color: Colors.black),
                    label: const Text('Aprovar',
                        style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  // ══════════════════════════════════════════════════════════════
  // ABA 2 e 3: APROVADAS / RECUSADAS
  // ══════════════════════════════════════════════════════════════
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
        return _buildVazio(
          status == 'aguardando_confirmacao'
              ? 'Nenhuma requisição aguardando confirmação'
              : 'Nenhuma requisição recusada',
          Icons.inbox_outlined,
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        itemBuilder: (context, i) => _buildCardSimples(lista[i]),
      );
    });
  }

  Widget _buildCardSimples(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pendente';
    final color = controller.statusColor(status);
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];

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
              if (status == 'aguardando_confirmacao')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Ag. Técnico',
                      style: TextStyle(
                          color: Color(0xFF00BFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${episLista.length} EPI(s)  •  ${_formatarData(req['data_resposta'])}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (req['observacao_gestor'] != null) ...[
            const SizedBox(height: 4),
            Text(req['observacao_gestor'],
                style: TextStyle(color: color, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (req['registro_manual'] == true) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('📋 Registro manual',
                  style: TextStyle(color: Colors.blue, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ABA 4: HISTÓRICO — requisições concluídas com foto e assinatura
  // ══════════════════════════════════════════════════════════════
  Widget _buildHistorico() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FF88)));
      }
      if (controller.historicoRequisicoes.isEmpty) {
        return _buildVazio(
            'Nenhuma requisição concluída ainda', Icons.history);
      }
      return RefreshIndicator(
        onRefresh: controller.carregarHistorico,
        color: const Color(0xFF00FF88),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.historicoRequisicoes.length,
          itemBuilder: (context, i) =>
              _buildCardHistorico(controller.historicoRequisicoes[i]),
        ),
      );
    });
  }

  Widget _buildCardHistorico(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];
    final temFoto = req['foto_recebimento_base64'] != null;
    final temAssinatura = req['assinatura_recebimento_base64'] != null;

    return GestureDetector(
      onTap: () => _mostrarDetalheHistorico(req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF00FF88).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar técnico
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                  const Color(0xFF00FF88).withOpacity(0.15),
                  child: req['tecnico_foto'] != null
                      ? ClipOval(
                    child: Image.memory(
                      base64Decode(
                          req['tecnico_foto'].split(',').last),
                      fit: BoxFit.cover,
                      width: 36,
                      height: 36,
                    ),
                  )
                      : const Icon(Icons.person,
                      color: Color(0xFF00FF88), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['tecnico_nome'] ?? 'Técnico',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      Text(
                        'Confirmado em: ${_formatarData(req['data_confirmacao_recebimento'])}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Ícones de evidência disponível
                Row(
                  children: [
                    if (temFoto)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.photo,
                            color: Color(0xFF00FF88), size: 16),
                      ),
                    if (temAssinatura)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.draw,
                            color: Color(0xFF00FF88), size: 16),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: Colors.white38, size: 18),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${episLista.length} EPI(s): ${episLista.take(2).join(', ')}${episLista.length > 2 ? ' +${episLista.length - 2}' : ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (req['id_requisicao_ixc'] != null) ...[
              const SizedBox(height: 4),
              Text(
                '📦 IXC Req. #${req['id_requisicao_ixc']} — estoque descontado',
                style: const TextStyle(
                    color: Color(0xFF00FF88), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarDetalheHistorico(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
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

            // Cabeçalho
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['tecnico_nome'] ?? 'Técnico',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text('Req. #${req['id']}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CONCLUÍDA',
                      style: TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Aprovado por: ${req['gestor_nome'] ?? '--'}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            Text('Confirmado em: ${_formatarData(req['data_confirmacao_recebimento'])}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),

            // EPIs
            const Text('EPIs Recebidos:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...episLista.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF00FF88), size: 16),
                  const SizedBox(width: 8),
                  Text(e,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            )),

            // IXC info
            if (req['id_requisicao_ixc'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00FF88).withOpacity(0.2)),
                ),
                child: Text(
                  '📦 Estoque descontado via IXC — Requisição #${req['id_requisicao_ixc']}',
                  style: const TextStyle(
                      color: Color(0xFF00FF88), fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),

            // Foto e Assinatura
            const Text('Evidências de Recebimento:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            Row(
              children: [
                if (req['foto_recebimento_base64'] != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _verImagem(
                          req['foto_recebimento_base64'], 'Foto de Recebimento'),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              base64Decode(req['foto_recebimento_base64']
                                  .split(',')
                                  .last),
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('📷 Foto de Recebimento',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                if (req['foto_recebimento_base64'] != null &&
                    req['assinatura_recebimento_base64'] != null)
                  const SizedBox(width: 12),
                if (req['assinatura_recebimento_base64'] != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _verImagem(
                          req['assinatura_recebimento_base64'],
                          'Assinatura Digital'),
                      child: Column(
                        children: [
                          Container(
                            height: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                base64Decode(
                                    req['assinatura_recebimento_base64']
                                        .split(',')
                                        .last),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('✍️ Assinatura Digital',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                if (req['foto_recebimento_base64'] == null &&
                    req['assinatura_recebimento_base64'] == null)
                  const Text('Sem evidências registradas.',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),

            const SizedBox(height: 16),
            if (req['pdf_base64'] != null)
              BotaoPDF(
                requisicaoId: req['id'] as int,
                pdfBase64Cached: req['pdf_base64'],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════════════════════
  void _confirmarAprovacao(Map<String, dynamic> req) {
    final obsController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aprovar Requisição',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Técnico: ${req['tecnico_nome']}',
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'O estoque será descontado automaticamente do almoxarifado do técnico no IXC.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
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
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await controller.aprovar(
                req['id'] as int,
                observacao: obsController.text,
              );
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
            child:
            const Text('Aprovar', style: TextStyle(color: Colors.black)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (obsController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Informe o motivo da recusa'),
                      backgroundColor: Colors.red),
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

  void _verImagem(String? base64, String titulo) {
    if (base64 == null) return;
    try {
      final bytes = base64Decode(base64.split(',').last);
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
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
    } catch (_) { return '--'; }
  }
}