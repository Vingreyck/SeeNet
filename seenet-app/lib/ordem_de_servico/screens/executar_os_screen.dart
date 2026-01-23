import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:typed_data';  // ✅ ADICIONAR
import 'dart:convert';     // ✅ ADICIONAR
import '../../controllers/ordem_servico_controller.dart';
import '../../models/ordem_servico_model.dart';
import '../widgets/localizacao_widget.dart';
import '../widgets/anexos_widget.dart';
import '../widgets/assinatura_widget.dart';  // ✅ ADICIONAR (criar depois)
import 'package:intl/intl.dart';

class ExecutarOSScreen extends StatefulWidget {
  const ExecutarOSScreen({super.key});

  @override
  State<ExecutarOSScreen> createState() => _ExecutarOSScreenState();
}

class _ExecutarOSScreenState extends State<ExecutarOSScreen> {
  final OrdemServicoController controller = Get.find<OrdemServicoController>();
  late OrdemServico os;

  // Controllers dos formulários
  final TextEditingController onuModeloController = TextEditingController();
  final TextEditingController onuSerialController = TextEditingController();
  final TextEditingController onuStatusController = TextEditingController();
  final TextEditingController onuSinalController = TextEditingController();
  final TextEditingController relatoProblemaController = TextEditingController();
  final TextEditingController relatoSolucaoController = TextEditingController();
  final TextEditingController materiaisController = TextEditingController();
  final TextEditingController observacoesController = TextEditingController();

  // Estado
  double? latitude;
  double? longitude;
  List<String> fotosAnexadas = [];
  bool osIniciada = false;
  String statusAtual = 'pendente';
  Uint8List? _assinaturaBytes;

