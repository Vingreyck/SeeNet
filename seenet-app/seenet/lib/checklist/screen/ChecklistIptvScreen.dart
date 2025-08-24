import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistiptv.widget.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';
import '../../controllers/checkmark_controller.dart';
import '../../controllers/usuario_controller.dart';

class ChecklistIptvScreen extends StatefulWidget {
  const ChecklistIptvScreen({super.key});

  @override
  State<ChecklistIptvScreen> createState() => _ChecklistIptvScreenState();
}

class _ChecklistIptvScreenState extends State<ChecklistIptvScreen> {
  final CheckmarkController checkmarkController = Get.put(CheckmarkController());
  final UsuarioController usuarioController = Get.find<UsuarioController>();

  @override
  void initState() {
    super.initState();
    _inicializarDados();
  }

  void _inicializarDados() async {
    // Carregar checkmarks da categoria IPTV (ID = 2, ajuste se necessário)
    await checkmarkController.carregarCheckmarks(2);

    // Iniciar nova avaliação
    if (usuarioController.usuarioLogado.value != null) {
      await checkmarkController.iniciarAvaliacao(
        usuarioController.usuarioLogado.value!.id!,
        'Diagnóstico - IPTV'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          // Header verde
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00E87C),
                  Color(0xFF00B05B),
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Get.back(),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Problemas de IPTV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Lista de checkboxes dinâmica do banco
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Obx(() {
                    if (checkmarkController.checkmarksAtivos.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00FF88),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: checkmarkController.checkmarksAtivos.length,
                      itemBuilder: (context, index) {
                        final checkmark = checkmarkController.checkmarksAtivos[index];

                        return Obx(() => ChecklistiptvWidget(
                          title: checkmark.titulo,
                          isChecked: checkmarkController.respostas[checkmark.id] ?? false,
                          onChanged: (value) {
                            checkmarkController.toggleCheckmark(checkmark.id!, value ?? false);
                          },
                        ));
                      },
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: CheckmarkEnviarWidget(
                    onPressed: _enviarDiagnostico,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _enviarDiagnostico() async {
    // Salvar respostas
    bool salvou = await checkmarkController.salvarRespostas();

    if (salvou) {
      // Finalizar avaliação
      await checkmarkController.finalizarAvaliacao();

      Get.snackbar(
        'Sucesso',
        'Respostas salvas! Gerando diagnóstico...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Navegar para diagnóstico
      Get.toNamed('/diagnostico');
    } else {
      Get.snackbar(
        'Erro',
        'Erro ao salvar respostas',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}