// lib/ordem_de_servico/screens/executar_os_wizard_screen.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) '../../utils/io_stub.dart';
import 'dart:typed_data';
import '../../services/connectivity_service.dart';
import '../../services/sync_manager.dart';
import '../../services/tracking_service.dart';
import '../../services/estoque_service.dart';
import 'dart:convert';
import '../../controllers/ordem_servico_controller.dart';
import '../../services/ordem_servico_service.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/localizacao_widget.dart';
import '../widgets/qr_scanner_widget.dart';
import 'package:get_storage/get_storage.dart';
import '../widgets/anexos_widget.dart';
import '../widgets/historico_endereco_widget.dart';
import '../widgets/fachada_foto_widget.dart';
import '../widgets/os_cliente_info.dart';
import '../widgets/materiais_estoque_widget.dart';
import '../widgets/assinatura_widget.dart';
import '../widgets/campo_com_voz.dart';
import 'dart:async';
import 'apr_screen.dart';

class ExecutarOSWizardScreen extends StatefulWidget {
  const ExecutarOSWizardScreen({super.key});

  @override
  State<ExecutarOSWizardScreen> createState() => _ExecutarOSWizardScreenState();
}

class _ExecutarOSWizardScreenState extends State<ExecutarOSWizardScreen>
    with WidgetsBindingObserver {
  final OrdemServicoController controller = Get.find<OrdemServicoController>();
  final OrdemServicoService _osService = OrdemServicoService();
  late OrdemServico os;

  // Carregando o rascunho do SERVIDOR (outro técnico reagendou/encaminhou com
  // dados). Enquanto true, mostra spinner — as etapas só nascem depois que os
  // dados iniciais (fotos/itens/assinatura) estão prontos (o IndexedStack cria
  // os widgets filhos no 1º build, então precisam já ter o valor certo).
  bool _carregandoRascunho = false;

  int _etapaAtual = 0;
  final int _totalEtapas = 8;

  final TextEditingController onuModeloController = TextEditingController();
  final TextEditingController onuSerialController = TextEditingController();
  final TextEditingController onuMacController = TextEditingController();
  final TextEditingController onuStatusController = TextEditingController();
  final TextEditingController onuSinalController = TextEditingController();
  final TextEditingController relatoProblemaController = TextEditingController();
  final TextEditingController relatoSolucaoController = TextEditingController();
  final TextEditingController materiaisController = TextEditingController();
  List<ItemOS> itensEstoque = [];
  final TextEditingController observacoesController = TextEditingController();

  double? latitude;
  double? longitude;
  double? latitudeFinal;  // ✅ localização capturada NA FINALIZAÇÃO (prova de conclusão no local)
  double? longitudeFinal;
  bool _capturandoFinal = false; // capturando a localização de finalização (botão único)
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
    WidgetsBinding.instance.addObserver(this); // salva progresso ao minimizar/fechar
    // Restaura fotos/assinatura/materiais AGORA (antes do 1º build) — o IndexedStack
    // cria os widgets no primeiro build, então precisam já ter o valor inicial.
    _restaurarBinarios();

    // Sem progresso LOCAL desta OS? Pode existir um rascunho no SERVIDOR (outro
    // técnico reagendou/encaminhou → o local foi limpo). Só nesse caso gastamos um
    // GET (com spinner) — pra OS nova/continuando no mesmo aparelho, usa o local.
    final temProgressoLocal =
        GetStorage().read('wizard_progress_${os.id}') != null;
    if (!temProgressoLocal && os.tipoOs != 'E') {
      _carregandoRascunho = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final osAtualizada = controller.ordensServico
          .firstWhereOrNull((o) => o.id == os.id);
      if (osAtualizada != null) {
        setState(() {
          os = osAtualizada;
          // ✅ Sincroniza statusAtual com o status real do banco
          if (os.status == 'em_deslocamento' && statusAtual == 'pendente') {
            statusAtual = 'em_deslocamento';
          } else if (os.status == 'em_execucao') {
            statusAtual = 'em_execucao';
            osIniciada = true;
            _etapaAtual = 1;
          }
        });
      }

      // Carrega o rascunho do servidor ANTES de tudo (se aplicável), pra os
      // widgets filhos nascerem já com fotos/itens/assinatura corretos.
      if (_carregandoRascunho) {
        await _carregarRascunhoServidor();
      } else {
        _restaurarProgresso();
      }

      if (os.status == 'em_execucao' && _exigeApr) {
        // ✅ Se o APR já foi CONCLUÍDO nesta OS (marca local), NÃO re-força ao reabrir —
        // volta pro passo do wizard onde parou. Antes, o verificarAPR só olhava o
        // SERVIDOR; um APR concluído OFFLINE (ainda não sincronizado) reabria o APR
        // toda vez (e vazio, pois o rascunho é limpo ao concluir).
        final aprLocalOk = GetStorage().read('apr_concluido_${os.id}') == true;
        final aprOk = aprLocalOk || await controller.verificarAPR(os.id);
        if (!aprOk && mounted) {
          final resultado = await Navigator.push<bool>(
              context, MaterialPageRoute(builder: (_) => AprScreen(os: os)));
          if (resultado == true && mounted) {
            GetStorage().write('apr_concluido_${os.id}', true);
            setState(() { _etapaAtual = 1; });
          }
        }
      }

      if (os.status == 'pendente' || os.status == 'reaberta') {
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
    onuMacController.dispose();
    onuStatusController.dispose();
    onuSinalController.dispose();
    relatoProblemaController.dispose();
    relatoSolucaoController.dispose();
    materiaisController.dispose();
    observacoesController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ Salva o progresso quando o app vai pro fundo (minimizar/fechar/trocar de app)
  // — assim o técnico NÃO perde MAC/serial/relato se sair no meio da OS.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _salvarProgresso();
    }
    super.didChangeAppLifecycleState(state);
  }

  // APR obrigatória só para estes assuntos (MESMA regra do backend em finalizarExecucao).
  // Nos demais assuntos a OS segue normal, sem passar pela tela da APR.
  static const Set<String> _assuntosComApr = {'60', '4', '32'};
  bool get _exigeApr => _assuntosComApr.contains(os.idAssunto);

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

  Widget _buildEtapaLocalizacao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(icone: Icons.location_on_rounded, titulo: 'Localização', descricao: 'Confirme ou capture a localização do atendimento'),
          const SizedBox(height: 20),
          // Mesmos dados do OS card (login/senha copiáveis, plano, CTO, endereço
          // completo, Limpar MAC).
          _buildCard(child: OSClienteInfo(os: os, mostrarNome: true)),
          // Atalhos: WhatsApp + Ligar + abrir a localização no Google Maps.
          if (_temTelefone || _temEndereco) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_temTelefone) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirWhatsapp(os.clienteTelefone!),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('WhatsApp',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _ligarCliente(os.clienteTelefone!),
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: const Text('Ligar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00FF88),
                        side: const BorderSide(color: Color(0xFF00FF88)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                if (_temTelefone && _temEndereco) const SizedBox(width: 8),
                if (_temEndereco)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirMapa(os.clienteEndereco!),
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text('Mapa',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B9EFF),
                        side: const BorderSide(color: Color(0xFF3B9EFF)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          HistoricoEnderecoWidget(osId: os.id),
          const SizedBox(height: 12),
          // Aqui é SÓ VISUALIZAR a foto da fachada (ajuda a achar a casa). Tirar a
          // foto fica no passo "Fotos", que só aparece depois de "Cheguei ao Local".
          FachadaFotoWidget(osId: os.id, podeCapturar: false),
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
          // Foto da FACHADA (frente da casa) — agora aqui, pois o técnico já chegou
          // ao local. Fica registrada pro próximo que pegar este cliente achar a casa.
          FachadaFotoWidget(osId: os.id, podeCapturar: true),
          const SizedBox(height: 12),
          _buildCard(child: AnexosWidget(
            anexosIniciais: fotosAnexadas,
            onAnexosAlterados: (anexos) {
              setState(() { fotosAnexadas = anexos; });
              _salvarProgresso();
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
              CampoComVoz(controller: onuMacController, label: 'MAC da ONU', hint: 'Ex: 6E:9F:4A:...'),
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
            itensIniciais: itensEstoque,
            onItensAlterados: (itens) {
              setState(() {
                itensEstoque = itens;
                materiaisController.text = itens.map((i) =>
                '${i.produto.descricao} x${i.quantidade.toStringAsFixed(0)} (R\$${i.valorTotal.toStringAsFixed(2)})').join('\n');
              });
              _salvarProgresso();
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
            assinaturaInicial: assinaturaBytes,
            onAssinaturaSalva: (assinatura) {
              setState(() { assinaturaBytes = assinatura; });
              _salvarProgresso();
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
          const SizedBox(height: 20),
          // ✅ Localização de FINALIZAÇÃO: captura o GPS na hora de finalizar
          // (prova de que o técnico terminou no local do cliente). Auto-captura
          // ao abrir esta etapa se a permissão já estiver liberada.
          _buildTituloEtapa(icone: Icons.where_to_vote_rounded,
              titulo: 'Localização de finalização',
              descricao: 'Confirme onde você está terminando o atendimento'),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (latitudeFinal != null && longitudeFinal != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF00FF88), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Localização capturada\n${latitudeFinal!.toStringAsFixed(6)}, ${longitudeFinal!.toStringAsFixed(6)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Toque para capturar sua localização atual — obrigatório para finalizar.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed:
                      _capturandoFinal ? null : _capturarLocalizacaoFinal,
                  icon: _capturandoFinal
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Icon(
                          latitudeFinal != null
                              ? Icons.refresh_rounded
                              : Icons.my_location_rounded,
                          color: Colors.black,
                          size: 18),
                  label: Text(
                    latitudeFinal != null
                        ? 'Capturar novamente'
                        : 'Capturar localização',
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Captura ÚNICA da localização de finalização (um toque, SEM auto-atualizar).
  // Obrigatória pra finalizar (prova de que o técnico terminou no local).
  Future<void> _capturarLocalizacaoFinal() async {
    setState(() => _capturandoFinal = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _mostrarErro('Permissão negada. Habilite nas configurações.');
        }
        await Geolocator.openAppSettings();
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (mounted) _mostrarErro('Permissão de localização necessária.');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) _mostrarErro('GPS desativado. Ative o GPS.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          latitudeFinal = pos.latitude;
          longitudeFinal = pos.longitude;
        });
      }
    } catch (_) {
      if (mounted) _mostrarErro('Não foi possível capturar a localização');
    } finally {
      if (mounted) setState(() => _capturandoFinal = false);
    }
  }

  // ✅ Salvar progresso do wizard no GetStorage
  void _salvarProgresso() {
    GetStorage().write('wizard_progress_${os.id}', {
      'etapa':         _etapaAtual,
      'statusAtual':   statusAtual,
      'adminId':       adminSelecionadoId,
      'adminNome':     adminSelecionadoNome,
      'latitude':      latitude,   // ✅ persiste a localização capturada (não perde ao reabrir)
      'longitude':     longitude,
      'latitudeFinal':  latitudeFinal,
      'longitudeFinal': longitudeFinal,
      'onuModelo':     onuModeloController.text,
      'onuSerial':     onuSerialController.text,
      'onuMac':        onuMacController.text,
      'onuStatus':     onuStatusController.text,
      'onuSinal':      onuSinalController.text,
      'relatoProblema': relatoProblemaController.text,
      'relatoSolucao':  relatoSolucaoController.text,
      'materiais':     materiaisController.text,
      'observacoes':   observacoesController.text,
      // ✅ Binários/estruturados — pro técnico NÃO perder se fechar/matar o app.
      // Fotos: guarda o caminho (funciona no celular; no web o path é blob e morre
      // no reload). Assinatura: base64. Itens: JSON serializado.
      'fotos': fotosAnexadas
          .map((a) => {'path': a.foto.path, 'descricao': a.descricao, 'tipo': a.tipo})
          .toList(),
      'assinatura': assinaturaBytes != null ? base64Encode(assinaturaBytes!) : null,
      'itens': itensEstoque.map((i) => i.toJson()).toList(),
    });
  }

  // Restaura fotos/assinatura/itens do GetStorage (chamado no initState, síncrono).
  void _restaurarBinarios() {
    final dados = GetStorage().read<Map>('wizard_progress_${os.id}');
    if (dados == null) return;
    if (os.status != 'em_execucao' && os.status != 'em_deslocamento') return;

    // Fotos — só no mobile (no web o caminho vira inválido após reload).
    if (!kIsWeb && dados['fotos'] is List) {
      try {
        fotosAnexadas = (dados['fotos'] as List).map((f) {
          final m = Map<String, dynamic>.from(f);
          return AnexoComDescricao(
            foto: XFile(m['path'] as String),
            descricao: (m['descricao'] ?? '') as String,
            tipo: (m['tipo'] ?? 'foto') as String,
          );
        }).toList();
      } catch (_) {}
    }

    // Assinatura (base64 → bytes)
    if (dados['assinatura'] is String) {
      try { assinaturaBytes = base64Decode(dados['assinatura'] as String); } catch (_) {}
    }

    // Itens de estoque (JSON → ItemOS) + texto de materiais
    if (dados['itens'] is List) {
      try {
        itensEstoque = (dados['itens'] as List)
            .map((j) => ItemOS.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        materiaisController.text = itensEstoque.map((i) =>
            '${i.produto.descricao} x${i.quantidade.toStringAsFixed(0)} (R\$${i.valorTotal.toStringAsFixed(2)})').join('\n');
      } catch (_) {}
    }
  }

  // ✅ Restaurar progresso salvo
  void _restaurarProgresso() {
    final dados = GetStorage().read<Map>('wizard_progress_${os.id}');
    if (dados == null) return;
    if (os.status != 'em_execucao' && os.status != 'em_deslocamento') return;

    setState(() {
      final etapa = dados['etapa'] as int? ?? 0;
      if (etapa > 0) _etapaAtual = etapa;

      onuModeloController.text     = dados['onuModelo']     ?? '';
      onuSerialController.text     = dados['onuSerial']     ?? '';
      onuMacController.text        = dados['onuMac']        ?? '';
      onuStatusController.text     = dados['onuStatus']     ?? '';
      onuSinalController.text      = dados['onuSinal']      ?? '';
      relatoProblemaController.text = dados['relatoProblema'] ?? '';
      relatoSolucaoController.text  = dados['relatoSolucao']  ?? '';
      materiaisController.text     = dados['materiais']     ?? '';
      observacoesController.text   = dados['observacoes']   ?? '';

      if (dados['adminId'] != null) {
        adminSelecionadoId   = dados['adminId']   as int?;
        adminSelecionadoNome = dados['adminNome'] as String?;
      }
      // ✅ restaura a localização já capturada (mostra "Localização Capturada" ao voltar)
      if (dados['latitude'] != null) latitude = (dados['latitude'] as num).toDouble();
      if (dados['longitude'] != null) longitude = (dados['longitude'] as num).toDouble();
      if (dados['latitudeFinal'] != null) latitudeFinal = (dados['latitudeFinal'] as num).toDouble();
      if (dados['longitudeFinal'] != null) longitudeFinal = (dados['longitudeFinal'] as num).toDouble();
    });

    print('✅ Progresso do wizard restaurado — etapa ${_etapaAtual + 1}');
  }

  // ✅ Limpar progresso ao finalizar com sucesso
  void _limparProgresso() {
    GetStorage().remove('wizard_progress_${os.id}');
    // Backend já apaga o rascunho do servidor no finalizar; garante mesmo assim.
    _osService.limparRascunho(os.id);
  }

  // Limpa TODO o progresso LOCAL desta OS (usado ao reagendar/encaminhar: a OS
  // deixa este técnico; se voltar, o servidor é a fonte da verdade).
  void _limparProgressoLocalCompleto() {
    final s = GetStorage();
    s.remove('wizard_progress_${os.id}');
    s.remove('apr_rascunho_${os.id}');
    s.remove('apr_concluido_${os.id}');
  }

  // 💾 Salva TODO o estado do wizard no SERVIDOR (fotos em base64 pra funcionar
  // entre aparelhos diferentes). Usado ao reagendar/encaminhar → o próximo
  // técnico continua com tudo. Retorna true se salvou.
  Future<bool> _salvarRascunhoServidor() async {
    final fotosB64 = <Map<String, dynamic>>[];
    for (final a in fotosAnexadas) {
      try {
        final bytes = await a.foto.readAsBytes();
        fotosB64.add({
          'base64': base64Encode(bytes),
          'descricao': a.descricao,
          'tipo': a.tipo,
        });
      } catch (_) {}
    }
    final dados = <String, dynamic>{
      'etapa': _etapaAtual,
      'statusAtual': statusAtual,
      'adminId': adminSelecionadoId,
      'adminNome': adminSelecionadoNome,
      'latitude': latitude,
      'longitude': longitude,
      'latitudeFinal': latitudeFinal,
      'longitudeFinal': longitudeFinal,
      'onuModelo': onuModeloController.text,
      'onuSerial': onuSerialController.text,
      'onuMac': onuMacController.text,
      'onuStatus': onuStatusController.text,
      'onuSinal': onuSinalController.text,
      'relatoProblema': relatoProblemaController.text,
      'relatoSolucao': relatoSolucaoController.text,
      'materiais': materiaisController.text,
      'observacoes': observacoesController.text,
      'fotos': fotosB64,
      'assinatura': assinaturaBytes != null ? base64Encode(assinaturaBytes!) : null,
      'itens': itensEstoque.map((i) => i.toJson()).toList(),
      'aprRascunho': GetStorage().read('apr_rascunho_${os.id}'),
    };
    final ok = await _osService.salvarRascunho(os.id, dados);
    print('💾 [RASCUNHO] OS ${os.id} salvar → ${ok ? "OK" : "FALHOU"} '
        '(${fotosB64.length} fotos, ${itensEstoque.length} itens, '
        'assinatura=${assinaturaBytes != null})');
    return ok;
  }

  // 📥 Carrega o rascunho do servidor (outro técnico deixou dados) e aplica.
  // Se o servidor não tiver, cai no progresso LOCAL (mesmo aparelho/técnico).
  Future<void> _carregarRascunhoServidor() async {
    try {
      final dados = await _osService.buscarRascunho(os.id);
      print('📥 [RASCUNHO] OS ${os.id} → servidor '
          '${dados == null ? "VAZIO" : "OK (${dados.keys.length} chaves, "
              "${(dados['fotos'] as List?)?.length ?? 0} fotos, "
              "${(dados['itens'] as List?)?.length ?? 0} itens)"}');
      if (dados != null && mounted) {
        await _aplicarDadosRascunho(dados);
      } else {
        _restaurarProgresso(); // sem rascunho no servidor → usa o local
      }
    } catch (e) {
      print('❌ [RASCUNHO] erro ao carregar: $e');
      _restaurarProgresso();
    }
    if (mounted) setState(() => _carregandoRascunho = false);
  }

  // Aplica os dados do rascunho do servidor no estado. Fotos: no MOBILE são
  // gravadas em arquivo temporário (path válido → exibe E finaliza igual às fotos
  // do picker); no WEB viram XFile em memória (blob). NÃO aplica a 'etapa' — quem
  // assume começa pelo passo natural do status; o que importa é preservar os DADOS.
  Future<void> _aplicarDadosRascunho(Map dados) async {
    onuModeloController.text     = dados['onuModelo']     ?? '';
    onuSerialController.text     = dados['onuSerial']     ?? '';
    onuMacController.text        = dados['onuMac']        ?? '';
    onuStatusController.text     = dados['onuStatus']     ?? '';
    onuSinalController.text      = dados['onuSinal']      ?? '';
    relatoProblemaController.text = dados['relatoProblema'] ?? '';
    relatoSolucaoController.text  = dados['relatoSolucao']  ?? '';
    materiaisController.text     = dados['materiais']     ?? '';
    observacoesController.text   = dados['observacoes']   ?? '';

    if (dados['adminId'] != null) {
      adminSelecionadoId   = dados['adminId']   as int?;
      adminSelecionadoNome = dados['adminNome'] as String?;
    }
    if (dados['latitude'] != null) latitude = (dados['latitude'] as num).toDouble();
    if (dados['longitude'] != null) longitude = (dados['longitude'] as num).toDouble();
    if (dados['latitudeFinal'] != null) latitudeFinal = (dados['latitudeFinal'] as num).toDouble();
    if (dados['longitudeFinal'] != null) longitudeFinal = (dados['longitudeFinal'] as num).toDouble();

    if (dados['fotos'] is List) {
      final novas = <AnexoComDescricao>[];
      // dynamic (não Directory?): no build WEB o `Directory` do import condicional
      // vira um stub diferente do Directory real que o path_provider devolve —
      // dynamic evita esse choque de tipo em tempo de compilação (o bloco só roda
      // de fato no !kIsWeb, então isso nunca é executado no web).
      dynamic tmpDir;
      if (!kIsWeb) {
        try { tmpDir = await getTemporaryDirectory(); } catch (_) {}
      }
      int i = 0;
      for (final f in (dados['fotos'] as List)) {
        try {
          final m = Map<String, dynamic>.from(f);
          final bytes = base64Decode(m['base64'] as String);
          XFile xf;
          if (kIsWeb || tmpDir == null) {
            xf = XFile.fromData(bytes, name: 'foto.jpg', mimeType: 'image/jpeg');
          } else {
            final p =
                '${tmpDir.path}/rascunho_${os.id}_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
            await File(p).writeAsBytes(bytes);
            xf = XFile(p);
          }
          novas.add(AnexoComDescricao(
            foto: xf,
            descricao: (m['descricao'] ?? '') as String,
            tipo: (m['tipo'] ?? 'foto') as String,
          ));
          i++;
        } catch (_) {}
      }
      fotosAnexadas = novas;
    }
    if (dados['assinatura'] is String) {
      try { assinaturaBytes = base64Decode(dados['assinatura'] as String); } catch (_) {}
    }
    if (dados['itens'] is List) {
      try {
        itensEstoque = (dados['itens'] as List)
            .map((j) => ItemOS.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      } catch (_) {}
    }
    if (dados['aprRascunho'] != null) {
      try { GetStorage().write('apr_rascunho_${os.id}', dados['aprRascunho']); } catch (_) {}
    }
  }

  void _proximaEtapa() {
    if (_isLoading) return;
    if (!_validarEtapaAtual()) return;
    if (_etapaAtual == 0 && !osIniciada) { _iniciarOS(); return; }
    if (_etapaAtual == _totalEtapas - 1) { _finalizarOS(); return; }
    setState(() => _etapaAtual++);
    _salvarProgresso(); // ✅ Salva após cada avanço de etapa
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
          // ✅ Atualiza os objeto local com dados frescos do controller
          final osAtualizada = controller.ordensServico
              .firstWhereOrNull((o) => o.id == os.id);
          setState(() {
            statusAtual = 'em_deslocamento';
            osIniciada = false;
            if (osAtualizada != null) os = osAtualizada;
          });
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
        // ✅ Chegou ao local: NÃO para mais o tracking — muda pro modo ECONÔMICO.
        // O admin continua vendo o técnico no mapa durante toda a execução,
        // mas o GPS gasta uma fração da bateria (precisão média, envio ~60s).
        if (Get.isRegistered<TrackingService>()) {
          Get.find<TrackingService>().modoEconomico();
        }
        if (!mounted) return;
        // APR só é obrigatória para alguns assuntos (mesma regra do backend). Nos
        // demais, a chegada ao local vai DIRETO pra execução, sem abrir a APR.
        if (!_exigeApr) {
          setState(() { statusAtual = 'em_execucao'; osIniciada = true; _etapaAtual = 1; });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Chegada confirmada! Preencha os dados do atendimento.'),
            backgroundColor: Color(0xFF00FF88), duration: Duration(seconds: 2),
          ));
          return;
        }
        final aprConcluido = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AprScreen(os: os)));
        if (aprConcluido == true) {
          GetStorage().write('apr_concluido_${os.id}', true); // ✅ não re-força ao reabrir
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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

  // Tem telefone/endereço do cliente? (pros atalhos Ligar/Localização)
  bool get _temTelefone =>
      os.clienteTelefone != null && os.clienteTelefone!.trim().isNotEmpty;
  bool get _temEndereco =>
      os.clienteEndereco != null && os.clienteEndereco!.trim().isNotEmpty;

  // Abre o discador do celular com o número do cliente já preenchido
  // (funciona no Android e no iPhone, sem copiar/colar).
  Future<void> _ligarCliente(String telefone) async {
    final numero = telefone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (numero.isEmpty) {
      _mostrarErro('Telefone inválido');
      return;
    }
    final uri = Uri.parse('tel:$numero');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) _mostrarErro('Não foi possível abrir o discador');
    } catch (_) {
      if (mounted) _mostrarErro('Não foi possível abrir o discador');
    }
  }

  // Abre a conversa do WhatsApp com o número do cliente (wa.me). Adiciona o
  // código do Brasil (55) quando o número vem só com DDD + número.
  Future<void> _abrirWhatsapp(String telefone) async {
    var numero = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.isEmpty) {
      _mostrarErro('Telefone inválido');
      return;
    }
    if (!numero.startsWith('55') && numero.length <= 11) {
      numero = '55$numero';
    }
    final uri = Uri.parse('https://wa.me/$numero');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _mostrarErro('Não foi possível abrir o WhatsApp');
    } catch (_) {
      if (mounted) _mostrarErro('Não foi possível abrir o WhatsApp');
    }
  }

  // Abre o Google Maps buscando pelo endereço do cliente (iOS e Android).
  Future<void> _abrirMapa(String endereco) async {
    final query = Uri.encodeComponent(endereco);
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _mostrarErro('Não foi possível abrir o mapa');
    } catch (_) {
      if (mounted) _mostrarErro('Não foi possível abrir o mapa');
    }
  }

  // Encaminhar: escolhe um técnico da empresa e passa a OS pra ele.
  // A OS some da minha lista e aparece pra ele.
  Future<void> _encaminharOS() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> tecnicos;
    try {
      tecnicos = await controller.buscarTecnicos();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (!mounted) return;
    if (tecnicos.isEmpty) {
      _mostrarErro('Nenhum técnico disponível para encaminhar');
      return;
    }

    final escolhido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Encaminhar para',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('A OS sai da sua lista e vai para o técnico escolhido.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tecnicos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t = tecnicos[i];
                  final nome = (t['nome'] ?? 'Técnico').toString();
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(ctx, t),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                const Color(0xFF3B9EFF).withOpacity(0.15),
                            child: Text(
                              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Color(0xFF3B9EFF),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(nome,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (escolhido == null || escolhido['id'] == null) return;
    if (!mounted) return;
    final tecnicoId = escolhido['id'];
    final nomeTec = (escolhido['nome'] ?? 'técnico').toString();

    // Motivo obrigatório → vai pro campo "Mensagem" do encaminhamento no IXC.
    final motivoCtrl =
        TextEditingController(text: 'Encaminhada para $nomeTec');
    String? erroMotivo;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Encaminhar para $nomeTec?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Motivo *',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: motivoCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Descreva o motivo do encaminhamento',
                  hintStyle: const TextStyle(color: Colors.white38),
                  errorText: erroMotivo,
                  filled: true,
                  fillColor: const Color(0xFF111111),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (motivoCtrl.text.trim().isEmpty) {
                  setStateDialog(() => erroMotivo = 'Informe o motivo');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B9EFF)),
              child: const Text('Encaminhar',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      // 💾 Preserva TODO o progresso no servidor pro técnico que vai receber.
      final okRascunho = await _salvarRascunhoServidor();
      if (!okRascunho && mounted) {
        _mostrarErro('Aviso: não consegui salvar todo o progresso p/ o próximo técnico.');
      }
      // Para o rastreamento — não é mais a minha OS.
      if (Get.isRegistered<TrackingService>()) {
        Get.find<TrackingService>().parar();
      }
      final sucesso = await controller.encaminharOS(
        os.id,
        tecnicoId is int ? tecnicoId : int.parse(tecnicoId.toString()),
        motivo: motivoCtrl.text.trim(),
      );
      if (sucesso) {
        _limparProgressoLocalCompleto(); // a OS deixa este técnico
        if (mounted) Get.back(); // volta pra lista de OS
      } else {
        if (mounted) _mostrarErro('Erro ao encaminhar');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Reagendar: cliente não estava no local. Confirma (+ motivo opcional),
  // para o tracking, manda pro backend (IXC vira RAG) e volta pra lista.
  Future<void> _reagendarOS() async {
    final motivoCtrl =
        TextEditingController(text: 'Cliente não estava em casa');
    String? erroMotivo;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reagendar OS?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Use quando o cliente não estava no local. A OS volta para "Aguardando Agendamento" e você fica livre para a próxima.',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 14),
              const Text('Motivo *',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: motivoCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Descreva o motivo do reagendamento',
                  hintStyle: const TextStyle(color: Colors.white38),
                  errorText: erroMotivo,
                  filled: true,
                  fillColor: const Color(0xFF111111),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (motivoCtrl.text.trim().isEmpty) {
                  setStateDialog(() => erroMotivo = 'Informe o motivo');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Reagendar',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      // 💾 Preserva TODO o progresso no servidor — quando esta OS for reagendada
      // e alguém pegar de novo, continua exatamente de onde parou.
      final okRascunho = await _salvarRascunhoServidor();
      if (!okRascunho && mounted) {
        _mostrarErro('Aviso: não consegui salvar todo o progresso da OS.');
      }
      // Para o rastreamento GPS — o técnico não está mais atendendo esta OS.
      if (Get.isRegistered<TrackingService>()) {
        Get.find<TrackingService>().parar();
      }
      final sucesso = await controller.reagendarOS(
        os.id,
        latitude ?? 0,
        longitude ?? 0,
        motivo: motivoCtrl.text.trim(),
      );
      if (sucesso) {
        _limparProgressoLocalCompleto(); // a OS deixa este técnico
        if (mounted) Get.back(); // volta pra lista de OS
      } else {
        if (mounted) _mostrarErro('Erro ao reagendar');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📋 Checklist de fechamento da INSTALAÇÃO FTTH (só assunto 60).
  // Retorna o mapa preenchido ou null se o técnico cancelar (aí NÃO finaliza).
  Future<Map<String, dynamic>?> _coletarChecklistInstalacao() async {
    final atendidoCtrl = TextEditingController();
    bool acessoRemoto = true;
    bool senhaPadrao = true;
    bool ipv6 = true;
    bool clienteAssina = true;
    String? erroAtendido;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          Widget simNao(String titulo, bool valor, ValueChanged<bool> onChange) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final opt in const [true, false])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onChange(opt),
                            child: Container(
                              margin: EdgeInsets.only(right: opt ? 8 : 0),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: valor == opt
                                    ? (opt
                                        ? const Color(0xFF00FF88)
                                            .withOpacity(0.15)
                                        : Colors.red.withOpacity(0.15))
                                    : const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: valor == opt
                                        ? (opt
                                            ? const Color(0xFF00FF88)
                                            : Colors.red)
                                        : Colors.white12),
                              ),
                              child: Center(
                                child: Text(
                                  opt ? 'SIM' : 'NÃO',
                                  style: TextStyle(
                                    color: valor == opt
                                        ? (opt
                                            ? const Color(0xFF00FF88)
                                            : Colors.red)
                                        : Colors.white38,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Fechamento da instalação',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1 - Atendido por *',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: atendidoCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nome de quem atendeu',
                      hintStyle: const TextStyle(color: Colors.white38),
                      errorText: erroAtendido,
                      filled: true,
                      fillColor: const Color(0xFF111111),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  simNao('4 - Habilitou acesso remoto?', acessoRemoto,
                      (v) => setStateDialog(() => acessoRemoto = v)),
                  simNao('5 - Mudou senha padrão?', senhaPadrao,
                      (v) => setStateDialog(() => senhaPadrao = v)),
                  simNao('6 - Ativou IPv6?', ipv6,
                      (v) => setStateDialog(() => ipv6 = v)),
                  simNao('7 - Cliente assina?', clienteAssina,
                      (v) => setStateDialog(() => clienteAssina = v)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (atendidoCtrl.text.trim().isEmpty) {
                    setStateDialog(
                        () => erroAtendido = 'Informe quem atendeu');
                    return;
                  }
                  Navigator.pop(ctx, {
                    'atendido_por': atendidoCtrl.text.trim(),
                    'acesso_remoto': acessoRemoto,
                    'senha_padrao': senhaPadrao,
                    'ipv6': ipv6,
                    'cliente_assina': clienteAssina,
                  });
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88)),
                child: const Text('Confirmar',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 📋 Decisão de fechamento das OS de COBRANÇA (só assunto 90).
  // Retorna o id_proxima_tarefa escolhido, ou null se o técnico cancelar
  // (aí NÃO finaliza — igual ao checklist da instalação).
  static const List<Map<String, String>> _opcoesProximaTarefa = [
    {'id': '40', 'label': 'Negociar débitos com cliente'},
    {'id': '41', 'label': 'Recepcionar equipamentos'},
    {'id': '43', 'label': 'Cancelar contrato por inadimplência'},
  ];

  Future<String?> _coletarProximaTarefaCobranca() async {
    String? selecionado;
    bool tentouConfirmar = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Decisão da OS de cobrança',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Próxima tarefa *',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final opt in _opcoesProximaTarefa)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setStateDialog(() => selecionado = opt['id']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selecionado == opt['id']
                            ? const Color(0xFF00FF88).withOpacity(0.12)
                            : const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selecionado == opt['id']
                                ? const Color(0xFF00FF88)
                                : Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selecionado == opt['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selecionado == opt['id']
                                ? const Color(0xFF00FF88)
                                : Colors.white38,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(opt['label']!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (tentouConfirmar && selecionado == null)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Selecione uma opção',
                      style: TextStyle(color: Colors.red, fontSize: 11)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selecionado == null) {
                  setStateDialog(() => tentouConfirmar = true);
                  return;
                }
                Navigator.pop(ctx, selecionado);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88)),
              child: const Text('Confirmar',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalizarOS() async {
    // Localização de finalização é OBRIGATÓRIA (prova de conclusão no local do cliente).
    if (latitudeFinal == null || longitudeFinal == null) {
      _mostrarErro('Capture a localização de finalização antes de finalizar a OS.');
      return;
    }

    // 📋 Instalação FTTH (assunto 60): checklist de fechamento OBRIGATÓRIO antes
    // de finalizar de fato. Se cancelar, não finaliza.
    Map<String, dynamic>? checklistInstalacao;
    if (os.idAssunto == '60') {
      checklistInstalacao = await _coletarChecklistInstalacao();
      if (checklistInstalacao == null) return;
    }

    // 📋 OS de cobrança (assunto 90): escolha OBRIGATÓRIA da próxima tarefa
    // antes de finalizar. Se cancelar, não finaliza.
    String? idProximaTarefa;
    if (os.idAssunto == '90') {
      idProximaTarefa = await _coletarProximaTarefaCobranca();
      if (idProximaTarefa == null) return;
    }

    // Se o checklist de instalação ou a decisão de cobrança já foram
    // preenchidos, isso já É a confirmação → pula o diálogo genérico.
    if (checklistInstalacao == null && idProximaTarefa == null) {
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
    }

    setState(() => _isLoading = true);

    // ✅ Mostrar dialog de progresso
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _FinalizacaoProgressDialog(),
      );
    }

    try {
      final dados = {
        'latitude': latitude, 'longitude': longitude,
        'latitude_final': latitudeFinal, 'longitude_final': longitudeFinal,
        'onu_modelo':    onuModeloController.text.trim(),
        'onu_serial':    onuSerialController.text.trim(),
        'onu_status':    onuStatusController.text.trim(),
        'onu_mac':       onuMacController.text.trim(),
        'onu_sinal_optico': onuSinalController.text.trim().isNotEmpty
            ? double.tryParse(onuSinalController.text.trim()) : null,
        'relato_problema': relatoProblemaController.text.trim(),
        'relato_solucao':  relatoSolucaoController.text.trim(),
        'materiais_utilizados': materiaisController.text.trim(),
        'itens_estoque': itensEstoque.map((item) => {
          'id_produto':          item.produto.id,
          'descricao':           item.produto.descricao,
          'quantidade':          item.quantidade,
          'valor_unitario':      item.valorUnitario,
          'valor_total':         item.valorTotal,
          'id_patrimonio':       item.patrimonio?.id ?? '0',
          'numero_serie':        item.patrimonio?.serial ?? '',
          'numero_patrimonial':  item.patrimonio?.numeroPatrimonial ?? '',
          'mac':                 item.patrimonio?.mac ?? '',
          // almox ONDE o patrimônio está → o comodato tem que sair de lá (senão
          // o IXC diz "Patrimônio está indisponível").
          'id_almoxarifado':     item.patrimonio?.idAlmoxarifado ?? '',
          'tipo_produto':        item.isPatrimonio ? 'P' : 'O',
        }).toList(),
        'observacoes': observacoesController.text.trim(),
        'fotos': fotosAnexadas.map((anexo) => {
          'tipo': anexo.tipo, 'descricao': anexo.descricao, 'path': anexo.foto.path,
        }).toList(),
        'assinatura': base64Encode(assinaturaBytes!),
      };

      // 📋 Checklist da instalação FTTH (assunto 60) — vai pro IXC (mensagem +
      // arquivo) e diferencia o fechamento "modo completo".
      if (checklistInstalacao != null) {
        dados['checklist_instalacao'] = checklistInstalacao;
      }

      // 📋 Decisão da OS de cobrança (assunto 90) → id_proxima_tarefa no IXC.
      if (idProximaTarefa != null) {
        dados['id_proxima_tarefa'] = idProximaTarefa;
      }

      final connectivity = Get.find<ConnectivityService>();
      bool sucesso;

      if (connectivity.offline) {
        final sync = Get.find<SyncManager>();
        await sync.enfileirarFinalizarOS(os.id, dados);
        sucesso = true;
      } else {
        sucesso = await controller.finalizarExecucao(os.id, dados);
      }

      // ✅ Fechar dialog de progresso
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // OS encerrada → para o rastreamento (o pino do técnico sai do mapa do admin).
      if (sucesso && Get.isRegistered<TrackingService>()) {
        Get.find<TrackingService>().parar();
      }

      if (sucesso && mounted) {
        _limparProgresso(); // ✅ Limpar progresso salvo
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
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Enquanto carrega o rascunho do servidor (outro técnico deixou dados),
    // mostra spinner — as etapas só nascem depois pra já virem com fotos/itens.
    if (_carregandoRascunho) {
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF00FF88)),
              SizedBox(height: 16),
              Text('Carregando dados salvos da OS...',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          _buildHeader(),
          // IndexedStack mantém TODAS as etapas vivas (não recria ao navegar) —
          // assim fotos, materiais/patrimônios e assinatura NÃO somem ao voltar
          // uma etapa nem ao avançar. Antes cada etapa era recriada vazia.
          Expanded(
            child: IndexedStack(
              sizing: StackFit.expand,
              index: _etapaAtual,
              children: [
                _buildEtapaLocalizacao(),
                _buildEtapaAnexos(),
                _buildEtapaDadosONU(),
                _buildEtapaRelatos(),
                _buildEtapaMateriais(),
                _buildEtapaObservacoes(),
                _buildEtapaAssinatura(),
                _buildEtapaRevisao(),
              ],
            ),
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botão "Reagendar" (cliente ausente): só na etapa 0 e com o técnico
          // em campo (deslocamento/execução). Fica ao lado do "Cheguei ao Local".
          if ((_etapaAtual == 0 || _etapaAtual == _totalEtapas - 1) &&
              (statusAtual == 'em_deslocamento' ||
                  statusAtual == 'em_execucao'))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _reagendarOS,
                      icon: const Icon(Icons.event_busy_rounded, size: 18),
                      label: const Text('Reagendar',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _encaminharOS,
                      icon: const Icon(Icons.forward_to_inbox_rounded,
                          size: 18),
                      label: const Text('Encaminhar',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF3B9EFF),
                        side: const BorderSide(color: Color(0xFF3B9EFF)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
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

}

class _FinalizacaoProgressDialog extends StatefulWidget {
  const _FinalizacaoProgressDialog();

  @override
  State<_FinalizacaoProgressDialog> createState() =>
      _FinalizacaoProgressDialogState();
}

class _FinalizacaoProgressDialogState
    extends State<_FinalizacaoProgressDialog> {
  int _stepAtual = 0;
  Timer? _timer;

  static const _steps = [
    (Icons.save_rounded,       '💾 Salvando dados...'),
    (Icons.picture_as_pdf,     '📄 Gerando PDF APR...'),
    (Icons.picture_as_pdf,     '📄 Gerando PDF OS...'),
    (Icons.cloud_upload_rounded,'🔗 Conectando ao IXC...'),
    (Icons.inventory_2_rounded, '📦 Enviando materiais...'),
    (Icons.check_rounded,       '✅ Finalizando OS...'),
    (Icons.photo_camera_rounded,'📸 Enviando fotos e PDFs...'),
  ];

  @override
  void initState() {
    super.initState();
    // Avança um passo a cada ~3.5s (total ~24s para 7 etapas)
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_stepAtual < _steps.length - 1) {
        setState(() => _stepAtual++);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 52, height: 52,
              child: CircularProgressIndicator(
                  color: Color(0xFF00FF88), strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            const Text('Finalizando OS',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Aguarde, isso pode levar alguns segundos...',
                style: TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ...List.generate(_steps.length, (i) {
              final done    = i < _stepAtual;
              final current = i == _stepAtual;
              final cor = done
                  ? const Color(0xFF00FF88)
                  : current ? Colors.orange : Colors.white24;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(children: [
                  Icon(
                    done
                        ? Icons.check_circle_rounded
                        : current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off_rounded,
                    color: cor, size: 17,
                  ),
                  const SizedBox(width: 10),
                  Text(_steps[i].$2,
                      style: TextStyle(color: cor, fontSize: 13)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}