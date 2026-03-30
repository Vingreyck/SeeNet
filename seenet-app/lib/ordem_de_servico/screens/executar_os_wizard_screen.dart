// lib/ordem_de_servico/screens/executar_os_wizard_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import '../../services/tracking_service.dart';
import 'dart:convert';
import '../../controllers/ordem_servico_controller.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/localizacao_widget.dart';
import '../widgets/anexos_widget.dart';
import '../../services/estoque_service.dart';
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
  int? adminSelecionadoId;   // ✅ NOVO: Admin escolhido para acompanhar
  String? adminSelecionadoNome;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    os = Get.arguments as OrdemServico;

    if (os.status == 'em_execucao') {
      osIniciada = true;
      _etapaAtual = 1;
    } else if (os.status == 'em_deslocamento') {
      osIniciada = false;
      _etapaAtual = 0;
      statusAtual = 'em_deslocamento'; // ✅ FIX BÔNUS: sincronizar statusAtual
    } else {
      osIniciada = false;
      _etapaAtual = 0;
      statusAtual = 'pendente';
    }

    if (os.latitude != null && os.longitude != null) {
      latitude = os.latitude;
      longitude = os.longitude;
    }

    // ✅ NOVO: Mostrar seleção de admin ao abrir a tela (só se OS for pendente)
    if (os.status == 'pendente') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await controller.carregarAdmins();
        if (mounted) {
          await _selecionarAdmin();
        }
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
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
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 15,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            os.corPrioridade,
            os.corPrioridade.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OS #${os.numeroOs}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _getNomeEtapa(_etapaAtual),
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_etapaAtual + 1) / _totalEtapas,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_etapaAtual + 1}/$_totalEtapas',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
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

  // ETAPA 0: Localização
  Widget _buildEtapaLocalizacao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.location_on,
            titulo: 'Localização',
            descricao: 'Confirme ou capture a localização do atendimento',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Cliente', os.clienteNome),
                if (os.clienteEndereco != null) _buildInfoRow('Endereço', os.clienteEndereco!),
                if (os.clienteTelefone != null) _buildInfoRow('Telefone', os.clienteTelefone!),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            child: LocalizacaoWidget(
              onLocalizacaoCapturada: (lat, lng) {
                setState(() { latitude = lat; longitude = lng; });
              },
              latitudeInicial: latitude,
              longitudeInicial: longitude,
            ),
          ),
        ],
      ),
    );
  }

  // ETAPA 1: Anexos
  Widget _buildEtapaAnexos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.camera_alt,
            titulo: 'Fotos do Local',
            descricao: 'Tire fotos do roteador, ONU, local e equipamentos',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: AnexosWidget(
              onAnexosAlterados: (anexos) {
                setState(() { fotosAnexadas = anexos; });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ETAPA 2: Dados ONU
  Widget _buildEtapaDadosONU() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.router,
            titulo: 'Dados da ONU',
            descricao: 'Informações técnicas do equipamento (opcional)',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: Column(
              children: [
                CampoComVoz(
                  controller: onuModeloController,
                  label: 'Modelo da ONU',
                  hint: 'Ex: AN5506-04-F',
                ),
                const SizedBox(height: 16),
                CampoComVoz(
                  controller: onuSerialController,
                  label: 'Serial da ONU',
                  hint: 'Ex: HWTC12345678',
                ),
                const SizedBox(height: 16),
                CampoComVoz(
                  controller: onuStatusController,
                  label: 'Status',
                  hint: 'Ex: Online',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: onuSinalController,
                  label: 'Sinal Óptico (dBm)',
                  hint: 'Ex: -24.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ETAPA 3: Relatos
  Widget _buildEtapaRelatos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.description,
            titulo: 'Relatos',
            descricao: 'Descreva o problema e a solução aplicada',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: Column(
              children: [
                CampoComVoz(
                  controller: relatoProblemaController,
                  label: 'Problema Identificado *',
                  hint: 'Descreva o problema encontrado...',
                  maxLines: 4,
                  appendMode: true,
                ),
                const SizedBox(height: 16),
                CampoComVoz(
                  controller: relatoSolucaoController,
                  label: 'Solução Aplicada *',
                  hint: 'Descreva a solução aplicada...',
                  maxLines: 4,
                  appendMode: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ETAPA 4: Materiais
  Widget _buildEtapaMateriais() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.build,
            titulo: 'Materiais Utilizados',
            descricao: 'Selecione os materiais e equipamentos do estoque',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: MateriaisEstoqueWidget(
              osIdExterno: os.idExterno ?? '',
              onItensAlterados: (itens) {
                setState(() {
                  itensEstoque = itens;
                  materiaisController.text = itens.map((i) =>
                  '${i.produto.descricao} x${i.quantidade.toStringAsFixed(0)} (R\$${i.valorTotal.toStringAsFixed(2)})'
                  ).join('\n');
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ETAPA 5: Observações
  Widget _buildEtapaObservacoes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.notes,
            titulo: 'Observações',
            descricao: 'Informações adicionais sobre o atendimento',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: CampoComVoz(
              controller: observacoesController,
              label: 'Observações',
              hint: 'Detalhes adicionais, dificuldades encontradas...',
              maxLines: 6,
              appendMode: true,
            ),
          ),
        ],
      ),
    );
  }

  // ETAPA 6: Assinatura
  Widget _buildEtapaAssinatura() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.draw,
            titulo: 'Assinatura do Cliente',
            descricao: 'Solicite a assinatura do cliente no campo abaixo',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: AssinaturaWidget(
              onAssinaturaSalva: (assinatura) {
                setState(() { assinaturaBytes = assinatura; });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ETAPA 7: Revisão
  Widget _buildEtapaRevisao() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTituloEtapa(
            icone: Icons.check_circle,
            titulo: 'Revisão Final',
            descricao: 'Confira todas as informações antes de finalizar',
          ),
          const SizedBox(height: 24),
          _buildResumoCard(titulo: 'Localização', icone: Icons.location_on, conteudo: latitude != null ? 'Lat: ${latitude!.toStringAsFixed(6)}\nLng: ${longitude!.toStringAsFixed(6)}' : 'Não capturada', editarEtapa: 0),
          _buildResumoCard(titulo: 'Fotos', icone: Icons.camera_alt, conteudo: '${fotosAnexadas.length} foto(s) anexada(s)', editarEtapa: 1),
          if (onuModeloController.text.isNotEmpty)
            _buildResumoCard(titulo: 'Dados da ONU', icone: Icons.router, conteudo: 'Modelo: ${onuModeloController.text}', editarEtapa: 2),
          _buildResumoCard(
            titulo: 'Relatos', icone: Icons.description,
            conteudo: relatoProblemaController.text.length > 50 ? '${relatoProblemaController.text.substring(0, 50)}...' : relatoProblemaController.text,
            editarEtapa: 3,
          ),
          _buildResumoCard(
            titulo: 'Materiais',
            icone: Icons.build,
            conteudo: itensEstoque.isNotEmpty
                ? '${itensEstoque.length} item(ns) - R\$ ${itensEstoque.fold<double>(0, (s, i) => s + i.valorTotal).toStringAsFixed(2)}'
                : 'Nenhum material adicionado',
            editarEtapa: 4,
          ),
          _buildResumoCard(titulo: 'Assinatura', icone: Icons.draw, conteudo: assinaturaBytes != null ? '✓ Confirmada' : '✗ Não assinada', editarEtapa: 6),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // WIDGETS REUTILIZÁVEIS
  // ──────────────────────────────────────────────

  Widget _buildTituloEtapa({required IconData icone, required String titulo, required String descricao}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, color: const Color(0xFF00FF88), size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 8),
        Text(descricao, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _buildResumoCard({required String titulo, required IconData icone, required String conteudo, required int editarEtapa}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icone, color: const Color(0xFF00FF88)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(conteudo, style: const TextStyle(color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF00FF88)),
            onPressed: () => setState(() => _etapaAtual = editarEtapa),
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
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2)),
      ),
    );
  }

  Widget _buildInfoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label:', style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Expanded(child: Text(valor, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // BOTÕES DE NAVEGAÇÃO
  // ──────────────────────────────────────────────

  Widget _buildBotoesNavegacao() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          if (_etapaAtual > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _etapaAtual--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Anterior', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          if (_etapaAtual > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _proximaEtapa, // ✅ desabilita durante loading
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading
                    ? Colors.grey.shade700 // ✅ cinza quando carregando
                    : (_etapaAtual == 0 && statusAtual == 'em_deslocamento'
                    ? Colors.orange
                    : const Color(0xFF00FF88)),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isLoading
                  ? const SizedBox( // ✅ spinner no lugar do texto
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
                  : Text(
                _etapaAtual == 0
                    ? (statusAtual == 'pendente'
                    ? '🚗 Iniciar Deslocamento'
                    : statusAtual == 'em_deslocamento'
                    ? '📍 Cheguei ao Local'
                    : 'Próximo')
                    : (_etapaAtual == _totalEtapas - 1 ? 'Finalizar OS' : 'Próximo'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _proximaEtapa() {
    if (_isLoading) return; // ✅ Bloqueia duplo toque
    if (!_validarEtapaAtual()) return;

    if (_etapaAtual == 0 && !osIniciada) {
      _iniciarOS();
      return;
    }

    if (_etapaAtual == _totalEtapas - 1) {
      _finalizarOS();
      return;
    }

    setState(() => _etapaAtual++);
  }

  bool _validarEtapaAtual() {
    switch (_etapaAtual) {
      case 0:
        if (latitude == null || longitude == null) {
          _mostrarErro('Capture a localização antes de prosseguir');
          return false;
        }
        return true;
      case 3:
        if (relatoProblemaController.text.trim().isEmpty) { _mostrarErro('Descreva o problema identificado'); return false; }
        if (relatoSolucaoController.text.trim().isEmpty) { _mostrarErro('Descreva a solução aplicada'); return false; }
        return true;
      case 6:
        if (assinaturaBytes == null) { _mostrarErro('Solicite a assinatura do cliente'); return false; }
        return true;
      default:
        return true;
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
    setState(() => _isLoading = true); // ✅ trava o botão
    try {

      if (statusAtual == 'pendente') {
        if (adminSelecionadoId == null) {
          final selecionou = await _selecionarAdmin();
          if (!selecionou) return;
        }

        final sucesso = await controller.deslocarParaOS(
          os.id, latitude!, longitude!,
          adminId: adminSelecionadoId,
        );

        if (sucesso) {
          setState(() {
            statusAtual = 'em_deslocamento';
            osIniciada = false;
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
        if (Get.isRegistered<TrackingService>()) {
          final tracking = Get.find<TrackingService>();
          tracking.parar();
        }

        final sucesso = await controller.chegarAoLocal(os.id, latitude!, longitude!);

        if (!sucesso) {
          if (mounted) _mostrarErro('Erro ao informar chegada');
          return;
        }

        if (!mounted) return;
        final aprConcluido = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => AprScreen(os: os)),
        );

        if (aprConcluido == true) {
          setState(() {
            statusAtual = 'em_execucao';
            osIniciada = true;
            _etapaAtual = 1;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ APR concluído! Preencha os dados do atendimento.'),
              backgroundColor: Color(0xFF00FF88),
              duration: Duration(seconds: 2),
            ));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('⚠️ O APR é obrigatório para continuar o atendimento.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ));
          }
        }
        return;
      }

      if (statusAtual == 'em_execucao') {
        setState(() {
          osIniciada = true;
          _etapaAtual = 1;
        });
      }

    } finally {
      if (mounted) setState(() => _isLoading = false); // ✅ libera sempre
    }
  }

  /// Mostra bottom sheet para técnico selecionar qual admin vai acompanhar
  Future<bool> _selecionarAdmin() async {
    await controller.carregarAdmins();
    final admins = controller.adminsDisponiveis;

    if (admins.isEmpty) {
      return true;
    }

    // Mostrar seleção
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.admin_panel_settings, color: Color(0xFF00FF88), size: 40),
              const SizedBox(height: 12),
              const Text(
                'Selecione o Responsável',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Escolha qual administrador vai acompanhar este atendimento',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ...admins.map((admin) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.pop(context, admin),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.orange.withOpacity(0.3),
                          child: const Icon(Icons.admin_panel_settings,
                              color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                admin['nome'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (admin['email'] != null &&
                                  !admin['email'].toString().endsWith('@seenet.local'))
                                Text(
                                  admin['email'],
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text(
                  'Pular (sem acompanhamento)',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (resultado != null) {
      adminSelecionadoId = resultado['id'];
      adminSelecionadoNome = resultado['nome'];
      return true;
    }

    // Se clicou "Pular", continua sem admin
    return true;
  }

  Future<void> _finalizarOS() async {
    // ⚠️ dialog ANTES de ativar o loading (não bloqueia o cancelar)
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Finalizar OS?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Os dados serão enviados para o IXC. Confirma?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true); // ✅ trava o botão só depois de confirmar
    try {

      final dados = {
        'latitude': latitude,
        'longitude': longitude,
        'onu_modelo': onuModeloController.text.trim(),
        'onu_serial': onuSerialController.text.trim(),
        'onu_status': onuStatusController.text.trim(),
        'onu_sinal_optico': onuSinalController.text.trim().isNotEmpty
            ? double.tryParse(onuSinalController.text.trim())
            : null,
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
          'tipo': anexo.tipo,
          'descricao': anexo.descricao,
          'path': anexo.foto.path,
        }).toList(),
        'assinatura': base64Encode(assinaturaBytes!),
      };

      final sucesso = await controller.finalizarExecucao(os.id, dados);

      if (sucesso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ OS finalizada com sucesso!'),
          backgroundColor: Color(0xFF00FF88),
        ));
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao finalizar OS'),
          backgroundColor: Colors.red,
        ));
      }

    } finally {
      if (mounted) setState(() => _isLoading = false); // ✅ libera sempre
    }
  }
}