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
  // 'deslocamento' = GPS agressivo (dirigindo); 'eco' = técnico no local do
  // cliente (após "cheguei ao local") — precisão média, envio raro, gasta pouco.
  String modo = 'deslocamento';

  // Envia a posição pro servidor — cadência conforme o modo.
  Future<void> enviarPosicao(Position pos) async {
    if (osId == null || token == null) return;
    final minIntervalo = modo == 'eco' ? 45 : 5;
    if (DateTime.now().difference(ultimoEnvio).inSeconds < minIntervalo) return;
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
          title: modo == 'eco'
              ? 'SeeNet — GPS (modo econômico)'
              : 'SeeNet — GPS Ativo',
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
  //
  // MODO ECO (técnico parado no local do cliente): precisão MÉDIA (~100m — o
  // SO resolve por WiFi/célula em vez de segurar o chip GPS ligado) e cadência
  // de ~60s. distanceFilter fica 0 de propósito: com filtro de distância um
  // técnico PARADO nunca dispararia update e o admin veria "sem sinal". No iOS
  // o stream contínuo também é o que mantém o app vivo em background.
  void iniciarStream() {
    posSub?.cancel();
    final bool eco = modo == 'eco';
    final LocationSettings settings = Platform.isIOS
        ? AppleSettings(
            accuracy: eco ? LocationAccuracy.medium : LocationAccuracy.high,
            activityType:
                eco ? ActivityType.other : ActivityType.automotiveNavigation,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          )
        : AndroidSettings(
            accuracy: eco ? LocationAccuracy.medium : LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: Duration(seconds: eco ? 60 : 5),
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
    modo        = (event?['modo'] as String?) ?? 'deslocamento';
    print('📡 [BG] Tracking iniciado — OS $osId (modo: $modo)');
    iniciarStream();
  });

  // Troca de modo em tempo real (ex: "cheguei ao local" → eco). Reabre o
  // stream com as novas configurações e zera o throttle pra mandar uma
  // posição logo — o admin vê o pino "no local" na hora.
  service.on('setMode').listen((event) {
    final novo = (event?['modo'] as String?) ?? 'deslocamento';
    if (novo == modo) return;
    modo = novo;
    ultimoEnvio = DateTime.fromMillisecondsSinceEpoch(0);
    print('🔋 [BG] Modo de tracking → $modo');
    if (osId != null) iniciarStream();
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