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

  final RxString _rotaAtual = '/checklist'.obs;

  /// Atualiza a rota atual e o índice da tab.
  ///
  /// IMPORTANTE: este método deve ser chamado a partir do
  /// `routingCallback` do GetMaterialApp já protegido por
  /// `WidgetsBinding.instance.addPostFrameCallback`. Isso garante que
  /// as mudanças reativas (`_rotaAtual` e `selectedIndex`) só disparem
  /// rebuild do GlobalBottomNav DEPOIS que a transição de rota terminou,
  /// evitando o LateInitializationError no overlay do GetX.
  void atualizarRota(String rota) {
    _rotaAtual.value = rota;
    if (rota == '/checklist') {
      selectedIndex.value = 1;
    } else if (rota == '/seguranca') {
      selectedIndex.value = 2;
    } else if (rota == '/seguranca/perfil') {
      selectedIndex.value = 3;
    }
  }

  /// Atualiza apenas o índice da tab selecionada, com proteção contra
  /// disparar rebuild durante o frame de navegação.
  ///
  /// Use esta versão a partir do `onTap` do bottom nav, que dispara
  /// junto com `Get.toNamed`.
  void selecionarTabSafe(int i) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      selectedIndex.value = i;
    });
  }

  bool get mostrarNav {
    final rota = _rotaAtual.value;
    return !_rotasOcultas.any((r) => rota.startsWith(r));
  }
}