import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../../controllers/ordem_servico_controller.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/localizacao_widget.dart';
import '../widgets/anexos_widget.dart';
import '../widgets/assinatura_widget.dart';
import 'package:intl/intl.dart';

class ExecutarOSWizardScreen extends StatefulWidget {
  const ExecutarOSWizardScreen({super.key});

  @override
  State<ExecutarOSWizardScreen> createState() => _ExecutarOSWizardScreenState();
}

class _ExecutarOSWizardScreenState extends State<ExecutarOSWizardScreen> {
  final OrdemServicoController controller = Get.find<OrdemServicoController>();
  late OrdemServico os;

  // Controle de etapas
  int _etapaAtual = 0;
  final int _totalEtapas = 8;

  // Controllers
  final TextEditingController onuModeloController = TextEditingController();
  final TextEditingController onuSerialController = TextEditingController();
  final TextEditingController onuStatusController = TextEditingController();
  final TextEditingController onuSinalController = TextEditingController();
  final TextEditingController relatoProblemaController = TextEditingController();
  final TextEditingController relatoSolucaoController = TextEditingController();
  final TextEditingController materiaisController = TextEditingController();
  final TextEditingController observacoesController = TextEditingController();

  // Dados coletados
  double? latitude;
  double? longitude;
  List<String> fotosAnexadas = [];
  Uint8List? assinaturaBytes;
  bool osIniciada = false;
  String statusAtual = 'pendente';

