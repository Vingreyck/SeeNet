// lib/ordem_de_servico/screens/acompanhamento_screen.dart — REDESIGN
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'rastreamento_mapa_screen.dart';

class AcompanhamentoScreen extends StatefulWidget {
  const AcompanhamentoScreen({super.key});

  @override
  State<AcompanhamentoScreen> createState() => _AcompanhamentoScreenState();
}

class _AcompanhamentoScreenState extends State<AcompanhamentoScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  List<Map<String, dynamic>> _tecnicos = [];
  bool _carregando = true;
  Timer? _timer;

  late AnimationController _pulseCtrl;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  Map<String, String> get _headers {
    final auth = Get.find<AuthService>();
    return {
      'Authorization': 'Bearer ${auth.token}',
      'X-Tenant-Code': auth.tenantCode ?? '',
      'Content-Type': 'application/json',
    };
  }

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _carregar());
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/acompanhamento'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _tecnicos = List<Map<String, dynamic>>.from(
                data['data'] ?? []);
            _carregando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
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
              bottom: 16,
              left: 8,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1F2D), Color(0xFF111111)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                // Ícone com pulse
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, child) => Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFFF).withOpacity(
                          0.08 + _pulseCtrl.value * 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00BFFF).withOpacity(
                              0.25 + _pulseCtrl.value * 0.2)),
                    ),
                    child: const Icon(Icons.radar_rounded,
                        color: Color(0xFF00BFFF), size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Acompanhamento',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      Text('Técnicos em campo • Auto-atualiza 15s',
                          style: TextStyle(
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

          // ── Contador ────────────────────────────────────────
          if (!_carregando && _tecnicos.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF00FF88)
                                  .withOpacity(_pulseCtrl.value * 0.6),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${_tecnicos.length} técnico(s) em campo',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                  const Spacer(),
                  Text(
                    '${_tecnicos.where((t) => t['latitude'] != null).length} com GPS',
                    style: const TextStyle(
                        color: Color(0xFF00FF88), fontSize: 12),
                  ),
                ],
              ),
            ),

          // ── Lista ────────────────────────────────────────────
          Expanded(
            child: _carregando
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00BFFF), strokeWidth: 2.5))
                : _tecnicos.isEmpty
                ? _buildVazio()
                : RefreshIndicator(
              onRefresh: _carregar,
              color: const Color(0xFF00BFFF),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: _tecnicos.length,
                itemBuilder: (context, index) =>
                    _buildCard(_tecnicos[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = item['status'] ?? '';
    final temGPS = item['latitude'] != null;
    final atualizadoEm = item['atualizado_em'] != null
        ? DateTime.tryParse(item['atualizado_em'])
        : null;

    // Frescor da posição em 3 níveis: 🟢 ao vivo (<30s) · 🟡 atrasado (<2min) · 🔴 sem sinal.
    String tempoStr = '';
    Color corFrescor = const Color(0xFF00FF88);
    bool semSinal = false;
    if (atualizadoEm != null) {
      final diff = DateTime.now().difference(atualizadoEm);
      if (diff.inSeconds < 30) {
        tempoStr = 'ao vivo';
        corFrescor = const Color(0xFF00FF88);
      } else if (diff.inSeconds < 120) {
        tempoStr = diff.inMinutes < 1
            ? 'há ${diff.inSeconds}s'
            : 'há ${diff.inMinutes}min';
        corFrescor = Colors.orange;
      } else {
        tempoStr = diff.inMinutes < 60
            ? 'há ${diff.inMinutes}min'
            : 'há ${diff.inHours}h';
        corFrescor = Colors.red;
        semSinal = true;
      }
    }

    final isDeslocamento = status == 'em_deslocamento';
    final cor = isDeslocamento ? Colors.orange : const Color(0xFF00FF88);
    final statusLabel = isDeslocamento ? 'Em Deslocamento' : 'Em Execução';
    final statusIcon =
    isDeslocamento ? Icons.directions_car_rounded : Icons.build_rounded;

    return GestureDetector(
      onTap: temGPS
          ? () => Get.to(() => RastreamentoMapaScreen(
        osId: item['id'].toString(),
        tecnicoNome: item['tecnico_nome'] ?? '',
        numeroOs: item['numero_os'] ?? '',
        clienteNome: item['cliente_nome'] ?? '',
      ))
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.06),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cor.withOpacity(0.12),
                      border: Border.all(
                          color: cor.withOpacity(0.3), width: 1.5),
                    ),
                    child: Center(child: Icon(statusIcon, color: cor, size: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['tecnico_nome'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                  color: cor, shape: BoxShape.circle),
                            ),
                            Text(statusLabel,
                                style: TextStyle(
                                    color: cor, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (temGPS)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: corFrescor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(semSinal ? '$tempoStr • sem sinal' : tempoStr,
                            style: TextStyle(
                                color: semSinal ? Colors.red : Colors.white38,
                                fontSize: 10)),
                      ],
                    ),
                ],
              ),
            ),

            // ── Info OS ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_outlined,
                          color: Colors.white24, size: 14),
                      const SizedBox(width: 6),
                      Text('OS #${item['numero_os'] ?? ''}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 14),
                      const Icon(Icons.person_outline_rounded,
                          color: Colors.white24, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(item['cliente_nome'] ?? '',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),

                  if (temGPS) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Get.to(() => RastreamentoMapaScreen(
                          osId: item['id'].toString(),
                          tecnicoNome: item['tecnico_nome'] ?? '',
                          numeroOs: item['numero_os'] ?? '',
                          clienteNome: item['cliente_nome'] ?? '',
                        )),
                        icon: Icon(Icons.map_rounded,
                            color: cor, size: 16),
                        label: Text('Ver no Mapa',
                            style: TextStyle(
                                color: cor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: cor.withOpacity(0.4)),
                          padding:
                          const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      isDeslocamento
                          ? '📡 Aguardando sinal GPS...'
                          : '🔧 Técnico no local (GPS encerrado)',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
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
          Icon(Icons.location_off_rounded,
              size: 56,
              color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 14),
          const Text('Nenhum técnico em campo',
              style: TextStyle(
                  color: Colors.white38, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Quando um técnico iniciar uma OS e selecionar você como responsável, ele aparecerá aqui.',
              style: TextStyle(color: Colors.white24, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}