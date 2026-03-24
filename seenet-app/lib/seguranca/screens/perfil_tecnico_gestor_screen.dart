// lib/seguranca/screens/perfil_tecnico_gestor_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
  String _filtroStatus = 'todas';

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
              const SizedBox(height: 12),
              _buildBotaoFichaEpi(),
              const SizedBox(height: 12),
              _buildBotaoAssinaturaAdmissao(),
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

  Widget _buildHistoricoRequisicoes() {
    final filtradas = _filtroStatus == 'todas'
        ? _requisicoes
        : _filtroStatus == 'aprovada'
        ? _requisicoes.where((r) => r['status'] == 'aprovada' || r['status'] == 'aguardando_confirmacao').toList()
        : _requisicoes.where((r) => r['status'] == _filtroStatus).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtros
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFiltroChip('Todas', 'todas', _requisicoes.length),
              const SizedBox(width: 8),
              _buildFiltroChip('Aprovadas', 'aprovada', _requisicoes.where((r) => r['status'] == 'aprovada' || r['status'] == 'aguardando_confirmacao').length),
              const SizedBox(width: 8),
              _buildFiltroChip('Concluídas', 'concluida', _requisicoes.where((r) => r['status'] == 'concluida').length),
              const SizedBox(width: 8),
              _buildFiltroChip('Pendentes', 'pendente', _requisicoes.where((r) => r['status'] == 'pendente').length),
              const SizedBox(width: 8),
              _buildFiltroChip('Recusadas', 'recusada', _requisicoes.where((r) => r['status'] == 'recusada').length),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (filtradas.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(Icons.assignment_outlined, size: 50, color: Colors.white12),
                SizedBox(height: 12),
                Text('Nenhuma requisição neste filtro',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF00FF88), size: 20),
              const SizedBox(width: 8),
              const Text('Histórico',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${filtradas.length} registro(s)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ...filtradas.map((req) => _buildRequisicaoCard(req)),
        ],
      ],
    );
  }

  Widget _buildFiltroChip(String label, String status, int count) {
    // Para "aprovada" filtrar ambos
    final isSelected = _filtroStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filtroStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FF88).withOpacity(0.15) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00FF88) : Colors.white12,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? const Color(0xFF00FF88) : Colors.white54,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBotaoAssinaturaAdmissao() {
    final temAssinatura = _perfil?['assinatura_admissao'] != null;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _uploadAssinaturaAdmissao,
        icon: Icon(
          temAssinatura ? Icons.check_circle : Icons.upload_file,
          color: temAssinatura ? const Color(0xFF00FF88) : Colors.orange,
          size: 20,
        ),
        label: Text(
          temAssinatura ? 'Assinatura de Admissão ✓' : 'Enviar Assinatura de Admissão',
          style: TextStyle(
            color: temAssinatura ? const Color(0xFF00FF88) : Colors.orange,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: temAssinatura ? const Color(0xFF00FF88) : Colors.orange),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _uploadAssinaturaAdmissao() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final result = await _service.uploadAssinaturaAdmissao(widget.tecnicoId, base64Str);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Erro'),
        backgroundColor: result['success'] == true ? const Color(0xFF00C853) : Colors.red,
      ));

      if (result['success'] == true) {
        _carregarPerfil();
      }
    }
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

          // Devoluções associadas
          if (req['devolucoes'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Builder(builder: (_) {
                final devs = req['devolucoes'] is List
                    ? req['devolucoes'] as List
                    : jsonDecode(req['devolucoes'].toString());
                if (devs.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_return, color: Colors.blue, size: 14),
                          SizedBox(width: 4),
                          Text('Devoluções:', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...devs.map((d) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${d['epi']} — ${d['codigo_subst'] ?? ''} ${d['data_devolucao'] ?? ''}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      )),
                    ],
                  ),
                );
              }),
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

  Widget _buildBotaoFichaEpi() {
  return SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
  onPressed: _gerarFichaEpi,
  icon: const Icon(Icons.description, color: Color(0xFF00FF88), size: 20),
  label: const Text('Ficha de EPI Completa (PDF)',
  style: TextStyle(color: Color(0xFF00FF88), fontSize: 14, fontWeight: FontWeight.bold)),
  style: OutlinedButton.styleFrom(
  side: const BorderSide(color: Color(0xFF00FF88)),
  padding: const EdgeInsets.symmetric(vertical: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  ),
  );
  }

  Future<void> _gerarFichaEpi() async {
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Gerando ficha de EPI...'), backgroundColor: Color(0xFF00FF88)),
  );

  final pdfBase64 = await _service.buscarFichaEpi(widget.tecnicoId);

  if (pdfBase64 == null) {
  if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Erro ao gerar ficha'), backgroundColor: Colors.red),
  );
  }
  return;
  }

  // Salvar e compartilhar
  final clean = pdfBase64.replaceFirst(RegExp(r'^data:application/pdf;base64,'), '');
  final bytes = base64Decode(clean);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/Ficha_EPI_${widget.tecnicoNome.replaceAll(' ', '_')}.pdf');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
  [XFile(file.path, mimeType: 'application/pdf')],
  subject: 'Ficha de EPI - ${widget.tecnicoNome} - BBnet Up',
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