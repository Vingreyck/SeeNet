// lib/ordem_de_servico/screens/ordens_servico_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ordem_servico_controller.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/os_card_widget.dart';
import '../../controllers/usuario_controller.dart';
import 'package:seenet/widgets/skeleton_loader.dart';
import 'executar_os_wizard_screen.dart';

class OrdensServicoScreen extends StatefulWidget {
  const OrdensServicoScreen({super.key});

  @override
  State<OrdensServicoScreen> createState() => _OrdensServicoScreenState();
}

class _OrdensServicoScreenState extends State<OrdensServicoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrdemServicoController controller = Get.put(OrdemServicoController());

  final TextEditingController _buscaController = TextEditingController();
  final RxString _termoBusca = ''.obs;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _buscaController.addListener(() {
      _termoBusca.value = _buscaController.text;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_buscaController.text == _termoBusca.value) {
          controller.carregarOSsConcluidas(busca: _termoBusca.value);
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // Primeiro nome do usuário (pra saudação no header da home).
  String _primeiroNome() {
    final nome = Get.find<UsuarioController>().nomeUsuario.trim();
    return nome.isEmpty ? 'técnico' : nome.split(' ').first;
  }

  void _mostrarDetalhesOSConcluida(OrdemServico os) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 5),
                      Text('CONCLUÍDA',
                          style: TextStyle(color: Colors.green,
                              fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('OS #${os.numeroOs}',
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _detalheRow(Icons.person_outline_rounded, os.clienteNome),
            if (os.clienteEndereco != null && os.clienteEndereco!.isNotEmpty)
              _detalheRow(Icons.location_on_outlined, os.clienteEndereco!),
            if (os.dataFim != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF00FF88), size: 18),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Concluída em',
                            style: TextStyle(color: Colors.white38, fontSize: 11)),
                        Text(_formatarData(os.dataFim!),
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detalheRow(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(texto,
              style: const TextStyle(color: Colors.white70, fontSize: 14))),
        ],
      ),
    );
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';

  Widget _buildListaOS(List<OrdemServico> ordens, String status) {
    if (ordens.isEmpty) return _buildEmptyState(status);
    return RefreshIndicator(
      onRefresh: () => controller.carregarMinhasOSs(),
      color: const Color(0xFF00FF88),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: ordens.length,
        itemBuilder: (context, index) {
          final os = ordens[index];
          return OSCardWidget(
            os: os,
            onTap: () => Get.to(() => const ExecutarOSWizardScreen(), arguments: os),
          );
        },
      ),
    );
  }

  Widget _buildListaConcluidas() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: TextField(
              controller: _buscaController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar por nome do cliente...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.white38, size: 20),
                suffixIcon: Obx(() => _termoBusca.value.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white38, size: 18),
                  onPressed: () {
                    _buscaController.clear();
                    controller.carregarOSsConcluidas();
                  },
                )
                    : const SizedBox.shrink()),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.isLoadingConcluidas.value) {
              return const OSSkeleton(itemCount: 3);
            }
            final lista = controller.osConcluidas;
            if (lista.isEmpty) {
              if (_termoBusca.value.isNotEmpty) {
                return _buildEmptySearch(_termoBusca.value);
              }
              return _buildEmptyState('concluida');
            }
            return RefreshIndicator(
              onRefresh: () =>
                  controller.carregarOSsConcluidas(busca: _termoBusca.value),
              color: const Color(0xFF00FF88),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: lista.length,
                itemBuilder: (context, index) => OSCardWidget(
                  os: lista[index],
                  onTap: () => _mostrarDetalhesOSConcluida(lista[index]),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptySearch(String termo) {
    return _buildVazio(
      Icons.search_off_rounded,
      'Nenhum resultado',
      'Nenhuma OS encontrada para "$termo"',
    );
  }

  Widget _buildEmptyState(String status) {
    final configs = {
      'pendente': [Icons.check_circle_outline_rounded, 'Nenhuma OS pendente',
        'Você não tem ordens de serviço pendentes.'],
      'em_execucao': [Icons.build_circle_outlined, 'Nenhuma OS em execução',
        'Você não está executando nenhuma OS.'],
      'concluida': [Icons.history_rounded, 'Nenhuma OS concluída',
        'As OSs finalizadas por você aparecerão aqui.'],
    };
    final c = configs[status]!;
    return _buildVazio(c[0] as IconData, c[1] as String, c[2] as String);
  }

  Widget _buildErrorState(String erro) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56,
                color: Colors.red.withOpacity(0.6)),
            const SizedBox(height: 16),
            const Text('Erro ao carregar OSs',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(erro,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => controller.carregarMinhasOSs(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.black),
              label: const Text('Tentar novamente',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio(IconData icon, String titulo, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 14),
            Text(titulo,
                style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(msg,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
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
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF111111)],
              ),
            ),
            child: Row(
              children: [
                if (Navigator.canPop(context)) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Olá, ${_primeiroNome()} 👋',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      const Text('Ordens de Serviço',
                          style: TextStyle(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                    ],
                  ),
                ),
                if (Get.find<UsuarioController>().isAdmin)
                  IconButton(
                    icon: const Icon(Icons.gps_fixed,
                        color: Color(0xFF00FF88), size: 20),
                    tooltip: 'Acompanhar Técnicos',
                    onPressed: () =>
                        Get.toNamed('/ordens-servico/acompanhamento'),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white54, size: 20),
                  onPressed: () {
                    controller.carregarMinhasOSs();
                    controller.carregarOSsConcluidas();
                  },
                ),
              ],
            ),
          ),

          // ── Tab bar custom ─────────────────────────────────
          Obx(() {
            final p = controller.osPendentes.length;
            final e = controller.osEmExecucao.length;
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF00FF88),
                  borderRadius: BorderRadius.circular(11),
                ),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: p > 0 ? 'Pendentes ($p)' : 'Pendentes'),
                  Tab(text: e > 0 ? 'Em Campo ($e)' : 'Em Campo'),
                  const Tab(text: 'Concluídas'),
                ],
              ),
            );
          }),

          // ── Conteúdo ────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const OSSkeleton(itemCount: 3);
              }
              if (controller.erro.value.isNotEmpty) {
                return _buildErrorState(controller.erro.value);
              }
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildListaOS(controller.osPendentes, 'pendente'),
                  _buildListaOS(controller.osEmExecucao, 'em_execucao'),
                  _buildListaConcluidas(),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count',
                  style: const TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }
}

// OSSkeleton inalterado
class OSSkeleton extends StatelessWidget {
  final int itemCount;
  const OSSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SkeletonLoader(width: 50, height: 20,
                  borderRadius: BorderRadius.circular(8)),
              const Spacer(),
              SkeletonLoader(width: 80, height: 24,
                  borderRadius: BorderRadius.circular(12)),
            ]),
            const SizedBox(height: 12),
            SkeletonLoader(width: double.infinity, height: 20,
                borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 8),
            SkeletonLoader(width: 200, height: 16,
                borderRadius: BorderRadius.circular(8)),
          ],
        ),
      ),
    );
  }
}