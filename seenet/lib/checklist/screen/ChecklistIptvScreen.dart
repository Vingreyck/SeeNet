import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistiptv.widget.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';

class ChecklistIptvScreen extends StatefulWidget {
  const ChecklistIptvScreen({super.key});

  @override
  State<ChecklistIptvScreen> createState() => _ChecklistIptvScreenState();
}

class _ChecklistIptvScreenState extends State<ChecklistIptvScreen> {
  // Lista para controlar o estado dos checkboxes
  List<bool> checkStates = List.generate(24, (index) => false);

final List<String> problemas = [
  // Problemas de streaming
  'Canais travando/congelando',
  'Buffering constante',
  'Canal fora do ar',
  'Qualidade fraca',
  'Imagem pixelizada',
  'Áudio dessincronizado',
  'Tela preta',
  'Sem áudio',
  'Áudio cortando',
  
  // Problemas técnicos
  'Error code: xxxxx',
  'IPTV não abre',
  'Erro de autenticação',
  'Problema de DNS', // MOVIDO de configuração
  'Configuração incorreta', // MOVIDO de configuração
  'Lista de canais desatualizada',
  'EPG não carrega',
  'Aplicativo travando',
  'Aplicativo não instala',
  'Memória insuficiente no dispositivo',
  'Codec não suportado',
  
  // Problemas de rede específicos para IPTV
  'Multicast não funcionando',
  'IGMP com problema',
  'QoS mal configurado',
  'Largura de banda insuficiente',
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: CheckmarkEnviarWidget(),
          ),
        ],
      ),
    );
  }
}