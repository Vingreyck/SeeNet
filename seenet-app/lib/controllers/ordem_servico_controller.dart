import 'package:get/get.dart';
import '../models/ordem_servico_model.dart';
import 'package:flutter/material.dart';
import '../services/ordem_servico_service.dart';

class OrdemServicoController extends GetxController {
  final OrdemServicoService _service = OrdemServicoService();

  var ordensServico = <OrdemServico>[].obs;
  var ordemAtual = Rx<OrdemServico?>(null);
  var isLoading = false.obs;
  var erro = ''.obs;

  @override
  void onInit() {
    super.onInit();
    carregarMinhasOSs();
  }

  // Carregar OSs do técnico
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

  // Carregar detalhes de uma OS
  Future<void> carregarDetalhesOS(String osId) async {
    try {
      isLoading.value = true;
      erro.value = '';
      
      final os = await _service.buscarDetalhesOS(osId);
      ordemAtual.value = os;
      
      print('✅ Detalhes da OS ${os.numeroOs} carregados');
    } catch (e) {
      erro.value = 'Erro ao carregar detalhes: $e';
      print('❌ Erro: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Iniciar execução
  Future<bool> iniciarExecucao(String osId, double lat, double lng) async {
    try {
      final sucesso = await _service.iniciarOS(osId, lat, lng);
      
      if (sucesso) {
        await carregarMinhasOSs(); // Recarrega a lista
        Get.snackbar(
          'Sucesso',
          'Execução iniciada!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      }
      
      return sucesso;
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Falha ao iniciar: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  // Finalizar OS
  Future<bool> finalizarExecucao(String osId, Map<String, dynamic> dados) async {
    try {
      final sucesso = await _service.finalizarOS(osId, dados);
      
      if (sucesso) {
        await carregarMinhasOSs();
        Get.snackbar(
          'Sucesso',
          'OS finalizada com sucesso!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      }
      
      return sucesso;
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Falha ao finalizar: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  // Filtrar por status
  List<OrdemServico> get osPendentes => 
      ordensServico.where((os) => os.status == 'pendente').toList();
      
  List<OrdemServico> get osEmExecucao => 
      ordensServico.where((os) => os.status == 'em_execucao').toList();
      
  List<OrdemServico> get osConcluidas => 
      ordensServico.where((os) => os.status == 'concluida').toList();
}