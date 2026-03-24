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
  final quantidadesSelecionadas = <String, int>{}.obs;

  final minhasRequisicoes = <Map<String, dynamic>>[].obs;
  final requisicoesPendentes = <Map<String, dynamic>>[].obs;
  final todasRequisicoes = <Map<String, dynamic>>[].obs;
  final historicoRequisicoes = <Map<String, dynamic>>[].obs;
  final requisacoesAprovadas = <Map<String, dynamic>>[].obs;
  final requisacoesRecusadas = <Map<String, dynamic>>[].obs;

  final perfilData = Rxn<Map<String, dynamic>>();
  final statsData = Rxn<Map<String, dynamic>>();

  // ── Guard contra chamadas duplicadas ──────────────────────────
  bool _isCarregandoMinhas = false;
  DateTime? _ultimoEnvio;

  // ── Bloqueio de nova requisição ───────────────────────────────
  bool get hasRequisicaoAguardando => minhasRequisicoes
      .any((r) => r['status'] == 'aguardando_confirmacao' || r['status'] == 'pendente');

  Map<String, dynamic>? get requisicaoAguardando => minhasRequisicoes
      .firstWhereOrNull((r) => r['status'] == 'aguardando_confirmacao');

  // ✅ NOVO: Requisição pendente (enviada mas não aprovada ainda)
  Map<String, dynamic>? get requisicaoPendente => minhasRequisicoes
      .firstWhereOrNull((r) => r['status'] == 'pendente');

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
    quantidadesSelecionadas.clear();
  }

  Future<Map<String, dynamic>> enviarRequisicao() async {
    if (episSelecionados.isEmpty) {
      return {'success': false, 'message': 'Selecione ao menos um EPI'};
    }

    // ✅ Bloqueia se já tiver aguardando confirmação
    if (hasRequisicaoAguardando) {
      return {
        'success': false,
        'message': 'Você possui uma requisição aguardando confirmação de recebimento. Confirme o recebimento antes de fazer uma nova.',
      };
    }

    // ✅ GUARD: Debounce — impede duplo envio em menos de 2s
    final agora = DateTime.now();
    if (_ultimoEnvio != null && agora.difference(_ultimoEnvio!).inSeconds < 2) {
      return {'success': false, 'message': 'Aguarde antes de enviar novamente'};
    }
    _ultimoEnvio = agora;

    isSending.value = true;
    try {
      final episComDetalhes = <String>[];

      for (final epi in episSelecionados) {
        final tam = tamanhosSelecionados[epi];
        final qtd = quantidadesSelecionadas[epi] ?? 1;

        String nome = epi;

        if (tam != null) nome += ' (Tam. $tam)';
        if (qtd > 1) nome += ' x$qtd';

        episComDetalhes.add(nome);
      }

      final result = await _service.criarRequisicao(
        episSolicitados: episComDetalhes,
      );

      if (result['success'] == true) {
        // ✅ REFRESH OTIMISTA: Insere requisição fake IMEDIATAMENTE
        // Isso faz o bloqueio aparecer instantaneamente na UI
        _inserirRequisicaoOtimista(episComDetalhes);

        episSelecionados.clear();
        tamanhosSelecionados.clear();
        quantidadesSelecionadas.clear();

        // ✅ Refresh real em background (sem bloquear a UI)
        _refreshMinhasEmBackground();
      }

      return result;
    } finally {
      isSending.value = false;
    }
  }

  /// ✅ NOVO: Insere uma requisição "fake" na lista local para bloqueio imediato
  void _inserirRequisicaoOtimista(List<String> episSolicitados) {
    final fakeRequisicao = <String, dynamic>{
      'id': -1, // ID temporário
      'status': 'pendente',
      'epis_solicitados': episSolicitados,
      'data_criacao': DateTime.now().toIso8601String(),
      '_otimista': true, // Flag para identificar como otimista
    };

    // Insere no INÍCIO da lista (mais recente primeiro)
    minhasRequisicoes.insert(0, fakeRequisicao);
    minhasRequisicoes.refresh(); // Força update dos Obx()

    print('⚡ Requisição otimista inserida — bloqueio ativo imediatamente');
  }

  /// ✅ NOVO: Recarrega do servidor em background e substitui dados otimistas
  Future<void> _refreshMinhasEmBackground() async {
    // Pequeno delay pra dar tempo do backend processar
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final lista = await _service.buscarMinhasRequisicoes();
      minhasRequisicoes.value = lista;
      print('🔄 Lista de requisições atualizada do servidor');
    } catch (e) {
      print('⚠️ Falha ao atualizar do servidor (dados otimistas mantidos): $e');
      // Em caso de erro, os dados otimistas continuam valendo
      // O próximo carregarMinhasRequisicoes() vai corrigir
    }
  }

  Future<void> carregarMinhasRequisicoes() async {
    // ✅ GUARD: Evita chamadas simultâneas
    if (_isCarregandoMinhas) return;
    _isCarregandoMinhas = true;

    isLoading.value = true;
    try {
      minhasRequisicoes.value = await _service.buscarMinhasRequisicoes();
    } finally {
      isLoading.value = false;
      _isCarregandoMinhas = false;
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

  Future<void> carregarAprovadas() async {
    isLoading.value = true;
    try {
      requisacoesAprovadas.value = await _service.buscarTodas(status: 'aguardando_confirmacao');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> carregarRecusadas() async {
    isLoading.value = true;
    try {
      requisacoesRecusadas.value = await _service.buscarTodas(status: 'recusada');
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
        carregarAprovadas();
        carregarHistorico();
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
        carregarRecusadas();
      }
      return result;
    } finally {
      isSending.value = false;
    }
  }

  final devolucoesPendentes = <Map<String, dynamic>>[].obs;
  final devedores = <Map<String, dynamic>>[].obs;

  Future<void> carregarDevolucoesPendentes() async {
    isLoading.value = true;
    try { devolucoesPendentes.value = await _service.buscarDevolucoesPendentes(); }
    finally { isLoading.value = false; }
  }

  Future<void> carregarDevedores() async {
    isLoading.value = true;
    try { devedores.value = await _service.buscarDevedores(); }
    finally { isLoading.value = false; }
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