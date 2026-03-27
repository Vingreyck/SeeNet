// lib/services/tracking_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Envia localização do técnico a cada 10s durante deslocamento.
/// Inicia em "Iniciar Deslocamento", para em "Cheguei ao Local".
class TrackingService extends GetxService {
  Timer? _timer;
  String? _osId;
  final isTracking = false.obs;

  final String baseUrl = 'https://seenet-production.up.railway.app/api';

  Map<String, String> get _headers {
    final auth = Get.find<AuthService>();
    return {
      'Authorization': 'Bearer ${auth.token}',
      'X-Tenant-Code': auth.tenantCode ?? '',
      'Content-Type': 'application/json',
    };
  }

  /// Inicia envio de GPS a cada 10 segundos
  void iniciar(String osId) {
    if (_timer != null) parar(); // Garantir que não tem 2 timers

    _osId = osId;
    isTracking.value = true;

    print('📡 Tracking iniciado para OS $osId');

    // Enviar imediatamente
    _enviarLocalizacao();

    // Depois a cada 10 segundos
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _enviarLocalizacao();
    });
  }

  /// Para o envio de GPS
  void parar() {
    _timer?.cancel();
    _timer = null;
    isTracking.value = false;

    if (_osId != null) {
      _limparLocalizacao(_osId!);
      print('📡 Tracking parado para OS $_osId');
    }

    _osId = null;
  }

  /// Envia posição atual pro backend
  Future<void> _enviarLocalizacao() async {
    if (_osId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));

      await http.put(
        Uri.parse('$baseUrl/ordens-servico/$_osId/location'),
        headers: _headers,
        body: json.encode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'velocidade': position.speed,
          'precisao': position.accuracy,
        }),
      );

      print('📍 GPS enviado: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
    } catch (e) {
      print('⚠️ Erro ao enviar GPS: $e');
      // Não para o tracking por erro temporário (sem sinal, etc)
    }
  }

  /// Limpa posição no backend ao chegar
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