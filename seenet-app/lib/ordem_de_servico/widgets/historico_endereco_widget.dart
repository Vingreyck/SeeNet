import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';

class HistoricoEnderecoWidget extends StatefulWidget {
  final String osId;

  const HistoricoEnderecoWidget({super.key, required this.osId});

  @override
  State<HistoricoEnderecoWidget> createState() => _HistoricoEnderecoWidgetState();
}

class _HistoricoEnderecoWidgetState extends State<HistoricoEnderecoWidget> {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  List<Map<String, dynamic>> _historico = [];
  bool _carregando = true;
  bool _expandido = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final auth = Get.find<AuthService>();
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/${widget.osId}/historico-endereco'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'X-Tenant-Code': auth.tenantCode ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _historico = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _carregando = false;
          });
        }
      } else {
        if (mounted) setState(() => _carregando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88))),
            SizedBox(width: 10),
            Text('Verificando histórico...', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    if (_historico.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.history, color: Colors.white38, size: 18),
            SizedBox(width: 8),
            Text('Nenhum atendimento anterior neste endereço',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header clicável
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_historico.length} atendimento(s) anterior(es) neste endereço',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  _expandido ? Icons.expand_less : Icons.expand_more,
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ),

        // Lista expandida
        if (_expandido) ...[
          const SizedBox(height: 8),
          ..._historico.map((item) => _buildItem(item)),
        ],
      ],
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    String dataFormatada = 'Data desconhecida';
    if (item['data_conclusao'] != null) {
      try {
        final dt = DateTime.parse(item['data_conclusao']);
        dataFormatada = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: OS + data + técnico
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'OS #${item['numero_os'] ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item['tipo_servico'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                dataFormatada,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),

          if (item['tecnico_nome'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text(item['tecnico_nome'],
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],

          // Problema
          if (item['relato_problema'] != null &&
              item['relato_problema'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Problema:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              item['relato_problema'],
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Solução
          if (item['relato_solucao'] != null &&
              item['relato_solucao'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Solução:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              item['relato_solucao'],
              style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}