  @override
  void initState() {
    super.initState();
    os = Get.arguments as OrdemServico;
    osIniciada = os.status == 'em_execucao';
    statusAtual = os.status;

    // Preencher dados existentes se houver
    if (os.onuModelo != null) onuModeloController.text = os.onuModelo!;
    if (os.onuSerial != null) onuSerialController.text = os.onuSerial!;
    if (os.onuStatus != null) onuStatusController.text = os.onuStatus!;
    if (os.onuSinalOptico != null) onuSinalController.text = os.onuSinalOptico.toString();
    if (os.materiaisUtilizados != null) materiaisController.text = os.materiaisUtilizados!;
    if (os.observacoes != null) observacoesController.text = os.observacoes!;
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
    relatoProblemaController.dispose();    // ✅ ADICIONAR
    relatoSolucaoController.dispose();     // ✅ ADICIONAR
    materiaisController.dispose();
    observacoesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          // ✅ HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 100,
            child: Container(
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
                  stops: const [0.32, 1.0],
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'OS #${os.numeroOs}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            os.status == 'em_execucao' ? 'Em Execução' : 'Pendente',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(os.iconeStatus, color: Colors.white, size: 32),
                ],
              ),
            ),
          ),

          // ✅ CONTEÚDO
          Positioned(
            top: MediaQuery.of(context).padding.top + 120,
            left: 0,
            right: 0,
            bottom: 80, // Espaço para o botão
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ INFO DO CLIENTE
                  _buildSecao(
                    titulo: 'Informações do Cliente',
                    icone: Icons.person,
                    child: Column(
                      children: [
                        _buildInfoRow('Nome', os.clienteNome),
                        if (os.clienteEndereco != null)
                          _buildInfoRow('Endereço', os.clienteEndereco!),
                        if (os.clienteTelefone != null)
                          _buildInfoRow('Telefone', os.clienteTelefone!),
                        _buildInfoRow('Tipo de Serviço', os.tipoServico),
                        _buildInfoRow(
                          'Data de Abertura',
                          os.dataAbertura != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(os.dataAbertura!)
                              : 'Sem data',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ LOCALIZAÇÃO
                  _buildSecao(
                    titulo: 'Localização',
                    icone: Icons.location_on,
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

                  const SizedBox(height: 20),

                  // ✅ DADOS DA ONU (OPCIONAL)
                  _buildSecao(
                    titulo: 'Dados da ONU (Opcional)',
                    icone: Icons.router,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: onuModeloController,
                          label: 'Modelo da ONU',
                          hint: 'Ex: AN5506-04-F',
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: onuSerialController,
                          label: 'Serial da ONU',
                          hint: 'Ex: HWTC12345678',
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: onuStatusController,
                          label: 'Status',
                          hint: 'Ex: Online',
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: onuSinalController,
                          label: 'Sinal Óptico (dBm)',
                          hint: 'Ex: -24.5',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ RELATOS (OBRIGATÓRIO)
                  _buildSecao(
                    titulo: 'Relatos (Obrigatório)',
                    icone: Icons.description,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: relatoProblemaController,
                          label: 'Problema Identificado *',
                          hint: 'Descreva o problema encontrado...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: relatoSolucaoController,
                          label: 'Solução Aplicada *',
                          hint: 'Descreva a solução aplicada...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ ANEXOS (FOTOS)
                  _buildSecao(
                    titulo: 'Fotos do Local',
                    icone: Icons.camera_alt,
                    child: AnexosWidget(
                      onAnexosAlterados: (anexos) {
                        setState(() {
                          // Extrair apenas os caminhos das fotos
                          fotosAnexadas = anexos.map((a) => a.foto.path).toList();
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ MATERIAIS UTILIZADOS
                  _buildSecao(
                    titulo: 'Materiais Utilizados',
                    icone: Icons.build,
                    child: _buildTextField(
                      controller: materiaisController,
                      label: 'Materiais',
                      hint: 'Ex: 20m de cabo de rede, 2 conectores RJ45',
                      maxLines: 3,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ OBSERVAÇÕES
                  _buildSecao(
                    titulo: 'Observações',
                    icone: Icons.notes,
                    child: _buildTextField(
                      controller: observacoesController,
                      label: 'Observações',
                      hint: 'Descreva o que foi feito, problemas encontrados, etc.',
                      maxLines: 5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (osIniciada)
                    _buildSecao(
                      titulo: 'Assinatura do Cliente',
                      icone: Icons.draw,
                      child: AssinaturaWidget(
                        onAssinaturaSalva: (assinatura) {
                          setState(() {
                            _assinaturaBytes = assinatura;
                          });
                        },
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ✅ BOTÃO FLUTUANTE
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
              child: osIniciada
                  ? _buildBotaoFinalizar()
                  : _buildBotaoAcao(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecao({
    required String titulo,
    required IconData icone,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: const Color(0xFF00FF88), size: 24),
              const SizedBox(width: 12),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
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

  Widget _buildBotaoAcao() {
    // Estado 1: Pendente → Botão Deslocamento
    if (statusAtual == 'pendente') {
      return ElevatedButton.icon(
        onPressed: _iniciarDeslocamento,
        icon: const Icon(Icons.directions_car, color: Colors.black, size: 28),
        label: const Text(
          '🚗 Iniciar Deslocamento',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF88),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      );
    }

    // Estado 2: Em Deslocamento → Botão Chegada
    if (statusAtual == 'em_deslocamento') {
      return ElevatedButton.icon(
        onPressed: _chegarAoLocal,
        icon: const Icon(Icons.location_on, color: Colors.black, size: 28),
        label: const Text(
          '📍 Cheguei ao Local',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      );
    }

    // Estado 3: Em Execução → Botão Finalizar
    if (statusAtual == 'em_execucao') {
      return _buildBotaoFinalizar();
    }

    return const SizedBox.shrink();
  }

  Widget _buildBotaoFinalizar() {
    return ElevatedButton.icon(
      onPressed: _finalizarOS,
      icon: const Icon(Icons.check_circle, color: Colors.black, size: 28),
      label: const Text(
        'Finalizar OS',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00FF88),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Future<void> _iniciarDeslocamento() async {
    if (latitude == null || longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('É necessário capturar a localização antes de iniciar.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final sucesso = await controller.deslocarParaOS(os.id, latitude!, longitude!);

    if (sucesso) {
      setState(() {
        statusAtual = 'em_deslocamento';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚗 Deslocamento iniciado! Dirija com segurança.'),            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao iniciar execução. Tente novamente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _chegarAoLocal() async {
    if (latitude == null || longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('É necessário capturar a localização ao chegar.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final sucesso = await controller.chegarAoLocal(os.id, latitude!, longitude!);

    if (sucesso) {
      setState(() {
        statusAtual = 'em_execucao';
        osIniciada = true; // Necessário para mostrar campos de finalização
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
            content: Text('Erro ao informar chegada. Tente novamente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _finalizarOS() async {
    // Validações
    if (latitude == null || longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('É necessário ter a localização registrada.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (relatoProblemaController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, descreva o problema identificado.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (relatoSolucaoController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, descreva a solução aplicada.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // ✅ ADICIONAR VALIDAÇÃO DE ASSINATURA:
    if (_assinaturaBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('É necessária a assinatura do cliente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Confirmar finalização
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
          'Ao finalizar, os dados serão enviados para o IXC e não poderão ser mais editados.',
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
              'Finalizar',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Preparar dados
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
      'assinatura': base64Encode(_assinaturaBytes!),  // ✅ ADICIONAR
    };

    final sucesso = await controller.finalizarExecucao(os.id, dados);

    if (sucesso) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OS finalizada e enviada ao IXC com sucesso!'),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao finalizar OS. Tente novamente.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}