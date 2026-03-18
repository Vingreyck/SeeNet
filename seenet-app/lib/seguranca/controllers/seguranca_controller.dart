import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';

class SegurancaController extends GetxController {
  final SegurancaService _service = Get.find<SegurancaService>();

  final isLoading = false.obs;
  final isSending = false.obs;

  final epis = <String>[].obs;
  final episSelecionados = <String>{}.obs;
  final tamanhosSelecionados = <String, String>{}.obs;

  final minhasRequisicoes = <Map<String, dynamic>>[].obs;
  final requisicoesPendentes = <Map<String, dynamic>>[].obs;
  final todasRequisicoes = <Map<String, dynamic>>[].obs;
  final historicoRequisicoes = <Map<String, dynamic>>[].obs;

  final perfilData = Rxn<Map<String, dynamic>>();
  final statsData = Rxn<Map<String, dynamic>>();

  // ── Bloqueio de nova requisição ───────────────────────────────
  // Técnico fica bloqueado enquanto houver uma aguardando confirmação
  bool get hasRequisicaoAguardando => minhasRequisicoes
      .any((r) => r['status'] == 'aguardando_confirmacao');

  Map<String, dynamic>? get requisicaoAguardando => minhasRequisicoes
      .firstWhereOrNull((r) => r['status'] == 'aguardando_confirmacao');

  @override
  void onInit() {
    super.onInit();
    carregarEpis();
  }

  Future<void> carregarEpis() async {
    epis.value = await _service.buscarEpis();
  }

  void toggleEpi(String epi) {
    if (episSelecionados.contains(epi)) {
      episSelecionados.remove(epi);
    } else {
      episSelecionados.add(epi);
    }
  }

  void limparSelecao() {
    episSelecionados.clear();
    tamanhosSelecionados.clear();
  }

  Future<Map<String, dynamic>> enviarRequisicao() async {
    if (episSelecionados.isEmpty)
      return {'success': false, 'message': 'Selecione ao menos um EPI'};

    // Bloqueia se já tiver uma aguardando confirmação
    if (hasRequisicaoAguardando) {
      return {
        'success': false,
        'message': 'Você possui uma requisição aguardando confirmação de recebimento. Confirme o recebimento antes de fazer uma nova.',
      };
    }

    isSending.value = true;
    try {
      final episComTamanho = episSelecionados.map((epi) {
        final tam = tamanhosSelecionados[epi];
        return tam != null ? '$epi (Tam. $tam)' : epi;
      }).toList();

      final result = await _service.criarRequisicao(
        episSolicitados: episComTamanho,
      );
      if (result['success'] == true) {
        episSelecionados.clear();
        await carregarMinhasRequisicoes();
      }
      return result;
    } finally {
      isSending.value = false;
    }
  }

  Future<void> carregarMinhasRequisicoes() async {
    isLoading.value = true;
    try {
      minhasRequisicoes.value = await _service.buscarMinhasRequisicoes();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> carregarPendentes() async {
    isLoading.value = true;
    try {
      requisicoesPendentes.value = await _service.buscarPendentes();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> carregarTodas({String? status}) async {
    isLoading.value = true;
    try {
      todasRequisicoes.value = await _service.buscarTodas(status: status);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> carregarHistorico({int? tecnicoId}) async {
    isLoading.value = true;
    try {
      historicoRequisicoes.value =
      await _service.buscarHistorico(tecnicoId: tecnicoId);
    } finally {
      isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>> aprovar(
      int id, {
        String? observacao,
        String? dataEntrega,
        List<Map<String, dynamic>>? itensIxc,
      }) async {
    isSending.value = true;
    try {
      final result = await _service.aprovar(
        id,
        observacao: observacao,
        dataEntrega: dataEntrega,
        itensIxc: itensIxc,
      );
      if (result['success'] == true) {
        carregarPendentes();
        carregarTodas();
      }
      return result;
    } finally {
      isSending.value = false;
    }
  }

  Future<Map<String, dynamic>> recusar(int id, {required String observacao}) async {
    isSending.value = true;
    try {
      final result = await _service.recusar(id, observacao: observacao);
      if (result['success'] == true) {
        carregarPendentes();
        carregarTodas();
      }
      return result;
    } finally {
      isSending.value = false;
    }
  }

  Future<void> carregarPerfil() async {
    final data = await _service.buscarPerfil();
    if (data != null) {
      perfilData.value = data['usuario'];
      statsData.value = data['stats'];
    }
  }

  Future<bool> atualizarFoto(String fotoBase64) async {
    final ok = await _service.atualizarFotoPerfil(fotoBase64);
    if (ok) carregarPerfil();
    return ok;
  }

  Color statusColor(String status) {
    switch (status) {
      case 'concluida':
      case 'aprovada':         return const Color(0xFF00FF88);
      case 'recusada':         return const Color(0xFFFF4444);
      case 'aguardando_confirmacao': return const Color(0xFF00BFFF);
      default:                 return const Color(0xFFFFAA00);
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'concluida':             return 'Concluída';
      case 'aprovada':              return 'Aprovada';
      case 'recusada':              return 'Recusada';
      case 'aguardando_confirmacao': return 'Ag. Confirmação';
      default:                      return 'Pendente';
    }
  }
}