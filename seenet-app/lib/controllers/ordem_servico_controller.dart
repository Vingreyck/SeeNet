import 'package:get/get.dart';
import '../models/ordem_servico_model.dart';
import '../services/tracking_service.dart';
import 'package:flutter/material.dart';
import '../services/ordem_servico_service.dart';
import 'package:seenet/widgets/app_snackbar.dart';


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
    carregarMinhasOSs().then((_) {
      // Retomar tracking se tiver OS em deslocamento
      final osAtiva = ordensServico.firstWhereOrNull(
            (os) => os.status == 'em_deslocamento',
      );
      if (osAtiva != null) {
        try {
          final tracking = Get.find<TrackingService>();
          tracking.iniciar(osAtiva.id);
          print('🔄 Tracking retomado para OS ${osAtiva.numeroOs}');
        } catch (_) {}
      }
    });
    carregarOSsConcluidas();
    carregarAdmins();
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
        AppSnackbar.show(
          'Sucesso',
          'Deslocamento iniciado!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      }

      return sucesso;
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao iniciar: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<bool> chegarAoLocal(String osId, double lat, double lng) async {
    try {
      final sucesso = await _service.chegarAoLocal(osId, lat, lng);

      if (sucesso) {
        await carregarMinhasOSs();
        AppSnackbar.show(
          'Sucesso',
          '📍 Você chegou ao local!',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      return sucesso;
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao informar chegada: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  // Reagendar (cliente não estava no local): IXC vira "Aguardando Agendamento"
  // e a OS sai de "em campo" — o técnico fica livre pra próxima.
  Future<bool> reagendarOS(String osId, double lat, double lng,
      {String? motivo}) async {
    try {
      final sucesso = await _service.reagendarOS(osId, lat, lng, motivo: motivo);

      if (sucesso) {
        await carregarMinhasOSs();
        AppSnackbar.show(
          'Reagendada',
          'OS enviada para novo agendamento.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      return sucesso;
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao reagendar: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  // Lista de técnicos da empresa (pra encaminhar OS).
  Future<List<Map<String, dynamic>>> buscarTecnicos() =>
      _service.buscarTecnicos();

  // Encaminha a OS para outro técnico: some da minha lista, aparece pra ele.
  Future<bool> encaminharOS(String osId, int tecnicoId, {String? motivo}) async {
    try {
      final sucesso = await _service.encaminharOS(osId, tecnicoId, motivo: motivo);
      if (sucesso) {
        await carregarMinhasOSs();
        AppSnackbar.show(
          'Encaminhada',
          'OS enviada para o outro técnico.',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      }
      return sucesso;
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao encaminhar: $e',
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
        AppSnackbar.show(
          'Sucesso',
          'OS finalizada com sucesso!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      }

      return sucesso;
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao finalizar: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<bool> verificarAPR(String osId) async {
    try {
      return await _service.verificarAPR(osId);
    } catch (e) {
      print('⚠️ Erro ao verificar APR: $e');
      return true; // em caso de erro não bloqueia
    }
  }

  List<OrdemServico> get osPendentes =>
      ordensServico.where((os) => os.status == 'pendente').toList();

  List<OrdemServico> get osEmExecucao =>
      ordensServico.where((os) =>
      os.status == 'em_execucao' ||
          os.status == 'em_deslocamento'
      ).toList();


  List<OrdemServico> get osConcluidas => ordensConcluidasLista;
}