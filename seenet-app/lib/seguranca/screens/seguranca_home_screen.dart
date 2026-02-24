import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/seguranca_controller.dart';

class SegurancaHomeScreen extends StatelessWidget {
  const SegurancaHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SegurancaController>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Segurança do Trabalho',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A2F), Color(0xFF0D2B1F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.health_and_safety,
                        color: Color(0xFF00FF88), size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EPIs e Segurança',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Gerencie suas requisições\nde equipamentos de proteção',
                            style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('O que deseja fazer?',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),

            // Opção: Nova Requisição
            _buildCard(
              icon: Icons.add_circle_outline,
              title: 'Nova Requisição de EPI',
              subtitle: 'Solicite os equipamentos necessários\npara sua atividade',
              color: const Color(0xFF00FF88),
              onTap: () => Get.toNamed('/seguranca/requisicao'),
            ),
            const SizedBox(height: 12),

            // Opção: Minhas Requisições
            _buildCard(
              icon: Icons.list_alt,
              title: 'Minhas Requisições',
              subtitle: 'Acompanhe o status das suas\nsolicitações de EPI',
              color: Colors.blue,
              onTap: () => Get.toNamed('/seguranca/minhas'),
            ),
            const SizedBox(height: 12),

            // Opção: Meu Perfil
            _buildCard(
              icon: Icons.person_outline,
              title: 'Meu Perfil',
              subtitle: 'Visualize e edite\nsuas informações',
              color: Colors.purple,
              onTap: () => Get.toNamed('/seguranca/perfil'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }
}