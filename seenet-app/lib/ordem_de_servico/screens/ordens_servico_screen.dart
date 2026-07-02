// lib/ordem_de_servico/screens/ordens_servico_screen.dart — HOME (REDESIGN)
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

  // Aba/seção ativa (0=Pendentes, 1=Em campo, 2=Concluídas).
  // Usada pra destacar o card de resumo correspondente.
  final RxInt _tabAtual = 0.obs;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Mantém os cards de resumo em sincronia quando o usuário desliza as listas.
    _tabController.addListener(() {
      if (_tabAtual.value != _tabController.index) {
        _tabAtual.value = _tabController.index;
      }
    });
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

  // Iniciais do nome (1-2 letras) pro círculo de perfil.
  // Mesmo padrão do perfil_screen.dart.
  String _iniciais() {
    final nome = Get.find<UsuarioController>().nomeUsuario.trim();
    if (nome.isEmpty) return '?';
    return nome
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  // Data de hoje em português, ex.: "Quarta, 2 de jul".
  String _dataHoje() {
    final now = DateTime.now();
    const dias = [
      'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
    ];
    const meses = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    return '${dias[now.weekday - 1]}, ${now.day} de ${meses[now.month - 1]}';
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

  // ── HEADER (saudação + resumo do dia) ────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          _buildHeaderBar(context),
          _buildResumoCards(),

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

  // Barra do topo no PADRÃO das outras telas (gradiente + título à esquerda),
  // com o círculo de perfil (cor por cargo) à direita. Sem logo, sem "voltar".
  Widget _buildHeaderBar(BuildContext context) {
    final usuario = Get.find<UsuarioController>();
    // Fundo do topo na cor do cargo (MESMO padrão da tela de EPI):
    // admin=marrom, gestor=azul, técnico=verde — sempre escurecendo pro #111.
    final corFundo = usuario.isAdmin
        ? const Color(0xFF2A1A08)
        : usuario.isGestorSeguranca
            ? const Color(0xFF0A1A2A)
            : const Color(0xFF0D2B1F);
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [corFundo, const Color(0xFF111111)],
          stops: const [0.0, 0.8],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dataHoje(),
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Olá, ${_primeiroNome()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _profileCircle(usuario),
        ],
      ),
    );
  }

  // Círculo de perfil: inicial + borda na cor do cargo
  // (admin=laranja, gestor=azul, técnico=verde). Toca → abre o Perfil.
  Widget _profileCircle(UsuarioController usuario) {
    final cor = usuario.isAdmin
        ? const Color(0xFFFF9800)
        : usuario.isGestorSeguranca
            ? const Color(0xFF2196F3)
            : const Color(0xFF00FF88);
    return GestureDetector(
      onTap: () => Get.toNamed('/seguranca/perfil'),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cor.withOpacity(0.15),
          border: Border.all(color: cor, width: 2),
        ),
        child: Text(
          _iniciais(),
          style: TextStyle(
              color: cor, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Cards de resumo (dashboard) logo abaixo do topo. Tocar filtra a lista.
  Widget _buildResumoCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Obx(() {
        final p = controller.osPendentes.length;
        final e = controller.osEmExecucao.length;
        final c = controller.osConcluidas.length;
        final ativa = _tabAtual.value;
        return Row(
          children: [
            _statCard(0, 'Pendentes', p, Icons.pending_actions_rounded,
                const Color(0xFFFFB020), ativa == 0),
            const SizedBox(width: 10),
            _statCard(1, 'Em campo', e, Icons.engineering_rounded,
                const Color(0xFF3B9EFF), ativa == 1),
            const SizedBox(width: 10),
            _statCard(2, 'Concluídas', c, Icons.check_circle_rounded,
                const Color(0xFF00FF88), ativa == 2),
          ],
        );
      }),
    );
  }

  // Botão de ação do header (fundo translúcido pra combinar com o gradiente).
  Widget _headerAction(
      IconData icon, Color cor, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, color: cor, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  // Card de resumo: mostra a contagem e, ao tocar, troca a lista exibida.
  Widget _statCard(int index, String label, int count, IconData icon,
      Color cor, bool ativa) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: ativa ? cor.withOpacity(0.16) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ativa ? cor.withOpacity(0.65) : Colors.white.withOpacity(0.06),
              width: 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: cor, size: 20),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
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
