import 'package:get/get.dart';
import '../models/ordem_servico_model.dart';
import 'package:flutter/material.dart';
import '../services/ordem_servico_service.dart';

class OrdemServicoController extends GetxController {
  final OrdemServicoService _service = OrdemServicoService();

  var ordensServico = <OrdemServico>[].obs;
  var ordensConcluidasLista = <OrdemServico>[].obs;
  var ordemAtual = Rx<OrdemServico?>(null);
  var isLoading = false.obs;
  var isLoadingConcluidas = false.obs;
  var erro = ''.obs;

  // ✅ NOVO: Lista de admins disponíveis
  var adminsDisponiveis = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    carregarMinhasOSs();
    carregarOSsConcluidas();
    carregarAdmins(); // ✅ Carregar admins na inicialização
  }

  // ✅ NOVO: Carregar lista de admins
  Future<void> carregarAdmins() async {
    try {
      final admins = await _service.buscarAdmins();
      adminsDisponiveis.value = admins;
      print('✅ ${admins.length} admin(s) carregado(s)');
    } catch (e) {
      print('⚠️ Erro ao carregar admins: $e');
    }
  }

  Future<void> carregarMinhasOSs() async {
    try {
      isLoading.value = true;
      erro.value = '';

      final oss = await _service.buscarMinhasOSs();
      ordensServico.value = oss;

      print('✅ ${oss.length} OSs carregadas');
    } catch (e) {
      erro.value = 'Erro ao carregar OSs: $e';
      print('❌ Erro: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> carregarOSsConcluidas({String busca = ''}) async {
    try {
      isLoadingConcluidas.value = true;

      final oss = await _service.buscarOSsConcluidas(busca: busca);
      ordensConcluidasLista.value = oss;

      print('✅ ${oss.length} OSs concluídas carregadas');
    } catch (e) {
      print('❌ Erro ao carregar concluídas: $e');
    } finally {
      isLoadingConcluidas.value = false;
    }
  }

  Future<void> carregarDetalhesOS(String osId) async {
    try {
      isLoading.value = true;
      erro.value = '';

      final os = await _service.buscarDetalhesOS(osId);
      ordemAtual.value = os;
    } catch (e) {
      erro.value = 'Erro ao carregar detalhes: $e';
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ MODIFICADO: Agora aceita adminId
  Future<bool> deslocarParaOS(String osId, double lat, double lng, {int? adminId}) async {
    try {
      final sucesso = await _service.deslocarParaOS(osId, lat, lng, adminId: adminId);

      if (sucesso) {
        await carregarMinhasOSs();
        Get.snackbar(
          'Sucesso',
          'Deslocamento iniciado!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      }

      return sucesso;
    } catch (e) {
      Get.snackbar('Erro', 'Falha ao iniciar: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<bool> chegarAoLocal(String osId, double lat, double lng) async {
    try {
      final sucesso = await _service.chegarAoLocal(osId, lat, lng);

      if (sucesso) {
        await carregarMinhasOSs();
        Get.snackbar(
          'Sucesso',
          '📍 Você chegou ao local!',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      return sucesso;
    } catch (e) {
      Get.snackbar('Erro', 'Falha ao informar chegada: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<bool> finalizarExecucao(String osId, Map<String, dynamic> dados) async {
    try {
      final sucesso = await _service.finalizarOS(osId, dados);

      if (sucesso) {
        await carregarMinhasOSs();
        await carregarOSsConcluidas();
        Get.snackbar(
          'Sucesso',
          'OS finalizada com sucesso!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      }

      return sucesso;
    } catch (e) {
      Get.snackbar('Erro', 'Falha ao finalizar: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  List<OrdemServico> get osPendentes =>
      ordensServico.where((os) => os.status == 'pendente').toList();

  List<OrdemServico> get osEmExecucao =>
      ordensServico.where((os) => os.status == 'em_execucao').toList();

  List<OrdemServico> get osConcluidas => ordensConcluidasLista;
}