// lib/ordem_de_servico/screens/rastreamento_mapa_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

/// Mapa ao vivo mostrando a posição do técnico em tempo real
class RastreamentoMapaScreen extends StatefulWidget {
  final String osId;
  final String tecnicoNome;
  final String numeroOs;
  final String clienteNome;

  const RastreamentoMapaScreen({
    super.key,
    required this.osId,
    required this.tecnicoNome,
    required this.numeroOs,
    required this.clienteNome,
  });

  @override
  State<RastreamentoMapaScreen> createState() => _RastreamentoMapaScreenState();
}

class _RastreamentoMapaScreenState extends State<RastreamentoMapaScreen> {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';

  final MapController _mapController = MapController();
  Timer? _timer;
  LatLng? _posicaoAtual;
  String _statusOS = '';
  String _tempoAtualizado = '';
  double? _velocidade;
  bool _primeiraVez = true;
  bool _tecnicoChegou = false;

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
    _carregarLocalizacao();
    // Polling a cada 10 segundos
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _carregarLocalizacao());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _carregarLocalizacao() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/${widget.osId}/location'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        final lat = data['latitude'] as double;
        final lng = data['longitude'] as double;
        final status = data['os_status'] ?? '';

        if (mounted) {
          setState(() {
            _posicaoAtual = LatLng(lat, lng);
            _statusOS = status;
            _velocidade = data['velocidade'] != null
                ? (data['velocidade'] as num).toDouble()
                : null;
            _tecnicoChegou = status == 'em_execucao';

            // Calcular tempo
            if (data['atualizado_em'] != null) {
              final dt = DateTime.tryParse(data['atualizado_em']);
              if (dt != null) {
                final diff = DateTime.now().difference(dt);
                if (diff.inSeconds < 30) {
                  _tempoAtualizado = 'agora';
                } else if (diff.inMinutes < 1) {
                  _tempoAtualizado = 'há ${diff.inSeconds}s';
                } else {
                  _tempoAtualizado = 'há ${diff.inMinutes}min';
                }
              }
            }
          });

          // Centraliza na primeira posição recebida (depois use "Centralizar")
          if (_primeiraVez) {
            try {
              _mapController.move(LatLng(lat, lng), 16);
            } catch (_) {}
            _primeiraVez = false;
          }
        }
      } else if (response.statusCode == 404) {
        // Técnico parou de enviar (chegou ao local)
        if (mounted) {
          setState(() => _tecnicoChegou = true);
        }
      }
    } catch (e) {
      print('⚠️ Erro ao carregar localização: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tecnicoNome,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'OS #${widget.numeroOs} • ${widget.clienteNome}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Status bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _tecnicoChegou
                        ? const Color(0xFF00FF88).withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _tecnicoChegou
                              ? const Color(0xFF00FF88)
                              : _tempoAtualizado == 'agora'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _tecnicoChegou
                            ? '✅ Técnico chegou ao local'
                            : _posicaoAtual != null
                            ? '🚗 Em deslocamento • Atualizado $_tempoAtualizado'
                            : '📡 Aguardando GPS...',
                        style: TextStyle(
                          color: _tecnicoChegou
                              ? const Color(0xFF00FF88)
                              : Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_velocidade != null && _velocidade! > 1 && !_tecnicoChegou) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${(_velocidade! * 3.6).toStringAsFixed(0)} km/h',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: _posicaoAtual == null
                ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00FF88)),
                  SizedBox(height: 16),
                  Text('Aguardando localização do técnico...',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
                : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _posicaoAtual!,
                initialZoom: 16,
              ),
              children: [
                // Tiles do OpenStreetMap (grátis, sem chave)
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.seenet.diagnostico',
                ),
                // Marcador do técnico
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _posicaoAtual!,
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.location_on,
                        size: 46,
                        color: _tecnicoChegou
                            ? const Color(0xFF00FF88)
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botão centralizar
          if (_posicaoAtual != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF2A2A2A),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _mapController.move(_posicaoAtual!, 16);
                  },
                  icon: const Icon(Icons.my_location, size: 18, color: Colors.black),
                  label: const Text('Centralizar no Técnico',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

// (OpenStreetMap não usa estilo JSON como o Google Maps)
}