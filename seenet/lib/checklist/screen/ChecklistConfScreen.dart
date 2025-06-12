import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistconf.widget.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';

class ChecklistConfScreen extends StatefulWidget {
  const ChecklistConfScreen({super.key});

  @override
  State<ChecklistConfScreen> createState() => _ChecklistConfScreenState();
}

class _ChecklistConfScreenState extends State<ChecklistConfScreen> {
  // Lista para controlar o estado dos checkboxes
  List<bool> checkStates = List.generate(39, (index) => false);

final List<String> problemas = [
  // Instalações de equipamentos
  'Instalar roteador',
  'Instalar roteador comodato',
  'Instalar ONT Intelbras (comodato)',
  'Instalar modem',
  'Instalar switch',
  'Instalar access point',
  'Instalar repetidor Wi-Fi',
  
  // Instalações de cabeamento
  'Instalar cabo',
  'Instalar cabo na TV',
  'Instalar Drop/Fibra',
  'Instalar internet FTTH',
  'Instalar conexão temporária',
  'Passagem de cabo interno',
  'Instalação de canaleta',
  'Instalação de abraçadeiras',
  
  // Instalações de aplicativos/serviços
  'Instalar BBTV',
  'Instalar App Watch',
  'Instalar App Premium',
  'Instalar App Standard',
  'Configurar Smart TV',
  'Configurar TV Box',
  'Instalar aplicativo no celular',
  'Configurar streaming',
  
  // Configurações gerais
  'Configuração',
  'Mudar senha da WiFi', // MOVIDO de manutenção
  'Trocar roteador', // MOVIDO de manutenção
  'Organizar ONU e roteador',
  'Organizar cabos',
  'Configurar rede Wi-Fi',
  'Configurar portas',
  'Configurar DHCP',
  'Configurar firewall',
  'Configurar VPN',
  'Configurar controle parental',
  'Sincronizar equipamentos',
  'Backup de configurações',
  'Teste de velocidade',
  'Teste de conectividade',
  'Orientação ao cliente',
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
                  'Problemas de Aplicativos',
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
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: problemas.length,
                    itemBuilder: (context, index) {
                      return ChecklistConfWidget(
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
          ),
        ],
      ),
    );
  }
}