  @override
  void initState() {
    super.initState();
    os = Get.arguments as OrdemServico;

    // Determinar estado inicial baseado no status
    if (os.status == 'em_execucao') {
      osIniciada = true;
      _etapaAtual = 1; // Já pode preencher formulário
    } else if (os.status == 'em_deslocamento') {
      osIniciada = false;
      _etapaAtual = 0; // Precisa informar chegada
    } else {
      osIniciada = false;
      _etapaAtual = 0; // Precisa iniciar deslocamento
    }

    // Se já tem GPS salvo, usar
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
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
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
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00FF88),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_etapaAtual + 1}/$_totalEtapas',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
                if (os.clienteEndereco != null)
                  _buildInfoRow('Endereço', os.clienteEndereco!),
                if (os.clienteTelefone != null)
                  _buildInfoRow('Telefone', os.clienteTelefone!),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCard(
            child: LocalizacaoWidget(
              onLocalizacaoCapturada: (lat, lng) {
                setState(() {
                  latitude = lat;
                  longitude = lng;
                });
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
                setState(() {
                  // Extrair apenas os caminhos das fotos
                  fotosAnexadas = anexos.map((a) => a.foto.path).toList();
                });
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
                _buildTextField(
                  controller: onuModeloController,
                  label: 'Modelo da ONU',
                  hint: 'Ex: AN5506-04-F',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: onuSerialController,
                  label: 'Serial da ONU',
                  hint: 'Ex: HWTC12345678',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: onuStatusController,
                  label: 'Status',
                  hint: 'Ex: Online',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: onuSinalController,
                  label: 'Sinal Óptico (dBm)',
                  hint: 'Ex: -24.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                _buildTextField(
                  controller: relatoProblemaController,
                  label: 'Problema Identificado *',
                  hint: 'Descreva o problema encontrado...',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: relatoSolucaoController,
                  label: 'Solução Aplicada *',
                  hint: 'Descreva a solução aplicada...',
                  maxLines: 4,
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
            descricao: 'Liste os materiais e equipamentos utilizados',
          ),
          const SizedBox(height: 24),
          _buildCard(
            child: _buildTextField(
              controller: materiaisController,
              label: 'Materiais',
              hint: 'Ex: 20m de cabo de rede, 2 conectores RJ45...',
              maxLines: 5,
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
            child: _buildTextField(
              controller: observacoesController,
              label: 'Observações',
              hint: 'Detalhes adicionais, dificuldades encontradas...',
              maxLines: 6,
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
                setState(() {
                  assinaturaBytes = assinatura;
                });
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

          // Localização
          _buildResumoCard(
            titulo: 'Localização',
            icone: Icons.location_on,
            conteudo: latitude != null && longitude != null
                ? 'Lat: ${latitude!.toStringAsFixed(6)}\nLng: ${longitude!.toStringAsFixed(6)}'
                : 'Não capturada',
            editarEtapa: 0,
          ),

          // Fotos
          _buildResumoCard(
            titulo: 'Fotos',
            icone: Icons.camera_alt,
            conteudo: '${fotosAnexadas.length} foto(s) anexada(s)',
            editarEtapa: 1,
          ),

          // Dados ONU
          if (onuModeloController.text.isNotEmpty)
            _buildResumoCard(
              titulo: 'Dados da ONU',
              icone: Icons.router,
              conteudo: 'Modelo: ${onuModeloController.text}',
              editarEtapa: 2,
            ),

          // Relatos
          _buildResumoCard(
            titulo: 'Relatos',
            icone: Icons.description,
            conteudo: relatoProblemaController.text.length > 50
                ? '${relatoProblemaController.text.substring(0, 50)}...'
                : relatoProblemaController.text,
            editarEtapa: 3,
          ),

          // Materiais
          if (materiaisController.text.isNotEmpty)
            _buildResumoCard(
              titulo: 'Materiais',
              icone: Icons.build,
              conteudo: materiaisController.text.length > 50
                  ? '${materiaisController.text.substring(0, 50)}...'
                  : materiaisController.text,
              editarEtapa: 4,
            ),

          // Assinatura
          _buildResumoCard(
            titulo: 'Assinatura',
            icone: Icons.draw,
            conteudo: assinaturaBytes != null ? '✓ Confirmada' : '✗ Não assinada',
            editarEtapa: 6,
          ),
        ],
      ),
    );
  }
  Widget _buildTituloEtapa({
    required IconData icone,
    required String titulo,
    required String descricao,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, color: const Color(0xFF00FF88), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          descricao,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
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

  Widget _buildResumoCard({
    required String titulo,
    required IconData icone,
    required String conteudo,
    required int editarEtapa,
  }) {
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
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  conteudo,
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF00FF88)),
            onPressed: () {
              setState(() {
                _etapaAtual = editarEtapa;
              });
            },
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2),
        ),
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
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildBotoesNavegacao() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_etapaAtual > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _etapaAtual--;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Anterior',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          if (_etapaAtual > 0) const SizedBox(width: 12),

          Expanded(
            flex: _etapaAtual == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _proximaEtapa,
              style: ElevatedButton.styleFrom(
                backgroundColor: _etapaAtual == 0 && statusAtual == 'em_deslocamento'
                    ? Colors.orange
                    : const Color(0xFF00FF88),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
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
    if (!_validarEtapaAtual()) {
      return;
    }

    // Última etapa = iniciar execução ou finalizar
    if (_etapaAtual == 0 && !osIniciada) {
      _iniciarOS();
      return;
    }

    if (_etapaAtual == _totalEtapas - 1) {
      _finalizarOS();
      return;
    }

    setState(() {
      _etapaAtual++;
    });
  }

  bool _validarEtapaAtual() {
    switch (_etapaAtual) {
      case 0: // Localização
        if (latitude == null || longitude == null) {
          _mostrarErro('Capture a localização antes de prosseguir');
          return false;
        }
        return true;

      case 1: // Anexos (opcional)
        return true;

      case 2: // Dados ONU (opcional)
        return true;

      case 3: // Relatos
        if (relatoProblemaController.text.trim().isEmpty) {
          _mostrarErro('Descreva o problema identificado');
          return false;
        }
        if (relatoSolucaoController.text.trim().isEmpty) {
          _mostrarErro('Descreva a solução aplicada');
          return false;
        }
        return true;

      case 4: // Materiais (opcional)
        return true;

      case 5: // Observações (opcional)
        return true;

      case 6: // Assinatura
        if (assinaturaBytes == null) {
          _mostrarErro('Solicite a assinatura do cliente');
          return false;
        }
        return true;

      case 7: // Revisão
        return true;

      default:
        return true;
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _iniciarOS() async {
    // ESTADO 1: Pendente → Iniciar Deslocamento
    if (statusAtual == 'pendente') {
      print('🚗 Iniciando deslocamento...');

      final sucesso = await controller.deslocarParaOS(os.id, latitude!, longitude!);

      if (sucesso) {
        setState(() {
          statusAtual = 'em_deslocamento'; // ✅ CORRETO
          osIniciada = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚗 Deslocamento iniciado! Dirija com segurança.'),
              backgroundColor: Color(0xFF00FF88),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao iniciar deslocamento'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // ESTADO 2: Em Deslocamento → Chegar ao Local
    if (statusAtual == 'em_deslocamento') {
      print('📍 Informando chegada ao local...');

      final sucesso = await controller.chegarAoLocal(os.id, latitude!, longitude!);

      if (sucesso) {
        setState(() {
          statusAtual = 'em_execucao'; // ✅ CORRETO
          osIniciada = true;
          _etapaAtual = 1;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Chegou ao local! Preencha os dados do atendimento.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao informar chegada'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // ESTADO 3: Já está em execução - só avançar
    if (statusAtual == 'em_execucao') {
      setState(() {
        osIniciada = true;
        _etapaAtual = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Execução já iniciada!'),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _finalizarOS() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Finalizar OS?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Os dados serão enviados para o IXC. Confirma?',
          style: TextStyle(color: Colors.white70),
        ),
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
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

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
      'observacoes': observacoesController.text.trim(),
      'fotos': fotosAnexadas,
      'assinatura': base64Encode(assinaturaBytes!),
    };

    final sucesso = await controller.finalizarExecucao(os.id, dados);

    if (sucesso && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ OS finalizada com sucesso!'),
          backgroundColor: Color(0xFF00FF88),
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao finalizar OS'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}