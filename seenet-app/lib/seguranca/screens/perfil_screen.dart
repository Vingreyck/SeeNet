import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../controllers/seguranca_controller.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  int? _anoFiltro;
  int? _mesFiltro;
  int _abaAtual = 0; // 0=Histórico, 1=Fichário

  final controller = Get.find<SegurancaController>();

  @override
  void initState() {
    super.initState();
    controller.carregarPerfil();
    controller.carregarMinhasRequisicoes();
  }

  // Requisições concluídas do técnico (histórico de EPIs recebidos)
  List<Map<String, dynamic>> get _historicoRecebidos => controller.minhasRequisicoes
      .where((r) => r['status'] == 'concluida')
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Meu Perfil', style: TextStyle(color: Colors.white)),
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
              _buildAvatar(perfil),
              const SizedBox(height: 24),
              _buildInfoCard(perfil),
              const SizedBox(height: 16),
              if (stats != null) _buildStatsCard(stats),
              const SizedBox(height: 16),
              _buildHistoricoEpis(),
            ],
          ),
        );
      }),
    );
  }

  // ── Avatar ────────────────────────────────────────────────────
  Widget _buildAvatar(Map<String, dynamic> perfil) {
    final fotoBase64 = perfil['foto_perfil'] as String?;
    final nome = perfil['nome'] as String? ?? '';
    final tipo = perfil['tipo_usuario'] as String? ?? 'tecnico';

    Color tipoColor;
    String tipoLabel;
    switch (tipo) {
      case 'administrador':
        tipoColor = Colors.orange; tipoLabel = 'ADMINISTRADOR'; break;
      case 'gestor_seguranca':
        tipoColor = Colors.blue; tipoLabel = 'GESTOR DE SEGURANÇA'; break;
      default:
        tipoColor = const Color(0xFF00FF88); tipoLabel = 'TÉCNICO';
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
                  border: Border.all(
                      color: const Color(0xFF1A1A1A), width: 2),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  // ── Info ──────────────────────────────────────────────────────
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
          _buildInfoRow(Icons.email_outlined, 'E-mail', perfil['email'] ?? '--'),
          const Divider(color: Colors.white12, height: 20),
          _buildInfoRow(Icons.business_outlined, 'Empresa', perfil['empresa'] ?? '--'),
          const Divider(color: Colors.white12, height: 20),
          _buildInfoRow(Icons.calendar_today_outlined, 'Membro desde',
              _formatarData(perfil['data_criacao'])),
          if (perfil['ultimo_login'] != null) ...[
            const Divider(color: Colors.white12, height: 20),
            _buildInfoRow(Icons.access_time, 'Último acesso',
                _formatarData(perfil['ultimo_login'])),
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

  // ── Stats ─────────────────────────────────────────────────────
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
              _buildStatItem('Total', '${stats['total'] ?? 0}', Colors.white54),
              _buildStatItem('Concluídas', '${stats['aprovadas'] ?? 0}',
                  const Color(0xFF00FF88)),
              _buildStatItem(
                  'Pendentes', '${stats['pendentes'] ?? 0}', Colors.orange),
              _buildStatItem('Recusadas', '${stats['recusadas'] ?? 0}', Colors.red),
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
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Histórico de EPIs recebidos ───────────────────────────────
  Widget _buildHistoricoEpis() {
    final historico = controller.minhasRequisicoes
        .where((r) => r['status'] == 'concluida' && r['eh_fichario'] != true)
        .toList();
    final fichario = controller.minhasRequisicoes
        .where((r) => r['eh_fichario'] == true)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Abas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _buildAba('Histórico', 0, Icons.history),
                const SizedBox(width: 8),
                _buildAba('Fichário', 1, Icons.folder_special),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Filtro de período
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(child: _buildDropdownFiltro()),
                const SizedBox(width: 8),
                // Botão PDF do período filtrado
                if (_abaAtual == 0)
                  OutlinedButton.icon(
                    onPressed: _gerarPDFFiltrado,
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF00FF88)),
                    label: const Text('PDF', style: TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00FF88)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Conteúdo da aba
          if (_abaAtual == 0)
            ...historico.take(20).map((req) => _buildItemHistorico(req))
          else
            ...fichario.take(20).map((req) => _buildItemFichario(req)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAba(String label, int index, IconData icon) {
    final sel = _abaAtual == index;
    return GestureDetector(
      onTap: () => setState(() => _abaAtual = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF00FF88).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? const Color(0xFF00FF88) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: sel ? const Color(0xFF00FF88) : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: sel ? const Color(0xFF00FF88) : Colors.white38,
              fontSize: 12,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFiltro() {
    final anos = [null, DateTime.now().year, DateTime.now().year - 1, DateTime.now().year - 2];
    final meses = [null, 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return Row(
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _anoFiltro,
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              hint: const Text('Ano', style: TextStyle(color: Colors.white38, fontSize: 12)),
              items: anos.map((a) => DropdownMenuItem(
                value: a,
                child: Text(a?.toString() ?? 'Todos', style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: (v) => setState(() => _anoFiltro = v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _mesFiltro,
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              hint: const Text('Mês', style: TextStyle(color: Colors.white38, fontSize: 12)),
              items: List.generate(13, (i) => DropdownMenuItem(
                value: i == 0 ? null : i,
                child: Text(i == 0 ? 'Todos' : meses[i]!, style: const TextStyle(fontSize: 12)),
              )),
              onChanged: (v) => setState(() => _mesFiltro = v),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _gerarPDFFiltrado() async {
    // Chama o backend com filtro
    final auth = Get.find<AuthService>();
    final tecnicoId = controller.perfilData.value?['id'];
    if (tecnicoId == null) return;

    final params = <String>[];
    if (_mesFiltro != null) params.add('mes=$_mesFiltro');
    if (_anoFiltro != null) params.add('ano=$_anoFiltro');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';

    final url = 'https://seenet-production.up.railway.app/api/seguranca/relatorio-epi/$tecnicoId$query';

    // Abre no browser ou compartilha
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gerando PDF do período...'),
      backgroundColor: Color(0xFF00FF88),
    ));

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer ${auth.token}',
        'X-Tenant-Code': auth.tenantCode ?? '',
      });
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF gerado! Compartilhando...'),
          backgroundColor: Color(0xFF00FF88),
        ));
        // Compartilha via share_plus
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildItemFichario(Map<String, dynamic> req) {
    final epis = req['epis_solicitados'];
    final List<String> episLista = epis is List ? epis.cast<String>() : [];
    final temFoto = req['foto_documento_base64'] != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_special, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatarData(req['data_entrega'] ?? req['data_criacao']),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  episLista.join(', '),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (temFoto)
            const Icon(Icons.photo, color: Colors.purple, size: 16),
        ],
      ),
    );
  }

  Widget _buildItemHistorico(Map<String, dynamic> req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            req['tecnico_nome'] ?? 'Sem nome',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Data: ${req['data_entrega'] ?? '-'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'EPIs: ${(req['epis_solicitados'] ?? []).join(', ')}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _alterarFoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 70, maxWidth: 400);
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
    } catch (_) { return '--'; }
  }

  String _dia(String? data) {
    if (data == null) return '--';
    try { return DateTime.parse(data).toLocal().day.toString().padLeft(2, '0'); }
    catch (_) { return '--'; }
  }

  String _mesAno(String? data) {
    if (data == null) return '--';
    try {
      final dt = DateTime.parse(data).toLocal();
      const meses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
      return '${meses[dt.month - 1]} ${dt.year}';
    } catch (_) { return '--'; }
  }
}