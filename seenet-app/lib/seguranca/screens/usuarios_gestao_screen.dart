// lib/seguranca/screens/usuarios_gestao_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/seguranca_service.dart';
import 'perfil_tecnico_gestor_screen.dart';

class UsuariosGestaoScreen extends StatelessWidget {
  const UsuariosGestaoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Usuários (Gestão)',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Get.find<SegurancaService>().buscarTecnicos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF88)));
          }

          final tecnicos = snapshot.data ?? [];

          if (tecnicos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.white12),
                  SizedBox(height: 12),
                  Text('Nenhum usuário cadastrado',
                      style: TextStyle(color: Colors.white38, fontSize: 15)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tecnicos.length,
            itemBuilder: (context, index) {
              return _buildCardUsuario(tecnicos[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildCardUsuario(Map<String, dynamic> tec) {
    final tipo = tec['tipo_usuario'] as String? ?? 'tecnico';
    Color tipoColor;
    String tipoLabel;
    switch (tipo) {
      case 'administrador':
        tipoColor = Colors.orange;
        tipoLabel = 'Admin';
        break;
      case 'gestor_seguranca':
        tipoColor = Colors.blue;
        tipoLabel = 'Gestor Seg.';
        break;
      case 'gestor':
        tipoColor = Colors.purple;
        tipoLabel = 'Gestor';
        break;
      default:
        tipoColor = const Color(0xFF00FF88);
        tipoLabel = 'Técnico';
    }

    return InkWell(
      onTap: () => Get.to(() => PerfilTecnicoGestorScreen(
        tecnicoId: tec['id'] as int,
        tecnicoNome: tec['nome'] as String,
      )),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tipoColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: tipoColor.withOpacity(0.15),
              child: Icon(Icons.person, color: tipoColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tec['nome'] as String? ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(tec['email'] as String? ?? '',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tipoColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tipoLabel,
                  style: TextStyle(
                      color: tipoColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: tipoColor, size: 20),
          ],
        ),
      ),
    );
  }
}