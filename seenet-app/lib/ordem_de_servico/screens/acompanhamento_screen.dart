// lib/ordem_de_servico/screens/acompanhamento_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'rastreamento_mapa_screen.dart';

/// Tela do admin: lista de técnicos em campo que o selecionaram como responsável
class AcompanhamentoScreen extends StatefulWidget {
  const AcompanhamentoScreen({super.key});

  @override
  State<AcompanhamentoScreen> createState() => _AcompanhamentoScreenState();
}

class _AcompanhamentoScreenState extends State<AcompanhamentoScreen> {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  List<Map<String, dynamic>> _tecnicos = [];
  bool _carregando = true;
  Timer? _timer;

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
    // Auto-refresh a cada 15s
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            _tecnicos = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _carregando = false;
          });
        }
      }
    } catch (e) {
      print('❌ Erro ao carregar acompanhamento: $e');
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Acompanhar Técnicos',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FF88)),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : _tecnicos.isEmpty
          ? _buildVazio()
          : RefreshIndicator(
        onRefresh: _carregar,
        color: const Color(0xFF00FF88),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tecnicos.length,
          itemBuilder: (context, index) => _buildCard(_tecnicos[index]),
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('Nenhum técnico em campo',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text('Quando um técnico iniciar uma OS e selecionar você como responsável, ele aparecerá aqui.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = item['status'] ?? '';
    final temGPS = item['latitude'] != null;
    final atualizadoEm = item['atualizado_em'] != null
        ? DateTime.tryParse(item['atualizado_em'])
        : null;

    // Calcular "há X min"
    String tempoStr = '';
    if (atualizadoEm != null) {
      final diff = DateTime.now().difference(atualizadoEm);
      if (diff.inSeconds < 30) {
        tempoStr = 'agora';
      } else if (diff.inMinutes < 1) {
        tempoStr = 'há ${diff.inSeconds}s';
      } else if (diff.inMinutes < 60) {
        tempoStr = 'há ${diff.inMinutes}min';
      } else {
        tempoStr = 'há ${diff.inHours}h';
      }
    }

    final statusColor = status == 'em_deslocamento' ? Colors.orange : const Color(0xFF00FF88);
    final statusLabel = status == 'em_deslocamento' ? '🚗 Em Deslocamento' : '🔧 Em Execução';

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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: técnico + status
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(
                    status == 'em_deslocamento' ? Icons.directions_car : Icons.build,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['tecnico_nome'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (temGPS) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tempoStr == 'agora' ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(tempoStr,
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // OS info
            Row(
              children: [
                const Icon(Icons.assignment, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                Text('OS #${item['numero_os'] ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.person_outline, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item['cliente_nome'] ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),

            // Substitui a checagem do botão de rastrear no _buildCard
            if (temGPS) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.to(() => RastreamentoMapaScreen(...)),
                  icon: Icon(Icons.map, color: statusColor, size: 18),
                  label: Text('Ver no Mapa', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: statusColor.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                status == 'em_execucao'
                    ? '🔧 Técnico no local (GPS encerrado)'   // ✅ diferencia dos casos
                    : '📡 Aguardando sinal GPS...',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}