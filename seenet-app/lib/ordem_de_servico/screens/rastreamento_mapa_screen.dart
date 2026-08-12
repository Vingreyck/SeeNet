// lib/ordem_de_servico/screens/rastreamento_mapa_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_socket_service.dart';

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
  Timer? _timerTrilha;
  LatLng? _posicaoAtual;
  /// Rota percorrida, em TRECHOS. É uma lista de listas (e não uma linha só)
  /// porque a trilha guarda 7 dias: se o técnico voltou à mesma OS noutro dia,
  /// ligar o último ponto de um dia no primeiro do outro desenhava uma reta
  /// atravessando o mapa inteiro. Cada trecho vira uma polyline separada.
  List<List<LatLng>> _trechos = [];
  String _tempoAtualizado = '';
  double? _velocidade;
  bool _primeiraVez = true;
  bool _tecnicoChegou = false;
  DateTime? _atualizadoEm;

  final RealtimeSocketService _socket = RealtimeSocketService();
  StreamSubscription? _socketSub;

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
    _carregarTrilha();
    // 🔌 WebSocket: posição chega NA HORA (empurrada pelo backend a cada
    // update do técnico). O polling abaixo agora é só um FALLBACK (rede que
    // bloqueia WS, app antigo sem esse recurso etc.) — por isso ficou mais
    // espaçado (era 3s).
    _socket.conectar();
    _socket.inscreverOS(widget.osId);
    _socketSub = _socket.posicoes.listen((msg) {
      if (msg['os_id'].toString() != widget.osId) return;
      final lat = (msg['latitude'] as num?)?.toDouble();
      final lng = (msg['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      _aplicarPosicao(
        lat: lat,
        lng: lng,
        velocidade: (msg['velocidade'] as num?)?.toDouble(),
        atualizadoEm: DateTime.tryParse(msg['atualizado_em']?.toString() ?? ''),
      );
    });
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _carregarLocalizacao());
    // Trilha muda devagar (backend grava 1 ponto/15s) → atualiza a cada 30s
    _timerTrilha = Timer.periodic(const Duration(seconds: 30), (_) => _carregarTrilha());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerTrilha?.cancel();
    _socketSub?.cancel();
    _socket.fechar();
    _mapController.dispose();
    super.dispose();
  }

  /// Aplica uma posição nova (venha do WebSocket ou do polling HTTP) — mesma
  /// lógica de estado pros dois casos, pra não duplicar.
  void _aplicarPosicao({
    required double lat,
    required double lng,
    double? velocidade,
    DateTime? atualizadoEm,
    String? statusOs,
  }) {
    if (!mounted) return;
    setState(() {
      _posicaoAtual = LatLng(lat, lng);
      _velocidade = velocidade;
      if (statusOs != null) _tecnicoChegou = statusOs == 'em_execucao';
      _atualizadoEm = atualizadoEm ?? DateTime.now();

      final diff = DateTime.now().difference(_atualizadoEm!);
      if (diff.inSeconds < 30) {
        _tempoAtualizado = 'agora';
      } else if (diff.inMinutes < 1) {
        _tempoAtualizado = 'há ${diff.inSeconds}s';
      } else {
        _tempoAtualizado = 'há ${diff.inMinutes}min';
      }
    });

    if (_primeiraVez) {
      try {
        _mapController.move(LatLng(lat, lng), 16);
      } catch (_) {}
      _primeiraVez = false;
    }
  }

  /// Busca a rota percorrida (histórico de posições) pra desenhar a polyline.
  Future<void> _carregarTrilha() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ordens-servico/${widget.osId}/trilha'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final corpo = json.decode(response.body);

        // O backend já manda os trechos prontos (limpos e separados). O ramo
        // do `data` plano é o retrocompatível: app novo com backend antigo
        // ainda desenha, só que como um trecho só.
        final List<dynamic>? segmentos = corpo['segmentos'];
        final List<List<LatLng>> trechos = [];

        if (segmentos != null) {
          for (final seg in segmentos) {
            final pontos = _paraLatLng(seg as List<dynamic>);
            if (pontos.length >= 2) trechos.add(pontos);
          }
        } else {
          final pontos = _paraLatLng(corpo['data'] ?? []);
          if (pontos.length >= 2) trechos.add(pontos);
        }

        if (mounted) setState(() => _trechos = trechos);
      }
    } catch (e) {
      print('⚠️ Erro ao carregar trilha: $e');
    }
  }

  /// 🧭 Abre a posição ATUAL do técnico no Google Maps (app no celular, aba no
  /// navegador) — o admin usa pra traçar rota até ele ou ver a rua/bairro.
  ///
  /// Sem gate do `canLaunchUrl`: no Android 11+ ele falha por causa das
  /// `<queries>` do Manifest mesmo quando o link abre normal (mesma lição do
  /// botão de ligar pro cliente, no wizard).
  Future<void> _abrirNoMaps() async {
    final pos = _posicaoAtual;
    if (pos == null) return;

    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('⚠️ Não deu pra abrir o Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível abrir o Maps'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  List<LatLng> _paraLatLng(List<dynamic> pontos) => pontos
      .map((p) => LatLng(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          ))
      .toList();

  /// Primeiro ponto da rota (bolinha de partida) — do trecho mais antigo.
  LatLng? get _inicioDaRota =>
      _trechos.isEmpty ? null : _trechos.first.first;

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

        _aplicarPosicao(
          lat: lat,
          lng: lng,
          velocidade: data['velocidade'] != null ? (data['velocidade'] as num).toDouble() : null,
          atualizadoEm: data['atualizado_em'] != null ? DateTime.tryParse(data['atualizado_em']) : null,
          statusOs: status,
        );
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
                      // Mostra se o mapa está recebendo em TEMPO REAL (WebSocket)
                      // ou caiu no modo de reserva (atualiza a cada 15s). Sem
                      // isso não dá pra saber, em campo, se o tempo real está
                      // mesmo funcionando.
                      const SizedBox(width: 10),
                      Obx(() => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _socket.conectado.value
                                    ? Icons.bolt_rounded
                                    : Icons.sync_rounded,
                                size: 13,
                                color: _socket.conectado.value
                                    ? const Color(0xFF00FF88)
                                    : Colors.white38,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _socket.conectado.value ? 'ao vivo' : 'a cada 15s',
                                style: TextStyle(
                                  color: _socket.conectado.value
                                      ? const Color(0xFF00FF88)
                                      : Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          )),
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
                // 🛣️ Rota percorrida — uma polyline POR TRECHO, pra não ligar
                // uma visita na outra com uma reta cortando o mapa.
                if (_trechos.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      for (final trecho in _trechos)
                        Polyline(
                          points: trecho,
                          strokeWidth: 4,
                          color: const Color(0xFF3B9EFF).withOpacity(0.85),
                        ),
                    ],
                  ),
                // Ponto de partida da trilha
                if (_inicioDaRota != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _inicioDaRota!,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3B9EFF),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _mapController.move(_posicaoAtual!, 16);
                      },
                      icon: const Icon(Icons.my_location, size: 18, color: Colors.black),
                      label: const Text('Centralizar',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _abrirNoMaps,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Abrir no Maps',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B9EFF),
                        side: const BorderSide(color: Color(0xFF3B9EFF)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

// (OpenStreetMap não usa estilo JSON como o Google Maps)
}