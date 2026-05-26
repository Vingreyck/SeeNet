// lib/notificacoes/notificacoes_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'notificacoes_service.dart';

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  final _service = NotificacoesService();
  List<Map<String, dynamic>> _notificacoes = [];
  int _naoLidas = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
  }

  Future<void> _carregar() async {
    try {
      final dados = await _service.buscarNotificacoes();
      if (mounted) {
        setState(() {
          _notificacoes = dados['notificacoes'];
          _naoLidas = dados['nao_lidas'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _marcarTodasLidas() async {
    try {
      await _service.marcarTodasLidas();
      setState(() {
        for (final n in _notificacoes) {
          n['lida'] = true;
        }
        _naoLidas = 0;
      });
    } catch (_) {}
  }

  IconData _icone(String? tipo) {
    switch (tipo) {
      case 'os_deslocamento': return Icons.directions_car_rounded;
      case 'os_chegada': return Icons.location_on_rounded;
      case 'os_finalizada': return Icons.check_circle_rounded;
      case 'sla_alerta': return Icons.timer_rounded;
      case 'nova_os': return Icons.assignment_rounded;
      case 'circuit_breaker': return Icons.electrical_services_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _cor(String? tipo) {
    switch (tipo) {
      case 'os_deslocamento': return Colors.orange;
      case 'os_chegada': return Colors.blue;
      case 'os_finalizada': return const Color(0xFF00FF88);
      case 'sla_alerta': return Colors.red;
      case 'nova_os': return Colors.purple;
      case 'circuit_breaker': return Colors.red;
      default: return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16, left: 16, right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF111111)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Get.back(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('Notificações',
                            style: TextStyle(color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        if (_naoLidas > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF88),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$_naoLidas',
                                style: const TextStyle(color: Colors.black,
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                      const Text('Histórico de alertas',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                if (_naoLidas > 0)
                  TextButton(
                    onPressed: _marcarTodasLidas,
                    child: const Text('Limpar', style: TextStyle(color: Color(0xFF00FF88), fontSize: 13)),
                  ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                : _notificacoes.isEmpty
                ? _buildVazio()
                : RefreshIndicator(
              onRefresh: _carregar,
              color: const Color(0xFF00FF88),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _notificacoes.length,
                itemBuilder: (_, i) => _buildItem(_notificacoes[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> n) {
    final lida = n['lida'] == true;
    final tipo = n['tipo'] as String?;
    final cor = _cor(tipo);
    final data = n['data_criacao'] != null
        ? timeago.format(DateTime.parse(n['data_criacao']).toLocal(), locale: 'pt_BR')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: lida ? const Color(0xFF181818) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: lida ? Colors.white.withOpacity(0.05) : cor.withOpacity(0.25),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: lida ? null : () async {
          await _service.marcarLida(n['id']);
          setState(() {
            n['lida'] = true;
            _naoLidas = (_naoLidas - 1).clamp(0, 999);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icone(tipo), color: cor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n['titulo'] ?? '',
                        style: TextStyle(
                          color: lida ? Colors.white60 : Colors.white,
                          fontWeight: lida ? FontWeight.normal : FontWeight.w600,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 3),
                    Text(n['corpo'] ?? '',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(data, style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
              ),
              if (!lida)
                Container(
                  width: 7, height: 7, margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded,
              size: 56, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 14),
          const Text('Nenhuma notificação',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Alertas de OS, chegadas e finalizações\naparecerão aqui.',
              style: TextStyle(color: Colors.white38, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}