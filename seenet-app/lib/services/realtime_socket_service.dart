// lib/services/realtime_socket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';

/// Conexão WebSocket pro admin receber a posição do técnico NA HORA, em vez
/// de só polling. Cada tela usa sua própria instância (mapa de 1 OS OU lista
/// de acompanhamento) e chama [fechar] ao sair.
///
/// ADITIVO por decisão de projeto: se o WS não conectar (rede bloqueando,
/// servidor reiniciando, etc.) o polling que já existia nas telas continua
/// funcionando — isso aqui é só um empurrão extra, NUNCA a única fonte de
/// dado. Por isso nenhuma falha daqui mostra erro pro usuário.
class RealtimeSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _watchdog;

  bool _fechado = true;
  bool _conectando = false;
  int _tentativas = 0;
  DateTime _ultimaMensagem = DateTime.now();

  String? _osIdInscrita;
  bool _geralInscrito = false;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// true enquanto a conexão está autenticada e recebendo. As telas podem
  /// mostrar "ao vivo" vs "reconectando" com isso.
  final RxBool conectado = false.obs;

  /// Emite os payloads `{type:'posicao', os_id, latitude, longitude, ...}`.
  Stream<Map<String, dynamic>> get posicoes => _controller.stream;

  static const String _host = 'seenet-production.up.railway.app';

  // O servidor manda um ping de aplicação a cada 25s. Se passar deste tempo
  // sem NADA chegar, a conexão está morta de um jeito que o socket não
  // percebeu (típico de troca de rede/celular) → reconecta.
  static const Duration _silencioMaximo = Duration(seconds: 70);

  void conectar() {
    _fechado = false;
    _abrir();
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_fechado) return;
      if (DateTime.now().difference(_ultimaMensagem) > _silencioMaximo) {
        // Nem o ping do servidor chegou → derruba e reconecta do zero.
        _reconectar();
      }
    });
  }

  void _abrir() {
    if (_fechado || _conectando) return;
    _conectando = true;
    _ultimaMensagem = DateTime.now(); // dá uma janela pro handshake

    try {
      final channel = WebSocketChannel.connect(Uri.parse('wss://$_host/ws'));
      _channel = channel;

      _sub = channel.stream.listen(
        _onMessage,
        onDone: () {
          _conectando = false;
          conectado.value = false;
          _agendarReconexao();
        },
        onError: (_) {
          _conectando = false;
          conectado.value = false;
          _agendarReconexao();
        },
        cancelOnError: true,
      );

      channel.ready.then((_) {
        if (_fechado) return;
        _conectando = false;
        // Token vai na PRIMEIRA MENSAGEM, não na URL: query string de
        // WebSocket costuma cair em log de proxy/servidor.
        String? token;
        String? tenantCode;
        try {
          final auth = Get.find<AuthService>();
          token = auth.token;
          tenantCode = auth.tenantCode;
        } catch (_) {
          return; // sem AuthService registrado não há o que autenticar
        }
        _enviar({
          'type': 'auth',
          'token': token ?? '',
          'tenantCode': tenantCode ?? '',
        });
      }).catchError((_) {
        _conectando = false;
        conectado.value = false;
        _agendarReconexao();
      });
    } catch (_) {
      _conectando = false;
      conectado.value = false;
      _agendarReconexao();
    }
  }

  void _onMessage(dynamic raw) {
    _ultimaMensagem = DateTime.now();

    Map<String, dynamic> msg;
    try {
      msg = json.decode(raw.toString()) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type']) {
      case 'auth_ok':
        _tentativas = 0; // conectou de verdade → zera o backoff
        conectado.value = true;
        // Reaplica as inscrições — essencial depois de uma reconexão.
        if (_osIdInscrita != null) _enviarSubscribeOs(_osIdInscrita!);
        if (_geralInscrito) _enviarSubscribeGeral();
        break;

      case 'auth_erro':
        // Token recusado: insistir rápido não adianta (e martela o servidor).
        // Pode ser transitório (banco fora do ar), então tenta de novo bem
        // devagar; enquanto isso o polling da tela cobre.
        conectado.value = false;
        _tentativas = 6;
        break;

      case 'ping':
        break; // só serve pra alimentar o watchdog (já feito acima)

      case 'posicao':
        _controller.add(msg);
        break;
    }
  }

  /// Inscreve pra receber posição de UMA OS específica (mapa de rastreamento).
  void inscreverOS(String osId) {
    _osIdInscrita = osId;
    _enviarSubscribeOs(osId);
  }

  /// Inscreve pra receber posição de TODAS as OSs do admin (acompanhamento).
  void inscreverGeral() {
    _geralInscrito = true;
    _enviarSubscribeGeral();
  }

  void _enviarSubscribeOs(String osId) => _enviar({'type': 'subscribe_os', 'osId': osId});
  void _enviarSubscribeGeral() => _enviar({'type': 'subscribe_geral'});

  void _enviar(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(json.encode(msg));
    } catch (_) {}
  }

  void _reconectar() {
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _conectando = false;
    conectado.value = false;
    _agendarReconexao();
  }

  void _agendarReconexao() {
    if (_fechado) return;
    _reconnectTimer?.cancel();

    // Backoff exponencial (2s, 4s, 8s… até 60s) com "tempero" aleatório:
    // sem isso, se o servidor reiniciar, TODOS os admins reconectariam no
    // mesmo instante e derrubariam ele de novo.
    _tentativas = (_tentativas + 1).clamp(1, 6);
    final base = min(60, pow(2, _tentativas).toInt());
    final jitter = Random().nextInt(1000);
    _reconnectTimer = Timer(
      Duration(seconds: base, milliseconds: jitter),
      _abrir,
    );
  }

  /// Fecha de vez — chamar no `dispose()` da tela.
  void fechar() {
    _fechado = true;
    conectado.value = false;
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
    _sub?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _controller.close();
  }
}
