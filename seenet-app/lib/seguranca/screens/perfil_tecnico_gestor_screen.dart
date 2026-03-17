// lib/seguranca/screens/perfil_tecnico_gestor_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../services/seguranca_service.dart';
import '../controllers/seguranca_controller.dart';
import '../widgets/botao_pdf.dart';
import 'registro_manual_epi_screen.dart';

class PerfilTecnicoGestorScreen extends StatefulWidget {
  final int tecnicoId;
  final String tecnicoNome;

  const PerfilTecnicoGestorScreen({
    super.key,
    required this.tecnicoId,
    required this.tecnicoNome,
  });

  @override
  State<PerfilTecnicoGestorScreen> createState() =>
      _PerfilTecnicoGestorScreenState();
}

class _PerfilTecnicoGestorScreenState extends State<PerfilTecnicoGestorScreen> {
  final _service = Get.find<SegurancaService>();
  final _controller = Get.find<SegurancaController>();

  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _requisicoes = [];
  bool _isLoading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      final data = await _service.buscarPerfilTecnico(widget.tecnicoId);
      if (data != null) {
        setState(() {
          _perfil = data['usuario'];
          _stats = data['stats'];
          final List reqs = data['requisicoes'] ?? [];
          _requisicoes = reqs.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _erro = 'Não foi possível carregar o perfil';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Erro: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(widget.tecnicoNome,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _carregarPerfil,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : _erro != null
          ? _buildErro()
          : RefreshIndicator(
        onRefresh: _carregarPerfil,
        color: const Color(0xFF00FF88),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildAvatar(),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 16),
              if (_stats != null) _buildStatsCard(),
              const SizedBox(height: 16),
              _buildBotaoRegistroManual(),
              const SizedBox(height: 20),
              _buildHistoricoRequisicoes(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar ────────────────────────────────────────────────────
  Widget _buildAvatar() {
    final fotoBase64 = _perfil?['foto_perfil'] as String?;
    final nome = _perfil?['nome'] as String? ?? '';
    final tipo = _perfil?['tipo_usuario'] as String? ?? 'tecnico';

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
              width: 100,
              height: 100,
            )
                : Icon(Icons.person, size: 50, color: tipoColor.withOpacity(0.7)),
          ),
        ),
        const SizedBox(height: 12),
        Text(nome,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tipoColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(tipoLabel,
              style: TextStyle(
                  color: tipoColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ── Info ──────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.email_outlined, 'E-mail', _perfil?['email'] ?? '--'),
          const Divider(color: Colors.white12, height: 20),
          _buildInfoRow(Icons.business_outlined, 'Empresa', _perfil?['empresa'] ?? '--'),
          const Divider(color: Colors.white12, height: 20),
          _buildInfoRow(Icons.calendar_today_outlined, 'Membro desde',
              _formatarData(_perfil?['data_criacao'])),
          if (_perfil?['ultimo_login'] != null) ...[
            const Divider(color: Colors.white12, height: 20),
            _buildInfoRow(Icons.access_time, 'Último acesso',
                _formatarData(_perfil?['ultimo_login'])),
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
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  // ── Stats ─────────────────────────────────────────────────────
  Widget _buildStatsCard() {
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
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatItem('Total', '${_stats?['total'] ?? 0}', Colors.white54),
              _buildStatItem('Concluídas', '${_stats?['concluidas'] ?? 0}',
                  const Color(0xFF00FF88)),
              _buildStatItem('Pendentes', '${_stats?['pendentes'] ?? 0}', Colors.orange),
              _buildStatItem('Recusadas', '${_stats?['recusadas'] ?? 0}', Colors.red),
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
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Botão Registro Manual ─────────────────────────────────────
  Widget _buildBotaoRegistroManual() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Get.to(() => RegistroManualEpiScreen(
            tecnicoIdFixo: widget.tecnicoId,
            tecnicoNomeFixo: widget.tecnicoNome,
          ));
          _carregarPerfil(); // Recarrega ao voltar
        },
        icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 20),
        label: const Text('Registrar EPI Manual',
            style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF88),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Histórico de Requisições ──────────────────────────────────
  Widget _buildHistoricoRequisicoes() {
    if (_requisicoes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          children: [
            Icon(Icons.assignment_outlined, size: 50, color: Colors.white12),
            SizedBox(height: 12),
            Text('Nenhuma requisição registrada',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF00FF88), size: 20),
            const SizedBox(width: 8),
            const Text('Histórico Completo',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_requisicoes.length} registro(s)',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        ..._requisicoes.map((req) => _buildRequisicaoCard(req)),
      ],
    );
  }

  Widget _buildRequisicaoCard(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'pendente';
    final color = _controller.statusColor(status);
    final label = _controller.statusLabel(status);
    final epis = req['epis_solicitados'];
    final List<String> episLista =
    epis is List ? epis.cast<String>() : (epis is String ? _parseEpis(epis) : []);
    final temFoto = req['foto_recebimento_base64'] != null;
    final temAssinatura = req['assinatura_recebimento_base64'] != null;
    final temPdf = req['pdf_base64'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                if (req['registro_manual'] == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Manual',
                        style: TextStyle(color: Colors.blue, fontSize: 9)),
                  ),
                ],
                const Spacer(),
                Text('Req. #${req['id']}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),

          // EPIs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${episLista.length} EPI(s):',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: episLista
                      .map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(e,
                        style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Datas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _buildDataRow('Solicitado', _formatarData(req['data_criacao'])),
                if (req['data_resposta'] != null)
                  _buildDataRow('Respondido', _formatarData(req['data_resposta'])),
                if (req['data_confirmacao_recebimento'] != null)
                  _buildDataRow(
                      'Confirmado', _formatarData(req['data_confirmacao_recebimento'])),
                if (req['gestor_nome'] != null)
                  _buildDataRow('Gestor', req['gestor_nome']),
              ],
            ),
          ),

          // IXC info
          if (req['id_requisicao_ixc'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2)),
                ),
                child: Text(
                  '📦 Estoque descontado — IXC Req. #${req['id_requisicao_ixc']}',
                  style: const TextStyle(color: Color(0xFF00FF88), fontSize: 11),
                ),
              ),
            ),

          // Evidências e PDF
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (temFoto)
                  GestureDetector(
                    onTap: () =>
                        _verImagem(req['foto_recebimento_base64'], 'Foto de Recebimento'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo, color: Color(0xFF00FF88), size: 14),
                          SizedBox(width: 4),
                          Text('Foto',
                              style: TextStyle(color: Color(0xFF00FF88), fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                if (temFoto) const SizedBox(width: 8),
                if (temAssinatura)
                  GestureDetector(
                    onTap: () => _verImagem(
                        req['assinatura_recebimento_base64'], 'Assinatura Digital'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.draw, color: Color(0xFF00FF88), size: 14),
                          SizedBox(width: 4),
                          Text('Assinatura',
                              style: TextStyle(color: Color(0xFF00FF88), fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                if (temPdf)
                  BotaoPDF(
                    requisicaoId: req['id'] as int,
                    pdfBase64Cached: req['pdf_base64'],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 12),
          Text(_erro!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _carregarPerfil,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            child: const Text('Tentar Novamente', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _verImagem(String? base64, String titulo) {
    if (base64 == null) return;
    try {
      final bytes = base64Decode(base64.split(',').last);
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  List<String> _parseEpis(String epis) {
    try {
      final List parsed = jsonDecode(epis);
      return parsed.cast<String>();
    } catch (_) {
      return [epis];
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