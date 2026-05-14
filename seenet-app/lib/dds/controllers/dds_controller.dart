// lib/dds/controllers/dds_controller.dart
import 'package:get/get.dart';
import '../services/dds_service.dart';

class DdsController extends GetxController {
  final _service = Get.find<DdsService>();

  // ── Estado ─────────────────────────────────────────────────
  final Rx<Map<String, dynamic>?> sessaoAtiva = Rx(null);
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;
  final RxList<Map<String, dynamic>> historico = <Map<String, dynamic>>[].obs;

  // ── Sessão ativa ───────────────────────────────────────────

  Future<bool> verificarSessaoAtiva() async {
    isLoading.value = true;
    try {
      final data = await _service.verificarSessaoAtiva();
      final sessao = data?['sessao'];
      sessaoAtiva.value = sessao;
      return sessao != null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> criarSessao({
    required String tema,
    required int duracaoMinutos,
    String localDds = 'BBNet Up Provedor',
    String? linkMeet,                          // ← ADICIONAR
  }) async {
    isSending.value = true;
    try {
      final result = await _service.criarSessao(
        tema: tema,
        duracaoMinutos: duracaoMinutos,
        localDds: localDds,
        linkMeet: linkMeet,                    // ← ADICIONAR
      );
      if (result['success'] == true) sessaoAtiva.value = result['sessao'];
      return result;
    } finally {
      isSending.value = false;
    }
  }

  Future<Map<String, dynamic>> assinar({
    required int sessaoId,
    required String assinaturaBase64,
  }) async {
    isSending.value = true;
    try {
      final result = await _service.assinar(
        sessaoId: sessaoId,
        assinaturaBase64: assinaturaBase64,
      );
      if (result['success'] == true) {
        sessaoAtiva.value = null; // limpa popup
      }
      return result;
    } finally {
      isSending.value = false;
    }
  }

  Future<void> encerrarSessao(int sessaoId) async {
    await _service.encerrarSessao(sessaoId);
    sessaoAtiva.value = null;
  }

  // ── Histórico ──────────────────────────────────────────────

  Future<void> carregarHistorico({ int? ano, int? mes }) async {
    isLoading.value = true;
    try {
      historico.value = await _service.buscarHistorico(ano: ano, mes: mes);
    } finally {
      isLoading.value = false;
    }
  }
}