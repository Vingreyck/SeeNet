// lib/admin/dashboard_admin.view.dart — REDESIGN
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class DashboardAdminView extends StatefulWidget {
  const DashboardAdminView({super.key});

  @override
  State<DashboardAdminView> createState() => _DashboardAdminViewState();
}

class _DashboardAdminViewState extends State<DashboardAdminView>
    with SingleTickerProviderStateMixin {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  bool isLoading = true;
  Map<String, dynamic>? dados;

  late AnimationController _fadeCtrl;

  Map<String, String> get _headers {
    final auth = Get.find<AuthService>();
    return {
      'Authorization': 'Bearer ${auth.token}',
      'X-Tenant-Code': auth.tenantCode ?? '',
    };
  }

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _carregar();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      setState(() => isLoading = true);
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/dashboard'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (mounted) {
          setState(() => dados = body['data']);
          _fadeCtrl.forward(from: 0);
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
              bottom: 16, left: 8, right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2A), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: Color(0xFF00FF88), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dashboard',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      if (dados?['mes_referencia'] != null)
                        Text(dados!['mes_referencia'],
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white38, size: 20),
                  onPressed: _carregar,
                ),
              ],
            ),
          ),

          // ── Corpo ────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00FF88), strokeWidth: 2.5))
                : dados == null
                ? _buildVazio()
                : FadeTransition(
              opacity: _fadeCtrl,
              child: RefreshIndicator(
                onRefresh: _carregar,
                color: const Color(0xFF00FF88),
                child: SingleChildScrollView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      _buildMetricasResumo(),
                      const SizedBox(height: 16),
                      _buildStatusCards(),
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                          'OSs por Técnico',
                          Icons.people_outline_rounded),
                      const SizedBox(height: 10),
                      _buildTecnicosTable(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 56,
              color: Colors.white12),
          SizedBox(height: 12),
          Text('Sem dados disponíveis',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String titulo, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMetricasResumo() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            '${dados!['tempo_medio_horas'] ?? '0'}h',
            'Tempo médio',
            Icons.timer_outlined,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            '${dados!['taxa_conclusao_prazo'] ?? 0}%',
            'No prazo',
            Icons.check_circle_outline_rounded,
            const Color(0xFF00FF88),
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
      String valor, String label, IconData icon, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor,
                  style: TextStyle(
                      color: cor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    final porStatus =
        dados!['por_status'] as List<dynamic>? ?? [];
    final statusConfig = {
      'pendente': {
        'label': 'Pendentes',
        'cor': Colors.orange,
        'icon': Icons.schedule_rounded
      },
      'em_deslocamento': {
        'label': 'Deslocando',
        'cor': Colors.blue,
        'icon': Icons.directions_car_rounded
      },
      'em_execucao': {
        'label': 'Em Execução',
        'cor': const Color(0xFF00FF88),
        'icon': Icons.build_rounded
      },
      'concluida': {
        'label': 'Concluídas',
        'cor': Colors.green,
        'icon': Icons.check_circle_rounded
      },
      'cancelada': {
        'label': 'Canceladas',
        'cor': Colors.red,
        'icon': Icons.cancel_rounded
      },
    };

    final Map<String, int> totais = {};
    for (final item in porStatus) {
      totais[item['status'] as String] =
          int.tryParse(item['total'].toString()) ?? 0;
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: statusConfig.entries.map((entry) {
        final cfg = entry.value;
        final total = totais[entry.key] ?? 0;
        final cor = cfg['cor'] as Color;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cor.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cfg['icon'] as IconData, color: cor, size: 20),
              const SizedBox(height: 6),
              Text('$total',
                  style: TextStyle(
                      color: cor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(cfg['label'] as String,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 9),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTecnicosTable() {
    final porTecnico =
        dados!['por_tecnico'] as List<dynamic>? ?? [];
    final Map<String, Map<String, int>> agrupado = {};
    for (final item in porTecnico) {
      final nome   = item['tecnico'] as String;
      final status = item['status'] as String;
      final total  = int.tryParse(item['total'].toString()) ?? 0;
      agrupado.putIfAbsent(nome, () => {});
      agrupado[nome]![status] = total;
    }

    if (agrupado.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('Nenhum dado disponível',
              style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: agrupado.entries.map((entry) {
          final nome       = entry.key;
          final statusMap  = entry.value;
          final total      = statusMap.values.fold(0, (a, b) => a + b);
          final concluidas = statusMap['concluida'] ?? 0;
          final pendentes  = statusMap['pendente'] ?? 0;
          final emExecucao = statusMap['em_execucao'] ?? 0;
          final iniciais   = nome.trim().split(' ')
              .where((p) => p.isNotEmpty)
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase();

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00FF88).withOpacity(0.12),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(iniciais,
                        style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5, runSpacing: 4,
                        children: [
                          _pill('$concluidas conc.', Colors.green),
                          if (emExecucao > 0)
                            _pill('$emExecucao exec.',
                                const Color(0xFF00FF88)),
                          if (pendentes > 0)
                            _pill('$pendentes pend.', Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$total total',
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _pill(String label, Color cor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: cor.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label,
        style: TextStyle(color: cor, fontSize: 10)),
  );
}