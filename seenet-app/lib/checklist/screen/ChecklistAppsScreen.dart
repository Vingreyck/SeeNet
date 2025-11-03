// lib/checklist/screen/ChecklistAppsScreen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistapps.widget.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';
import '../../controllers/checkmark_controller.dart';
import '../../controllers/usuario_controller.dart';

class ChecklistAppsScreen extends StatefulWidget {
  const ChecklistAppsScreen({super.key});

  @override
  State<ChecklistAppsScreen> createState() => _ChecklistAppsScreenState();
}

class _ChecklistAppsScreenState extends State<ChecklistAppsScreen> {
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
      final categoriaNome = checkmarkController.nomeCategoriaAtual.isNotEmpty 
          ? checkmarkController.nomeCategoriaAtual 
          : 'Aplicativos';
      
      await checkmarkController.iniciarAvaliacao(
        usuarioController.usuarioLogado.value!.id!,
        'Diagnóstico - $categoriaNome',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
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
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 16),
                Obx(() {
                  final categoriaNome = checkmarkController.nomeCategoriaAtual.isNotEmpty
                      ? checkmarkController.nomeCategoriaAtual
                      : 'Aplicativos';
                  
                  return Text(
                    'Problemas de $categoriaNome',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Obx(() {
                    if (checkmarkController.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00FF88),
                        ),
                      );
                    }

                    if (checkmarkController.checkmarksAtivos.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: checkmarkController.checkmarksAtivos.length,
                      itemBuilder: (context, index) {
                        final checkmark = checkmarkController.checkmarksAtivos[index];

                        return Obx(() => ChecklistAppsWidget(
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

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.playlist_add_check_outlined,
              size: 80,
              color: Colors.white24,
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhum checkmark disponível',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta categoria ainda não possui checkmarks cadastrados.\n\n'
              'Acesse o painel administrativo para adicionar.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            if (usuarioController.isAdmin) ...[
              ElevatedButton.icon(
                onPressed: () => Get.toNamed('/admin/checkmarks'),
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text(
                  'Adicionar Checkmarks',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _enviarDiagnostico() async {
    bool salvou = await checkmarkController.salvarRespostas();

    if (!salvou) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao salvar respostas'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🤖 Gerando diagnóstico com IA...'),
          backgroundColor: Color(0xFF00FF88),
          duration: Duration(seconds: 3),
        ),
      );
    }

    await checkmarkController.gerarDiagnosticoComGemini();
    await checkmarkController.finalizarAvaliacao();

    if (mounted) {
      Get.offNamed('/diagnostico');
    }
  }
}