// lib/services/tracking_service.dart
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class TrackingService extends GetxService {
  final _bgService = FlutterBackgroundService();
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

  /// Inicia rastreamento GPS em background.
  /// Continua funcionando mesmo com o app fechado.
  Future<void> iniciar(String osId) async {
    if (_osId != null) parar(); // Garante que não tem dois trackings simultâneos

    _osId = osId;
    isTracking.value = true;

    final auth = Get.find<AuthService>();

    await _bgService.startService();

    _bgService.invoke('startTracking', {
      'osId':       osId,
      'token':      auth.token ?? '',
      'tenantCode': auth.tenantCode ?? '',
    });

    print('📡 Background tracking iniciado — OS $osId');
  }

  /// Para o rastreamento e limpa a posição no backend.
  void parar() {
    if (_osId != null) {
      _bgService.invoke('stopTracking', {});
      _limparLocalizacao(_osId!);
      print('📡 Tracking parado — OS $_osId');
    }

    _osId = null;
    isTracking.value = false;

    // Para o background service completamente
    _bgService.invoke('stopService', {});
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