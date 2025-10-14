// lib/checklist/screen/ChecklistLentidaoScreen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistlentidao.widget.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';
import '../../controllers/checkmark_controller.dart';
import '../../controllers/usuario_controller.dart';

class ChecklistLentidaoScreen extends StatefulWidget {
  const ChecklistLentidaoScreen({super.key});

  @override
  State<ChecklistLentidaoScreen> createState() => _ChecklistLentidaoScreenState();
}

class _ChecklistLentidaoScreenState extends State<ChecklistLentidaoScreen> {
  final CheckmarkController checkmarkController = Get.find<CheckmarkController>();
  final UsuarioController usuarioController = Get.find<UsuarioController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarDados();
    });
  }

  void _inicializarDados() async {
    print('📋 Checkmarks já carregados: ${checkmarkController.checkmarksAtivos.length}');
    
    if (usuarioController.usuarioLogado.value != null) {
      await checkmarkController.iniciarAvaliacao(
        usuarioController.usuarioLogado.value!.id!,
        'Diagnóstico - Lentidão'
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
                  onPressed: () {
                    // ✅ Usar Navigator.pop em vez de Get.back
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 16),
                const Text(
                  'Problemas de Lentidão',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Lista de checkboxes
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
                        
                        return Obx(() => ChecklistLentidaoWidget(
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
    bool salvou = await checkmarkController.salvarRespostas();
    
    if (salvou) {
      await checkmarkController.finalizarAvaliacao();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Respostas salvas! Gerando diagnóstico...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        Get.toNamed('/diagnostico');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar respostas'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}