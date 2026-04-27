import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class NavController extends GetxController {
  final RxInt selectedIndex = 1.obs;
  GlobalKey<ScaffoldState>? scaffoldKey;

  // Rotas onde o nav fica ESCONDIDO
  static const _rotasOcultas = [
    '/splash',
    '/login',
    '/registro',
    '/ordens-servico/executar',
    '/checklist/items',
    '/checklist/apps',
    '/checklist/iptv',
    '/checklist/lentidao',
    '/diagnostico',
    '/seguranca/requisicao',
    '/seguranca/confirmar-recebimento',
    '/web-admin',
    '/acompanhamento',
    '/transcricao',
  ];

  // ✅ ValueNotifier nativo do Flutter para a visibilidade do nav.
  //    Substitui o Obx externo do GlobalBottomNav, que estava
  //    causando "setState during build" + "improper use of GetX".
  //    ValueListenableBuilder agenda notificacoes corretamente fora
  //    do frame de build, sem warnings.
  final ValueNotifier<bool> mostrarNavNotifier = ValueNotifier<bool>(true);

  String _rotaAtual = '/checklist';

  /// Atualiza a rota atual e o índice da tab — sempre adiado para
  /// fora do frame atual, evitando "setState during build".
  void atualizarRota(String rota) {
    _aplicarSeguro(() {
      _rotaAtual = rota;
      mostrarNavNotifier.value = !_rotasOcultas.any((r) => rota.startsWith(r));

      if (rota == '/checklist') {
        selectedIndex.value = 1;
      } else if (rota == '/seguranca') {
        selectedIndex.value = 2;
      } else if (rota == '/seguranca/perfil') {
        selectedIndex.value = 3;
      }
    });
  }

  /// Atualiza apenas o índice da tab — também adiado.
  void selecionarTabSafe(int i) {
    _aplicarSeguro(() {
      selectedIndex.value = i;
    });
  }

  /// Executa [acao] em momento seguro:
  /// - Se o framework está em build/layout/paint, agenda para depois do frame.
  /// - Caso contrário, executa imediatamente.
  void _aplicarSeguro(VoidCallback acao) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final emFrame = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks;

    if (emFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => acao());
    } else {
      acao();
    }
  }

  /// Getter de compatibilidade — alguns lugares podem ainda chamar `mostrarNav`.
  bool get mostrarNav => mostrarNavNotifier.value;

  @override
  void onClose() {
    mostrarNavNotifier.dispose();
    super.onClose();
  }
}