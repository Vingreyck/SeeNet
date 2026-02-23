import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ordem_servico_controller.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/os_card_widget.dart';
import 'package:seenet/widgets/skeleton_loader.dart';
import 'executar_os_wizard_screen.dart';

class OrdensServicoScreen extends StatefulWidget {
  const OrdensServicoScreen({super.key});

  @override
  State<OrdensServicoScreen> createState() => _OrdensServicoScreenState();
}

class _OrdensServicoScreenState extends State<OrdensServicoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrdemServicoController controller = Get.put(OrdemServicoController());

  // ✅ Controller para busca nas concluídas
  final TextEditingController _buscaController = TextEditingController();
  final RxString _termoBusca = ''.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Listener para atualizar busca com debounce
    _buscaController.addListener(() {
      _termoBusca.value = _buscaController.text;
      // Debounce de 500ms para não fazer muitas requisições
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          // ✅ HEADER VERDE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 100,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 15,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.32, 1.0],
                  colors: [
                    Color.fromARGB(255, 0, 232, 124),
                    Color.fromARGB(255, 0, 176, 91),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ordens de Serviço',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                    onPressed: () {
                      controller.carregarMinhasOSs();
                      controller.carregarOSsConcluidas();
                    },
                  ),
                ],
              ),
            ),
          ),

          // ✅ TABS
          Positioned(
            top: MediaQuery.of(context).padding.top + 110,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF232323),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF00FF88),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Pendentes'),
                  Tab(text: 'Em Execução'),
                  Tab(text: 'Concluídas'),
                ],
              ),
            ),
          ),

          // ✅ CONTEÚDO DAS TABS
          Positioned(
            top: MediaQuery.of(context).padding.top + 170,
            left: 0,
            right: 0,
            bottom: 0,
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
                  _buildListaConcluidas(), // ✅ Lista com busca
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ✅ Lista de concluídas com campo de busca
  Widget _buildListaConcluidas() {
    return Column(
      children: [
        // Campo de busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _buscaController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por nome do cliente...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: Obx(() => _termoBusca.value.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38),
                onPressed: () {
                  _buscaController.clear();
                  controller.carregarOSsConcluidas();
                },
              )
                  : const SizedBox.shrink()
              ),
              filled: true,
              fillColor: const Color(0xFF232323),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00FF88)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        // Lista de concluídas
        Expanded(
          child: Obx(() {
            if (controller.isLoadingConcluidas.value) {
              return const OSSkeleton(itemCount: 3);
            }

            final lista = controller.osConcluidas;

            if (lista.isEmpty) {
              if (_termoBusca.value.isNotEmpty) {
                return _buildEmptySearchState(_termoBusca.value);
              }
              return _buildEmptyState('concluida');
            }

            return RefreshIndicator(
              onRefresh: () => controller.carregarOSsConcluidas(busca: _termoBusca.value),
              color: const Color(0xFF00FF88),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (context, index) {
                  final os = lista[index];
                  return OSCardWidget(
                    os: os,
                    onTap: () => _mostrarDetalhesOSConcluida(os),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  // ✅ Estado vazio para busca
  Widget _buildEmptySearchState(String termo) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.white24),
            const SizedBox(height: 20),
            const Text(
              'Nenhum resultado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma OS encontrada para "$termo"',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Mostrar detalhes da OS concluída
  void _mostrarDetalhesOSConcluida(OrdemServico os) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232323),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'CONCLUÍDA',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Número da OS
            Text(
              'OS #${os.numeroOs}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Cliente
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    os.clienteNome,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Endereço
            if (os.clienteEndereco != null && os.clienteEndereco!.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      os.clienteEndereco!,
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Data de conclusão
            if (os.dataFim != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF00FF88), size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Concluída em',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Text(
                          _formatarData(os.dataFim!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildListaOS(List<OrdemServico> ordens, String status) {
    if (ordens.isEmpty) {
      return _buildEmptyState(status);
    }

    return RefreshIndicator(
      onRefresh: () => controller.carregarMinhasOSs(),
      color: const Color(0xFF00FF88),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ordens.length,
        itemBuilder: (context, index) {
          final os = ordens[index];
          return OSCardWidget(
            os: os,
            onTap: () {
              // ✅ Abre wizard direto
              Get.to(() => const ExecutarOSWizardScreen(), arguments: os);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    String titulo = '';
    String mensagem = '';
    IconData icone = Icons.assignment;

    switch (status) {
      case 'pendente':
        titulo = 'Nenhuma OS pendente';
        mensagem = 'Você não tem ordens de serviço pendentes no momento.';
        icone = Icons.check_circle_outline;
        break;
      case 'em_execucao':
        titulo = 'Nenhuma OS em execução';
        mensagem = 'Você não está executando nenhuma OS no momento.';
        icone = Icons.build_circle_outlined;
        break;
      case 'concluida':
        titulo = 'Nenhuma OS concluída';
        mensagem = 'As OSs finalizadas por você aparecerão aqui.';
        icone = Icons.history;
        break;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 80, color: Colors.white24),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              mensagem,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String erro) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Erro ao carregar OSs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              erro,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => controller.carregarMinhasOSs(),
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text(
                'Tentar Novamente',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OSSkeleton extends StatelessWidget {
  final int itemCount;

  const OSSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonLoader(
                    width: 50,
                    height: 20,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const Spacer(),
                  SkeletonLoader(
                    width: 80,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SkeletonLoader(
                width: double.infinity,
                height: 20,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              SkeletonLoader(
                width: 200,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SkeletonLoader(
                    width: 100,
                    height: 16,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 20),
                  SkeletonLoader(
                    width: 120,
                    height: 16,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}