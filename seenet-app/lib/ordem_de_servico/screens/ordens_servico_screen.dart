import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ordem_servico_controller.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/os_card_widget.dart';
import 'package:seenet/widgets/skeleton_loader.dart';

class OrdensServicoScreen extends StatefulWidget {
  const OrdensServicoScreen({super.key});

  @override
  State<OrdensServicoScreen> createState() => _OrdensServicoScreenState();
}

class _OrdensServicoScreenState extends State<OrdensServicoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrdemServicoController controller = Get.put(OrdemServicoController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                        onPressed: () => Get.back(),
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
                    onPressed: () => controller.carregarMinhasOSs(),
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
                  _buildListaOS(controller.osConcluidas, 'concluida'),
                ],
              );
            }),
          ),
        ],
      ),
    );
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
              Get.toNamed('/ordens-servico/executar', arguments: os);
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
        mensagem = 'Você ainda não concluiu nenhuma OS.';
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
                    borderRadius: BorderRadius.circular(8), // ✅ CORRIGIDO
                  ),
                  const Spacer(),
                  SkeletonLoader(
                    width: 80, 
                    height: 24, 
                    borderRadius: BorderRadius.circular(12), // ✅ CORRIGIDO
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SkeletonLoader(
                width: double.infinity, 
                height: 20, 
                borderRadius: BorderRadius.circular(8), // ✅ CORRIGIDO
              ),
              const SizedBox(height: 8),
              SkeletonLoader(
                width: 200, 
                height: 16, 
                borderRadius: BorderRadius.circular(8), // ✅ CORRIGIDO
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SkeletonLoader(
                    width: 100, 
                    height: 16, 
                    borderRadius: BorderRadius.circular(8), // ✅ CORRIGIDO
                  ),
                  const SizedBox(width: 20),
                  SkeletonLoader(
                    width: 120, 
                    height: 16, 
                    borderRadius: BorderRadius.circular(8), // ✅ CORRIGIDO
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