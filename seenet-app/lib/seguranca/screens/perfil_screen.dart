import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../controllers/seguranca_controller.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final controller = Get.find<SegurancaController>();

  @override
  void initState() {
    super.initState();
    controller.carregarPerfil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Meu Perfil',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Obx(() {
        final perfil = controller.perfilData.value;
        final stats = controller.statsData.value;

        if (perfil == null) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar + nome
              _buildAvatar(perfil),
              const SizedBox(height: 24),

              // Dados do perfil
              _buildInfoCard(perfil),
              const SizedBox(height: 16),

              // Estatísticas de requisições
              if (stats != null) _buildStatsCard(stats),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> perfil) {
    final fotoBase64 = perfil['foto_perfil'] as String?;
    final nome = perfil['nome'] as String? ?? '';
    final tipo = perfil['tipo_usuario'] as String? ?? 'tecnico';

    Color tipoColor;
    String tipoLabel;
    switch (tipo) {
      case 'administrador':
        tipoColor = Colors.orange;
        tipoLabel = 'ADMINISTRADOR';
        break;
      case 'gestor_seguranca':
        tipoColor = Colors.blue;
        tipoLabel = 'GESTOR DE SEGURANÇA';
        break;
      default:
        tipoColor = const Color(0xFF00FF88);
        tipoLabel = 'TÉCNICO';
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tipoColor, width: 3),
                color: const Color(0xFF2A2A2A),
              ),
              child: ClipOval(
                child: fotoBase64 != null
                    ? Image.memory(
                  base64Decode(fotoBase64.split(',').last),
                  fit: BoxFit.cover,
                )
                    : Icon(Icons.person,
                    size: 50, color: tipoColor.withOpacity(0.7)),
              ),
            ),
            GestureDetector(
              onTap: _alterarFoto,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tipoColor,
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                ),
                child: const Icon(Icons.camera_alt,
                    size: 16, color: Colors.black),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(nome,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tipoColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(tipoLabel,
              style: TextStyle(
                  color: tipoColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> perfil) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email_outlined, 'E-mail',
              perfil['email'] ?? '--'),
          const Divider(color: Colors.white12, height: 20),
          _buildInfoRow(Icons.business_outlined, 'Empresa',
              perfil['empresa'] ?? '--'),
          const Divider(color: Colors.white12, height: 20),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Membro desde',
            _formatarData(perfil['data_criacao']),
          ),
          if (perfil['ultimo_login'] != null) ...[
            const Divider(color: Colors.white12, height: 20),
            _buildInfoRow(
              Icons.access_time,
              'Último acesso',
              _formatarData(perfil['ultimo_login']),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCard(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Requisições de EPI',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatItem('Total',
                  '${stats['total'] ?? 0}', Colors.white54),
              _buildStatItem('Aprovadas',
                  '${stats['aprovadas'] ?? 0}', const Color(0xFF00FF88)),
              _buildStatItem('Pendentes',
                  '${stats['pendentes'] ?? 0}', Colors.orange),
              _buildStatItem('Recusadas',
                  '${stats['recusadas'] ?? 0}', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style:
              const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _alterarFoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 400,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final ok = await controller.atualizarFoto(base64);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Foto atualizada!' : 'Erro ao atualizar foto'),
          backgroundColor: ok ? const Color(0xFF00C853) : Colors.red,
        ));
      }
    }
  }

  String _formatarData(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '--';
    }
  }
}