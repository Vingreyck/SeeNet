import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistiptv.widget.dart';

class ChecklistIptvScreen extends StatefulWidget {
  const ChecklistIptvScreen({super.key});

  @override
  State<ChecklistIptvScreen> createState() => _ChecklistIptvScreenState();
}

class _ChecklistIptvScreenState extends State<ChecklistIptvScreen> {
  // Lista para controlar o estado dos checkboxes
  List<bool> checkStates = List.generate(10, (index) => false);

  // Lista dos problemas de IPTV
  final List<String> problemas = [
    'Canais travando/congelando',
    'Buffering constante',
    'Canal fora do ar',
    'Qualidade fraca',
    'Error code: xxxxx',
    'IPTV não abre',
    'Erro de autenticação',
    'Velocidade abaixo do contratado',
    'Problema de DNS',
    'Configuração incorreta',
  ];

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
          // Lista de checkboxes
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: problemas.length,
              itemBuilder: (context, index) {
                return ChecklistiptvWidget(
                  title: problemas[index],
                  isChecked: checkStates[index],
                  onChanged: (value) {
                    setState(() {
                      checkStates[index] = value ?? false;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}