// lib/services/tracking_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class TrackingService extends GetxService {
  final _bgService = FlutterBackgroundService();
  String? _osId;
  final isTracking = false.obs;
  Timer? _webTimer; // no web não há background service → timer em foreground

  // Modos de rastreamento:
  // - 'deslocamento': GPS agressivo (alta precisão, envio ~5s) — técnico dirigindo.
  // - 'eco': técnico NO LOCAL (após "cheguei ao local") — continua visível pro
  //   admin até finalizar/reagendar/encaminhar, mas gastando MUITO menos bateria
  //   (precisão média, envio ~60s, só se mover >30m).
  static const String modoDeslocamento = 'deslocamento';
  static const String modoEco = 'eco';
  String _modo = modoDeslocamento;

  final String baseUrl = 'https://seenet-production.up.railway.app/api';

  Map<String, String> get _headers {
    final auth = Get.find<AuthService>();
    return {
      'Authorization': 'Bearer ${auth.token}',
      'X-Tenant-Code': auth.tenantCode ?? '',
      'Content-Type': 'application/json',
    };
  }

  /// Inicia rastreamento GPS.
  /// - Mobile: background service (continua com o app minimizado/fechado).
  /// - Web: timer em foreground (enquanto a aba estiver aberta).
  /// Em AMBOS envia UMA posição na hora, pra o admin não ficar em "aguardando GPS".
  /// [economico]=true inicia direto no modo eco (ex: retomada de OS em execução).
  Future<void> iniciar(String osId, {bool economico = false}) async {
    if (_osId != null) parar(); // não deixa dois trackings simultâneos

    _osId = osId;
    _modo = economico ? modoEco : modoDeslocamento;
    isTracking.value = true;

    // ✅ Posição IMEDIATA (não espera o 1º fix do stream, que pode demorar ~10s).
    _enviarPosicaoAtual(osId);

    if (kIsWeb) {
      // Web não suporta flutter_background_service (startService estoura). Usa timer.
      _iniciarTimerWeb(osId);
      print('📡 [WEB] tracking por timer iniciado — OS $osId (modo: $_modo)');
      return;
    }

    final auth = Get.find<AuthService>();
    await _bgService.startService();
    _bgService.invoke('startTracking', {
      'osId': osId,
      'token': auth.token ?? '',
      'tenantCode': auth.tenantCode ?? '',
      'modo': _modo,
    });

    print('📡 Background tracking iniciado — OS $osId (modo: $_modo)');
  }

  void _iniciarTimerWeb(String osId) {
    _webTimer?.cancel();
    final intervalo = _modo == modoEco
        ? const Duration(seconds: 60)
        : const Duration(seconds: 5);
    _webTimer = Timer.periodic(intervalo, (_) => _enviarPosicaoAtual(osId));
  }

  /// Chegou ao local: NÃO para o rastreamento — muda pro modo econômico.
  /// O admin continua vendo o técnico no mapa até finalizar/reagendar/encaminhar,
  /// mas o GPS passa a gastar uma fração da bateria.
  void modoEconomico() {
    if (_osId == null) return;
    _modo = modoEco;
    if (kIsWeb) {
      _iniciarTimerWeb(_osId!);
    } else {
      _bgService.invoke('setMode', {'modo': modoEco});
    }
    print('🔋 Tracking em modo econômico — OS $_osId');
  }

  /// Captura o GPS agora e manda pro backend (usado no start e no timer do web).
  Future<void> _enviarPosicaoAtual(String osId) async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        print('⚠️ Tracking: permissão de localização negada');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await http.put(
        Uri.parse('$baseUrl/ordens-servico/$osId/location'),
        headers: _headers,
        body: json.encode({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'velocidade': pos.speed,
          'precisao': pos.accuracy,
        }),
      );
      print('📍 Posição enviada — OS $osId (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})');
    } catch (e) {
      print('⚠️ Erro ao enviar posição atual: $e');
    }
  }

  /// Para o rastreamento e limpa a posição no backend.
  void parar() {
    _webTimer?.cancel();
    _webTimer = null;

    if (_osId != null) {
      if (!kIsWeb) _bgService.invoke('stopTracking', {});
      _limparLocalizacao(_osId!);
      print('📡 Tracking parado — OS $_osId');
    }

    _osId = null;
    _modo = modoDeslocamento;
    isTracking.value = false;

    if (!kIsWeb) _bgService.invoke('stopService', {});
  }

  Future<void> _limparLocalizacao(String osId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/ordens-servico/$osId/location'),
        headers: _headers,
      );
    } catch (e) {
      print('⚠️ Erro ao limpar localização: $e');
    }
  }

  @override
  void onClose() {
    parar();
    super.onClose();
  }
}
