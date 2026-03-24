// lib/services/notification_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'api_service.dart';

/// Handler de mensagens em background (precisa ser top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📩 Notificação em background: ${message.notification?.title}');
}

class NotificationService extends GetxService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Contagem de notificações não lidas (para badge)
  final unreadCount = 0.obs;

  // Canal de notificação Android
  static const _androidChannel = AndroidNotificationChannel(
    'seenet_notifications',
    'SeeNet Notificações',
    description: 'Notificações do SeeNet',
    importance: Importance.high,
    playSound: true,
  );

  /// Inicializar tudo (chamar no main.dart após Firebase.initializeApp)
  Future<void> init() async {
    // 1. Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Pedir permissão
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('🔔 Permissão de notificação: ${settings.authorizationStatus}');

    // 3. Configurar notificações locais (para foreground)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 4. Criar canal Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 5. Listener: notificações em foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 6. Listener: quando toca na notificação (app em background)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 7. Checar se o app foi aberto por uma notificação
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }

    print('✅ NotificationService inicializado');
  }

  /// Obter FCM token do dispositivo
  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      print('📱 FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      print('❌ Erro ao obter FCM token: $e');
      return null;
    }
  }

  /// Enviar FCM token pro backend (chamar após login)
  Future<void> sendTokenToBackend() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final api = Get.find<ApiService>();
      await api.put('/auth/fcm-token', {'fcm_token': token});
      print('✅ FCM token enviado ao backend');
    } catch (e) {
      print('⚠️ Erro ao enviar FCM token: $e');
    }
  }

  /// Listener: token atualizado (Firebase pode trocar o token)
  void listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM token atualizado');
      sendTokenToBackend();
    });
  }

  // ── Handlers internos ─────────────────────────────────────────

  /// Notificação recebida com app em foreground → mostrar local notification
  void _onForegroundMessage(RemoteMessage message) {
    print('📩 Foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    unreadCount.value++;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['route'] ?? '',
    );
  }

  /// Tocou na notificação (app em background)
  void _onMessageOpenedApp(RemoteMessage message) {
    print('👆 Notificação tocada (background): ${message.data}');
    _handleNotificationNavigation(message.data);
  }

  /// Tocou na notificação local (app em foreground)
  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Notificação local tocada: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      Get.toNamed(response.payload!);
    }
  }

  /// Navegar com base nos dados da notificação
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      // Pequeno delay pra garantir que o app carregou
      Future.delayed(const Duration(milliseconds: 500), () {
        Get.toNamed(route);
      });
    }
  }

  /// Limpar contagem de não lidas
  void clearUnreadCount() {
    unreadCount.value = 0;
  }
}