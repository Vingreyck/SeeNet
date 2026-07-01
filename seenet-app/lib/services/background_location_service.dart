// lib/services/background_location_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const _kChannelId   = 'seenet_gps_channel';
const _kChannelName = 'SeeNet GPS';
const _kNotifId     = 888;

/// Chame uma vez no splash — cria o canal de notificação e configura o serviço.
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Criar canal de notificação (Android)
  const channel = AndroidNotificationChannel(
    _kChannelId,
    _kChannelName,
    description: 'Rastreamento GPS do técnico em campo',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  final notifs = FlutterLocalNotificationsPlugin();
  await notifs
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _kChannelId,
      initialNotificationTitle: 'SeeNet',
      initialNotificationContent: 'Rastreamento GPS ativo',
      foregroundServiceNotificationId: _kNotifId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onStart,
      onBackground: _onIosBackground,
    ),
  );

  print('✅ Background service configurado');
}

// ── Isolate principal ────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  String? osId;
  String? token;
  String? tenantCode;
  StreamSubscription<Position>? posSub;
  DateTime ultimoEnvio = DateTime.fromMillisecondsSinceEpoch(0);

  // Envia a posição pro servidor — no máximo ~1x a cada 10s (mesma cadência de antes).
  Future<void> enviarPosicao(Position pos) async {
    if (osId == null || token == null) return;
    if (DateTime.now().difference(ultimoEnvio).inSeconds < 10) return;
    ultimoEnvio = DateTime.now();

    try {
      await http.put(
        Uri.parse(
          'https://seenet-production.up.railway.app/api/ordens-servico/$osId/location',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Tenant-Code': tenantCode ?? '',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'latitude':  pos.latitude,
          'longitude': pos.longitude,
          'velocidade': pos.speed,
          'precisao':  pos.accuracy,
        }),
      );

      // Atualizar texto da notificação foreground (Android)
      if (service is AndroidServiceInstance) {
        final h = DateTime.now();
        final hStr =
            '${h.hour.toString().padLeft(2,'0')}:${h.minute.toString().padLeft(2,'0')}';
        service.setForegroundNotificationInfo(
          title:   'SeeNet — GPS Ativo',
          content: 'OS #$osId • ${pos.latitude.toStringAsFixed(5)}, '
              '${pos.longitude.toStringAsFixed(5)} • $hStr',
        );
      }

      // Avisa a UI principal (opcional)
      service.invoke('locationUpdate', {
        'lat':  pos.latitude,
        'lng':  pos.longitude,
        'osId': osId,
      });

      print('📍 [BG] ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    } catch (e) {
      print('⚠️ [BG] Erro ao enviar GPS: $e');
    }
  }

  // Abre o stream de localização. No iOS, allowBackgroundLocationUpdates:true
  // mantém o app recebendo posição com ele minimizado (o Timer NÃO roda em 2º
  // plano no iOS — por isso a troca). No Android segue pelo foreground service.
  void iniciarStream() {
    posSub?.cancel();
    final LocationSettings settings = Platform.isIOS
        ? AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.automotiveNavigation,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          )
        : AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 10),
          );
    posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      enviarPosicao,
      onError: (e) => print('⚠️ [BG] Stream GPS: $e'),
    );
  }

  service.on('startTracking').listen((event) {
    osId        = event?['osId']        as String?;
    token       = event?['token']       as String?;
    tenantCode  = event?['tenantCode']  as String?;
    print('📡 [BG] Tracking iniciado — OS $osId');
    iniciarStream();
  });

  service.on('stopTracking').listen((_) {
    print('📡 [BG] Tracking parado — OS $osId');
    posSub?.cancel();
    posSub = null;
    osId = null;
    token = null;
  });

  service.on('stopService').listen((_) {
    posSub?.cancel();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async => true;