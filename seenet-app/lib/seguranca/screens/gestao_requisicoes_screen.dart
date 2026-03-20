import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';
import 'perfil_tecnico_gestor_screen.dart';
import '../widgets/aba_produtos_epi.dart';
import '../widgets/dialog_aprovacao_epi.dart';
import '../controllers/seguranca_controller.dart';

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
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              controller.carregarPendentes();
              setState(() {}); // refresh técnicos
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
            const Tab(text: 'Técnicos'),
            const Tab(text: 'Produtos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListaPendentes(),
          _buildListaTecnicos(),
          const AbaProdutosEpi(),
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
  // ABA 2: TÉCNICOS
  // ══════════════════════════════════════════════════════════════
  Widget _buildListaTecnicos() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Get.find<SegurancaService>().buscarTecnicos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final tecnicos = snapshot.data ?? [];

        if (tecnicos.isEmpty) {
          return _buildVazio('Nenhum técnico cadastrado', Icons.people_outline);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tecnicos.length,
          itemBuilder: (context, index) {
            final tec = tecnicos[index];
            return _buildCardTecnico(tec);
          },
        );
      },
    );
  }

  Widget _buildCardTecnico(Map<String, dynamic> tec) {
    final tipo = tec['tipo_usuario'] as String? ?? 'tecnico';
    Color tipoColor;
    String tipoLabel;
    switch (tipo) {
      case 'administrador':
        tipoColor = Colors.orange;
        tipoLabel = 'Admin';
        break;
      case 'gestor_seguranca':
        tipoColor = Colors.blue;
        tipoLabel = 'Gestor';
        break;
      default:
        tipoColor = const Color(0xFF00FF88);
        tipoLabel = 'Técnico';
    }

    return InkWell(
      onTap: () => Get.to(() => PerfilTecnicoGestorScreen(
        tecnicoId: tec['id'] as int,
        tecnicoNome: tec['nome'] as String,
      )),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tipoColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: tipoColor.withOpacity(0.15),
              child: Icon(Icons.person, color: tipoColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tec['nome'] as String? ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(tec['email'] as String? ?? '',
                      style:
                      const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tipoColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tipoLabel,
                  style: TextStyle(
                      color: tipoColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: tipoColor, size: 20),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════════════════════
  void _confirmarAprovacao(Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DialogAprovacaoEpi(requisicao: req),
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

  // ══════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════
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