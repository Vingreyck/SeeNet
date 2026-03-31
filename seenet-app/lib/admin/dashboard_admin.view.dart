import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class DashboardAdminView extends StatefulWidget {
  const DashboardAdminView({super.key});

  @override
  State<DashboardAdminView> createState() => _DashboardAdminViewState();
}

class _DashboardAdminViewState extends State<DashboardAdminView> {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  bool isLoading = true;
  Map<String, dynamic>? dados;

  Map<String, String> get _headers {
    final auth = Get.find<AuthService>();
    return {
      'Authorization': 'Bearer ${auth.token}',
      'X-Tenant-Code': auth.tenantCode ?? '',
    };
  }

  @override
  void initState() {
    super.initState();
    _carregar();
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
        if (mounted) setState(() => dados = body['data']);
      }
    } catch (e) {
      print('❌ Erro ao carregar dashboard: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : dados == null
          ? const Center(
          child: Text('Sem dados', style: TextStyle(color: Colors.white54)))
          : RefreshIndicator(
        onRefresh: _carregar,
        color: const Color(0xFF00FF88),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Referência do mês
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📅 ${dados!['mes_referencia'] ?? ''}',
                  style: const TextStyle(
                      color: Color(0xFF00FF88), fontSize: 13),
                ),
              ),

              const SizedBox(height: 20),

              // ── Cards de resumo ──────────────────────────
              _buildSectionTitle('Resumo do Mês'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Tempo médio',
                      '${dados!['tempo_medio_horas'] ?? '0'}h',
                      Icons.timer_outlined,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'No prazo',
                      '${dados!['taxa_conclusao_prazo'] ?? 0}%',
                      Icons.check_circle_outline,
                      const Color(0xFF00FF88),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Cards de status
              _buildStatusCards(),

              const SizedBox(height: 24),

              // ── OSs por técnico ──────────────────────────
              _buildSectionTitle('OSs por Técnico'),
              const SizedBox(height: 12),
              _buildTecnicosTable(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 24),
          const SizedBox(height: 8),
          Text(valor,
              style: TextStyle(
                  color: cor, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style:
              const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    final porStatus = dados!['por_status'] as List<dynamic>? ?? [];
    final statusConfig = {
      'pendente':       {'label': 'Pendentes',   'cor': Colors.orange,              'icone': Icons.schedule},
      'em_deslocamento':{'label': 'Deslocando',  'cor': Colors.blue,                'icone': Icons.directions_car},
      'em_execucao':    {'label': 'Em execução', 'cor': const Color(0xFF00FF88),    'icone': Icons.build},
      'concluida':      {'label': 'Concluídas',  'cor': Colors.green,               'icone': Icons.check_circle},
      'cancelada':      {'label': 'Canceladas',  'cor': Colors.red,                 'icone': Icons.cancel},
    };

    final Map<String, int> totais = {};
    for (final item in porStatus) {
      totais[item['status'] as String] = int.tryParse(item['total'].toString()) ?? 0;
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: statusConfig.entries.map((entry) {
        final cfg = entry.value;
        final total = totais[entry.key] ?? 0;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: (cfg['cor'] as Color).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(cfg['icone'] as IconData,
                  color: cfg['cor'] as Color, size: 22),
              const SizedBox(height: 6),
              Text(
                total.toString(),
                style: TextStyle(
                    color: cfg['cor'] as Color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                cfg['label'] as String,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTecnicosTable() {
    final porTecnico = dados!['por_tecnico'] as List<dynamic>? ?? [];

    // Agrupar por técnico
    final Map<String, Map<String, int>> agrupado = {};
    for (final item in porTecnico) {
      final nome = item['tecnico'] as String;
      final status = item['status'] as String;
      final total = int.tryParse(item['total'].toString()) ?? 0;
      agrupado.putIfAbsent(nome, () => {});
      agrupado[nome]![status] = total;
    }

    if (agrupado.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Nenhum dado disponível',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: agrupado.entries.map((entry) {
          final nome = entry.key;
          final statusMap = entry.value;
          final total = statusMap.values.fold(0, (a, b) => a + b);
          final concluidas = statusMap['concluida'] ?? 0;
          final pendentes = statusMap['pendente'] ?? 0;
          final emExecucao = statusMap['em_execucao'] ?? 0;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF00FF88).withOpacity(0.2),
                  child: Text(
                    nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Color(0xFF00FF88), fontWeight: FontWeight.bold),
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
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusPill('$concluidas conc.', Colors.green),
                          const SizedBox(width: 6),
                          if (emExecucao > 0)
                            _buildStatusPill('$emExecucao exec.', const Color(0xFF00FF88)),
                          if (emExecucao > 0) const SizedBox(width: 6),
                          if (pendentes > 0)
                            _buildStatusPill('$pendentes pend.', Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$total total',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusPill(String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: cor, fontSize: 11)),
    );
  }
}