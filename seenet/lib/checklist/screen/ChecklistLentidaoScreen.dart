import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistlentidao.widget.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';

class ChecklistLentidaoScreen extends StatefulWidget {
  const ChecklistLentidaoScreen({super.key});

  @override
  State<ChecklistLentidaoScreen> createState() => _ChecklistLentidaoScreenState();
}

class _ChecklistLentidaoScreenState extends State<ChecklistLentidaoScreen> {
  // Lista para controlar o estado dos checkboxes
  List<bool> checkStates = List.generate(10, (index) => false);

  // Lista dos problemas de lentidão
  final List<String> problemas = [
    'Velocidade abaixo do contratado',
    'Latência alta (ping > 100ms)',
    'Perda de pacotes',
    'Wi-fi com sinal fraco',
    'Problema no cabo',
    'Roteador com defeito',
    'Muitos dispositivos conectados',
    'Interferência eletromagnética',
    'Configuração incorreta',
    'Problema na operadora',
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: problemas.length,
              itemBuilder: (context, index) {
                return ChecklistLentidaoWidget(
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: CheckmarkEnviarWidget(),
          ),
        ],
      ),
    );
  }
}