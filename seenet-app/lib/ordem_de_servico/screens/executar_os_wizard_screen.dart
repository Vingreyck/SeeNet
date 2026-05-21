// lib/ordem_de_servico/screens/executar_os_wizard_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import '../../services/connectivity_service.dart';
import '../../services/sync_manager.dart';
import '../../services/tracking_service.dart';
import '../../services/estoque_service.dart';
import 'dart:convert';
import '../../controllers/ordem_servico_controller.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/localizacao_widget.dart';
import '../widgets/qr_scanner_widget.dart';
import '../widgets/anexos_widget.dart';
import '../widgets/historico_endereco_widget.dart';
import '../widgets/materiais_estoque_widget.dart';
import '../widgets/assinatura_widget.dart';
import '../widgets/campo_com_voz.dart';
import 'apr_screen.dart';
import 'package:intl/intl.dart';

class ExecutarOSWizardScreen extends StatefulWidget {
  const ExecutarOSWizardScreen({super.key});

  @override
  State<ExecutarOSWizardScreen> createState() => _ExecutarOSWizardScreenState();
}

class _ExecutarOSWizardScreenState extends State<ExecutarOSWizardScreen> {
  final OrdemServicoController controller = Get.find<OrdemServicoController>();
  late OrdemServico os;

  int _etapaAtual = 0;
  final int _totalEtapas = 8;

  final TextEditingController onuModeloController = TextEditingController();
  final TextEditingController onuSerialController = TextEditingController();
  final TextEditingController onuStatusController = TextEditingController();
  final TextEditingController onuSinalController = TextEditingController();
  final TextEditingController relatoProblemaController = TextEditingController();
  final TextEditingController relatoSolucaoController = TextEditingController();
  final TextEditingController materiaisController = TextEditingController();
  List<ItemOS> itensEstoque = [];
  final TextEditingController observacoesController = TextEditingController();

  double? latitude;
  double? longitude;
  List<AnexoComDescricao> fotosAnexadas = [];
  Uint8List? assinaturaBytes;
  bool osIniciada = false;
  String statusAtual = 'pendente';
  int? adminSelecionadoId;
  String? adminSelecionadoNome;
  bool _isLoading = false;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    os = Get.arguments as OrdemServico;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final osAtualizada = controller.ordensServico
          .firstWhereOrNull((o) => o.id == os.id);
      if (osAtualizada != null && osAtualizada.status != os.status) {
        setState(() => os = osAtualizada);
      }

