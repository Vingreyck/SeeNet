import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';

class SegurancaController extends GetxController {
  final SegurancaService _service = Get.find<SegurancaService>();

  
  final isLoading = false.obs;
  final isSending = false.obs;

  final epis = <String>[].obs;
  final episSelecionados = <String>{}.obs;

  final minhasRequisicoes = <Map<String, dynamic>>[].obs;
  final requisicoesPendentes = <Map<String, dynamic>>[].obs;
  final todasRequisicoes = <Map<String, dynamic>>[].obs;

  final perfilData = Rxn<Map<String, dynamic>>();
  final statsData = Rxn<Map<String, dynamic>>();

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

  void limparSelecao() => episSelecionados.clear();

  Future<Map<String, dynamic>> enviarRequisicao({
    required String assinaturaBase64,
    required String fotoBase64,
  }) async {
    if (episSelecionados.isEmpty) {
      return {'success': false, 'message': 'Selecione ao menos um EPI'};
    }
    isSending.value = true;
    try {
      final result = await _service.criarRequisicao(
        episSolicitados: episSelecionados.toList(),
        assinaturaBase64: assinaturaBase64,
        fotoBase64: fotoBase64,
      );
      if (result['success'] == true) {
        episSelecionados.clear();
        carregarMinhasRequisicoes();
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

  Future<Map<String, dynamic>> aprovar(int id, {String? observacao}) async {
    isSending.value = true;
    try {
      final result = await _service.aprovar(id, observacao: observacao);
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

  // Helpers de status
  Color statusColor(String status) {
    switch (status) {
      case 'aprovada':
        return const Color(0xFF00FF88);
      case 'recusada':
        return const Color(0xFFFF4444);
      default:
        return const Color(0xFFFFAA00);
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'aprovada':
        return 'Aprovada';
      case 'recusada':
        return 'Recusada';
      default:
        return 'Pendente';
    }
  }
}