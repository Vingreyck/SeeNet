import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'sync_manager.dart';

class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  final RxBool sincronizando = false.obs;
  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _verificarInicial();
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  Future<void> _verificarInicial() async {
    final result = await Connectivity().checkConnectivity();
    isOnline.value = _temConexao(result);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final tinha = isOnline.value;
    isOnline.value = _temConexao(results);

    // Voltou online → disparar sincronização
    if (!tinha && isOnline.value) {
      _dispararSync();
    }
  }

  bool _temConexao(List<ConnectivityResult> results) {
    return results.any((r) =>
    r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  Future<void> _dispararSync() async {
    try {
      final syncManager = Get.find<SyncManager>();
      await syncManager.sincronizar();
    } catch (_) {}
  }

  bool get offline => !isOnline.value;
}