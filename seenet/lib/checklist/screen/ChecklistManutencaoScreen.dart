import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checklistManutencao.widget.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';

class ChecklistManutencaoScreen extends StatefulWidget {
  const ChecklistManutencaoScreen({super.key});

  @override
  State<ChecklistManutencaoScreen> createState() => _ChecklistManutencaoScreenState();
}

class _ChecklistManutencaoScreenState extends State<ChecklistManutencaoScreen> {
  // Lista para controlar o estado dos checkboxes
  List<bool> checkStates = List.generate(49, (index) => false);

final List<String> problemas = [
  // Problemas de conectividade/instabilidade
  'Quedas constantes',
  'Quedas à noite',
  'Sem funcionar/Tec moto',
  'Sem funcionar/Equipe carro',
  'Lentidão',
  'Velocidade abaixo do contratado', // MOVIDO de IPTV
  'Intermitência no sinal',
  'Perda de pacotes',
  'Alta latência',
  
  // Problemas físicos da rede
  'Cabo baixo',
  'Cabo rompido/quebrado',
  'Conector danificado/quebrado',
  'Cabo mal crimpado',
  'Cabo deteriorado por intempéries',
  'Cabo danificado por roedores',
  'Emenda mal feita',
  'Conector oxidado',
  'Cabo descascado',
  
  // Problemas de equipamentos
  'Roteador para teste',
  'Repetidor sem funcionar',
  'ONU sem sinal',
  'CTO sem sinal',
  'Sinal alto na casa do cliente',
  'ONU com defeito',
  'Roteador com defeito',
  'Fonte queimada',
  'Porta ethernet com defeito',
  'LED de status apagado',
  'Superaquecimento de equipamento',
  'Equipamento reiniciando sozinho',
  
  // Reparos de infraestrutura
  'Reparo Backbone',
  'Reparo rede FTTH',
  'Reparo rede cabeada',
  'Manutenção FTTH',
  'Manutenção servidor (POP)',
  'Troca de poste',
  'Reparo em caixa de emenda',
  'Reparo splitter óptico',
  'Limpeza de conectores ópticos',
  'Fusão de fibra',
  
  // Melhorias e atualizações
  'Extensão rede fibra',
  'Mudar cabo de lugar',
  'Atualização de firmware',
  'Upgrade Splitter 1:16',
  'Balanceamento de carga',
  'Otimização de rota',
  
  // Alterações contratuais
  'Trocar equipamento alteração de contrato',
  'Upgrade de velocidade',
  'Downgrade de velocidade',
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
                  'Manutenção',
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
                return ChecklistManutencaoWidget(
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