      // Se em execução, checar se APR foi preenchido
      if (os.status == 'em_execucao') {
        final aprOk = await controller.verificarAPR(os.id);
        if (!aprOk && mounted) {
          final resultado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => AprScreen(os: os)),
          );
          if (resultado == true && mounted) {
            setState(() { _etapaAtual = 1; });
          }
        }
      }

      if (os.status == 'pendente') {
        await controller.carregarAdmins();
        if (mounted) await _selecionarAdmin();
      }
    });

    if (os.status == 'em_execucao') {
      osIniciada = true;
      _etapaAtual = 1;
    } else if (os.status == 'em_deslocamento') {
      osIniciada = false;
      _etapaAtual = 0;
      statusAtual = 'em_deslocamento';
    } else {
      osIniciada = false;
      _etapaAtual = 0;
      statusAtual = 'pendente';
    }

    if (os.latitude != null && os.longitude != null) {
      latitude = os.latitude;
      longitude = os.longitude;
    }
  }

  @override
  void dispose() {
    onuModeloController.dispose();
    onuSerialController.dispose();
    onuStatusController.dispose();
    onuSinalController.dispose();
    relatoProblemaController.dispose();
    relatoSolucaoController.dispose();
    materiaisController.dispose();
    observacoesController.dispose();
    super.dispose();
  }

  String _getNomeEtapa(int etapa) {
    switch (etapa) {
      case 0: return 'Localização';
      case 1: return 'Fotos';
      case 2: return 'Dados ONU';
      case 3: return 'Relatos';
      case 4: return 'Materiais';
      case 5: return 'Observações';
      case 6: return 'Assinatura';
      case 7: return 'Revisão';
      default: return '';
    }
  }

  Widget _buildEtapaAtual() {
    switch (_etapaAtual) {
      case 0: return _buildEtapaLocalizacao();
      case 1: return _buildEtapaAnexos();
      case 2: return _buildEtapaDadosONU();
      case 3: return _buildEtapaRelatos();
      case 4: return _buildEtapaMateriais();
      case 5: return _buildEtapaObservacoes();
      case 6: return _buildEtapaAssinatura();
      case 7: return _buildEtapaRevisao();
      default: return Container();
    }
  }

  Widget _buildEtapaLocalizacao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.location_on_rounded, titulo: 'Localização', descricao: 'Confirme ou capture a localização do atendimento'),
          const SizedBox(height: 20),
          _buildCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Cliente', os.clienteNome),
              if (os.clienteEndereco != null) _buildInfoRow('Endereço', os.clienteEndereco!),
              if (os.clienteTelefone != null) _buildInfoRow('Telefone', os.clienteTelefone!),
            ],
          )),
          const SizedBox(height: 12),
          HistoricoEnderecoWidget(osId: os.id),
          const SizedBox(height: 12),
          _buildCard(child: LocalizacaoWidget(
            onLocalizacaoCapturada: (lat, lng) {
              setState(() { latitude = lat; longitude = lng; });
            },
            latitudeInicial: latitude,
            longitudeInicial: longitude,
          )),
        ],
      ),
    );
  }

  Widget _buildEtapaAnexos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.camera_alt_rounded, titulo: 'Fotos do Local', descricao: 'Tire fotos do roteador, ONU, local e equipamentos'),
          const SizedBox(height: 20),
          _buildCard(child: AnexosWidget(
            onAnexosAlterados: (anexos) {
              setState(() { fotosAnexadas = anexos; });
            },
          )),
        ],
      ),
    );
  }

  Widget _buildEtapaDadosONU() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.router_rounded, titulo: 'Dados da ONU', descricao: 'Informações técnicas do equipamento (opcional)'),
          const SizedBox(height: 20),
          _buildCard(child: Column(
            children: [
              CampoComVoz(controller: onuModeloController, label: 'Modelo da ONU', hint: 'Ex: AN5506-04-F'),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: CampoComVoz(controller: onuSerialController, label: 'Serial da ONU', hint: 'Ex: HWTC12345678')),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Escanear QR code ou código de barras',
                    child: GestureDetector(
                      onTap: _abrirScanner,
                      child: Container(
                        height: 52, width: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00FF88), size: 24),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CampoComVoz(controller: onuStatusController, label: 'Status', hint: 'Ex: Online'),
              const SizedBox(height: 14),
              _buildTextField(controller: onuSinalController, label: 'Sinal Óptico (dBm)', hint: 'Ex: -24.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true)),
            ],
          )),
        ],
      ),
    );
  }

  Future<void> _abrirScanner() async {
    final serial = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => QrScannerWidget(onSerialCapturado: (s) {})),
    );
    if (serial != null && serial.isNotEmpty && mounted) {
      setState(() => onuSerialController.text = serial);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Serial capturado: $serial'),
        backgroundColor: const Color(0xFF00FF88),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _buildEtapaRelatos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.description_rounded, titulo: 'Relatos', descricao: 'Descreva o problema e a solução aplicada'),
          const SizedBox(height: 20),
          _buildCard(child: Column(
            children: [
              CampoComVoz(controller: relatoProblemaController, label: 'Problema Identificado *', hint: 'Descreva o problema encontrado...', maxLines: 4, appendMode: true),
              const SizedBox(height: 14),
              CampoComVoz(controller: relatoSolucaoController, label: 'Solução Aplicada *', hint: 'Descreva a solução aplicada...', maxLines: 4, appendMode: true),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildEtapaMateriais() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.build_rounded, titulo: 'Materiais Utilizados', descricao: 'Selecione os materiais e equipamentos do estoque'),
          const SizedBox(height: 20),
          _buildCard(child: MateriaisEstoqueWidget(
            osIdExterno: os.idExterno ?? '',
            onItensAlterados: (itens) {
              setState(() {
                itensEstoque = itens;
                materiaisController.text = itens.map((i) =>
                '${i.produto.descricao} x${i.quantidade.toStringAsFixed(0)} (R\$${i.valorTotal.toStringAsFixed(2)})').join('\n');
              });
            },
          )),
        ],
      ),
    );
  }

  Widget _buildEtapaObservacoes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.notes_rounded, titulo: 'Observações', descricao: 'Informações adicionais sobre o atendimento'),
          const SizedBox(height: 20),
          _buildCard(child: CampoComVoz(
            controller: observacoesController,
            label: 'Observações',
            hint: 'Detalhes adicionais, dificuldades encontradas...',
            maxLines: 6,
            appendMode: true,
          )),
        ],
      ),
    );
  }

  Widget _buildEtapaAssinatura() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.draw_rounded, titulo: 'Assinatura do Cliente', descricao: 'Solicite a assinatura do cliente no campo abaixo'),
          const SizedBox(height: 20),
          _buildCard(child: AssinaturaWidget(
            onAssinaturaSalva: (assinatura) {
              setState(() { assinaturaBytes = assinatura; });
            },
          )),
        ],
      ),
    );
  }

  Widget _buildEtapaRevisao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.check_circle_rounded, titulo: 'Revisão Final', descricao: 'Confira todas as informações antes de finalizar'),
          const SizedBox(height: 20),
          _buildResumoCard(titulo: 'Localização', icone: Icons.location_on_rounded,
              conteudo: latitude != null ? 'Lat: ${latitude!.toStringAsFixed(6)}\nLng: ${longitude!.toStringAsFixed(6)}' : 'Não capturada', editarEtapa: 0),
          _buildResumoCard(titulo: 'Fotos', icone: Icons.camera_alt_rounded,
              conteudo: '${fotosAnexadas.length} foto(s) anexada(s)', editarEtapa: 1),
          if (onuModeloController.text.isNotEmpty)
            _buildResumoCard(titulo: 'Dados da ONU', icone: Icons.router_rounded,
                conteudo: 'Modelo: ${onuModeloController.text}', editarEtapa: 2),
          _buildResumoCard(titulo: 'Relatos', icone: Icons.description_rounded,
              conteudo: relatoProblemaController.text.length > 50
                  ? '${relatoProblemaController.text.substring(0, 50)}...'
                  : relatoProblemaController.text, editarEtapa: 3),
          _buildResumoCard(titulo: 'Materiais', icone: Icons.build_rounded,
              conteudo: itensEstoque.isNotEmpty
                  ? '${itensEstoque.length} item(ns) - R\$ ${itensEstoque.fold<double>(0, (s, i) => s + i.valorTotal).toStringAsFixed(2)}'
                  : 'Nenhum material adicionado', editarEtapa: 4),
          _buildResumoCard(titulo: 'Assinatura', icone: Icons.draw_rounded,
              conteudo: assinaturaBytes != null ? '✓ Confirmada' : '✗ Não assinada', editarEtapa: 6),
        ],
      ),
    );
  }

  void _proximaEtapa() {
    if (_isLoading) return;
    if (!_validarEtapaAtual()) return;
    if (_etapaAtual == 0 && !osIniciada) { _iniciarOS(); return; }
    if (_etapaAtual == _totalEtapas - 1) { _finalizarOS(); return; }
    setState(() => _etapaAtual++);
  }

  bool _validarEtapaAtual() {
    switch (_etapaAtual) {
      case 0:
        if (latitude == null || longitude == null) { _mostrarErro('Capture a localização antes de prosseguir'); return false; }
        return true;
      case 3:
        if (relatoProblemaController.text.trim().isEmpty) { _mostrarErro('Descreva o problema identificado'); return false; }
        if (relatoSolucaoController.text.trim().isEmpty) { _mostrarErro('Descreva a solução aplicada'); return false; }
        return true;
      case 6:
        if (assinaturaBytes == null) { _mostrarErro('Solicite a assinatura do cliente'); return false; }
        return true;
      default: return true;
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensagem),
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _iniciarOS() async {
    setState(() => _isLoading = true);
    try {
      if (statusAtual == 'pendente') {
        if (adminSelecionadoId == null) {
          final selecionou = await _selecionarAdmin();
          if (!selecionou) return;
        }
        final connectivity = Get.find<ConnectivityService>();
        bool sucesso;
        if (connectivity.offline) {
          final sync = Get.find<SyncManager>();
          await sync.enfileirarDeslocar(os.id, latitude!, longitude!, adminId: adminSelecionadoId);
          sucesso = true;
        } else {
          sucesso = await controller.deslocarParaOS(os.id, latitude!, longitude!, adminId: adminSelecionadoId);
        }
        if (sucesso) {
          setState(() { statusAtual = 'em_deslocamento'; osIniciada = false; });
          final tracking = Get.find<TrackingService>();
          tracking.iniciar(os.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('🚗 Deslocamento iniciado! ${adminSelecionadoNome ?? "Admin"} será notificado.'),
              backgroundColor: const Color(0xFF00FF88),
              duration: const Duration(seconds: 3),
            ));
          }
        } else {
          if (mounted) _mostrarErro('Erro ao iniciar deslocamento');
        }
        return;
      }
      if (statusAtual == 'em_deslocamento') {
        if (Get.isRegistered<TrackingService>()) Get.find<TrackingService>().parar();
        final connectivity = Get.find<ConnectivityService>();
        bool sucesso;
        if (connectivity.offline) {
          final sync = Get.find<SyncManager>();
          await sync.enfileirarChegar(os.id, latitude!, longitude!);
          sucesso = true;
        } else {
          sucesso = await controller.chegarAoLocal(os.id, latitude!, longitude!);
        }
        if (!sucesso) { if (mounted) _mostrarErro('Erro ao informar chegada'); return; }
        if (!mounted) return;
        final aprConcluido = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AprScreen(os: os)));
        if (aprConcluido == true) {
          setState(() { statusAtual = 'em_execucao'; osIniciada = true; _etapaAtual = 1; });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ APR concluído! Preencha os dados do atendimento.'),
            backgroundColor: Color(0xFF00FF88), duration: Duration(seconds: 2),
          ));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ O APR é obrigatório para continuar o atendimento.'),
            backgroundColor: Colors.orange, duration: Duration(seconds: 3),
          ));
        }
        return;
      }
      if (statusAtual == 'em_execucao') setState(() { osIniciada = true; _etapaAtual = 1; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _selecionarAdmin() async {
    await controller.carregarAdmins();
    final admins = controller.adminsDisponiveis;
    if (admins.isEmpty) return true;
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.orange, size: 32),
                ),
                const SizedBox(height: 12),
                const Text('Selecione o Responsável',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Escolha qual administrador vai acompanhar este atendimento',
                    style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ...admins.map((admin) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, admin),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withOpacity(0.12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.admin_panel_settings_rounded,
                                color: Colors.orange, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(admin['nome'] ?? '',
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 14, fontWeight: FontWeight.w600)),
                                if (admin['email'] != null &&
                                    !admin['email'].toString().endsWith('@seenet.local'))
                                  Text(admin['email'],
                                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                        ],
                      ),
                    ),
                  ),
                )),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Pular (sem acompanhamento)',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (resultado != null) {
      adminSelecionadoId = resultado['id'];
      adminSelecionadoNome = resultado['nome'];
    }
    return true;
  }

  Future<void> _finalizarOS() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Finalizar OS?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Os dados serão enviados para o IXC. Confirma?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _isLoading = true);
    try {
      final dados = {
        'latitude': latitude, 'longitude': longitude,
        'onu_modelo': onuModeloController.text.trim(),
        'onu_serial': onuSerialController.text.trim(),
        'onu_status': onuStatusController.text.trim(),
        'onu_sinal_optico': onuSinalController.text.trim().isNotEmpty
            ? double.tryParse(onuSinalController.text.trim()) : null,
        'relato_problema': relatoProblemaController.text.trim(),
        'relato_solucao': relatoSolucaoController.text.trim(),
        'materiais_utilizados': materiaisController.text.trim(),
        'itens_estoque': itensEstoque.map((item) => {
          'id_produto': item.produto.id,
          'descricao': item.produto.descricao,
          'quantidade': item.quantidade,
          'valor_unitario': item.valorUnitario,
          'valor_total': item.valorTotal,
          'id_patrimonio': item.patrimonio?.id ?? '0',
          'numero_serie': item.patrimonio?.serial ?? '',
          'numero_patrimonial': item.patrimonio?.numeroPatrimonial ?? '',
          'tipo_produto': item.isPatrimonio ? 'P' : 'O',
        }).toList(),
        'observacoes': observacoesController.text.trim(),
        'fotos': fotosAnexadas.map((anexo) => {
          'tipo': anexo.tipo, 'descricao': anexo.descricao, 'path': anexo.foto.path,
        }).toList(),
        'assinatura': base64Encode(assinaturaBytes!),
      };
      final connectivity = Get.find<ConnectivityService>();
      bool sucesso;
      if (connectivity.offline) {
        final sync = Get.find<SyncManager>();
        await sync.enfileirarFinalizarOS(os.id, dados);
        sucesso = true;
      } else {
        sucesso = await controller.finalizarExecucao(os.id, dados);
      }
      if (sucesso && mounted) {
        final msg = connectivity.offline
            ? '📥 OS salva localmente — será enviada quando voltar o sinal'
            : '✓ OS finalizada com sucesso!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: connectivity.offline ? Colors.orange : const Color(0xFF00FF88),
        ));
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao finalizar OS'), backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildEtapaAtual()),
          _buildBotoesNavegacao(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final corPrioridade = os.corPrioridade;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 16, left: 16, right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            corPrioridade,
            corPrioridade.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OS #${os.numeroOs}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(_getNomeEtapa(_etapaAtual),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              // Indicadores de etapa
              Row(
                children: List.generate(_totalEtapas, (i) {
                  final concluida = i < _etapaAtual;
                  final atual = i == _etapaAtual;
                  return Container(
                    width: atual ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: concluida || atual
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de progresso
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_etapaAtual + 1) / _totalEtapas,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF00FF88)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${_etapaAtual + 1}/$_totalEtapas',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotoesNavegacao() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          if (_etapaAtual > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _etapaAtual--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Anterior',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _proximaEtapa,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading
                    ? Colors.grey.shade700
                    : (_etapaAtual == 0 && statusAtual == 'em_deslocamento'
                    ? Colors.orange
                    : const Color(0xFF00FF88)),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
                  : Text(
                _etapaAtual == 0
                    ? (statusAtual == 'pendente'
                    ? '🚗 Iniciar Deslocamento'
                    : statusAtual == 'em_deslocamento'
                    ? '📍 Cheguei ao Local'
                    : 'Próximo')
                    : (_etapaAtual == _totalEtapas - 1
                    ? 'Finalizar OS'
                    : 'Próximo'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets visuais ──────────────────────────────────────────

  Widget _buildTituloEtapa({
    required IconData icone,
    required String titulo,
    required String descricao,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF88).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF00FF88).withOpacity(0.2)),
          ),
          child: Icon(icone, color: const Color(0xFF00FF88), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text(descricao,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: child,
    );
  }

  Widget _buildResumoCard({
    required String titulo,
    required IconData icone,
    required String conteudo,
    required int editarEtapa,
  }) {
    final ok = !conteudo.contains('✗') && !conteudo.contains('Não');
    final cor = ok ? const Color(0xFF00FF88) : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icone, color: cor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(conteudo,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _etapaAtual = editarEtapa),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Color(0xFF00FF88), size: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF00FF88), width: 1.5)),
      ),
    );
  }

  Widget _buildInfoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}