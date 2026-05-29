// lib/dds/screens/dds_historico_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../controllers/dds_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/dds_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class DdsHistoricoScreen extends StatefulWidget {
  const DdsHistoricoScreen({super.key});

  @override
  State<DdsHistoricoScreen> createState() => _DdsHistoricoScreenState();
}

class _DdsHistoricoScreenState extends State<DdsHistoricoScreen> {
  final _ctrl = Get.find<DdsController>();
  final _service = Get.find<DdsService>();
  int _anoSelecionado = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    await _ctrl.carregarHistorico(ano: _anoSelecionado);
  }

  // ── PDF histórico anual ────────────────────────────────────
  Future<void> _gerarPdfHistorico() async {
    try {
      final api = Get.find<ApiService>();
      if (kIsWeb) {
        final url = ApiConfig.getUrl(
            '/api/dds/historico/pdf?ano=$_anoSelecionado&token=${api.token}');
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }
      Get.snackbar('Gerando...', 'Aguarde o PDF do histórico.',
          backgroundColor: const Color(0xFF2A2A2A),
          colorText: Colors.white,
          duration: const Duration(seconds: 10));
      final url = ApiConfig.getUrl('/api/dds/historico/pdf?ano=$_anoSelecionado');
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.getAuthHeaders(api.token!, api.tenantCode!),
      );
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/DDS_$_anoSelecionado.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'DDS Histórico $_anoSelecionado',
        );
      }
    } catch (e) {
      Get.snackbar('Erro', 'Falha ao gerar PDF: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Histórico de DDS',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF00FF88)),
            tooltip: 'Gerar PDF do ano',
            onPressed: _gerarPdfHistorico,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _carregar,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSeletorAno(),
          Expanded(child: _buildLista()),
        ],
      ),
    );
  }

  Widget _buildSeletorAno() {
    final anoAtual = DateTime.now().year;
    return Container(
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(4, (i) {
            final ano = anoAtual - i;
            final sel = _anoSelecionado == ano;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _anoSelecionado = ano);
                  _carregar();
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF00FF88).withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                      sel ? const Color(0xFF00FF88) : Colors.white12,
                    ),
                  ),
                  child: Text('$ano',
                      style: TextStyle(
                        color: sel
                            ? const Color(0xFF00FF88)
                            : Colors.white54,
                        fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      )),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLista() {
    return Obx(() {
      if (_ctrl.isLoading.value) {
        return const Center(
            child:
            CircularProgressIndicator(color: Color(0xFF00FF88)));
      }

      if (_ctrl.historico.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy, size: 60, color: Colors.white12),
              const SizedBox(height: 12),
              Text('Nenhum DDS em $_anoSelecionado',
                  style:
                  const TextStyle(color: Colors.white38, fontSize: 15)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _carregar,
        color: const Color(0xFF00FF88),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _ctrl.historico.length,
          itemBuilder: (_, i) => _buildCard(_ctrl.historico[i]),
        ),
      );
    });
  }

  Widget _buildCard(Map<String, dynamic> s) {
    final tema = s['tema'] as String? ?? '';
    final duracao = s['duracao_minutos'] as int? ?? 0;
    final totalAssinaturas =
        int.tryParse('${s['total_assinaturas']}') ?? 0;
    final local = s['local_dds'] as String? ?? 'BBNet Up Provedor';

    return GestureDetector(
      onTap: () => _verParticipantes(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF00FF88).withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(_diaStr(s['criado_em']),
                      style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text(_mesStr(s['criado_em']),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tema,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(local,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 3),
                      Text('5 a $duracao min',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      const SizedBox(width: 12),
                      const Icon(Icons.people,
                          size: 12, color: Colors.white38),
                      const SizedBox(width: 3),
                      Text('$totalAssinaturas presença(s)',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _verParticipantes(Map<String, dynamic> sessao) async {
    final data =
    await _service.buscarParticipantes(sessao['id'] as int);
    if (data == null) return;

    final participantes =
        (data['participantes'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalhesDdsSheet(
        sessao:
        data['sessao'] as Map<String, dynamic>? ?? sessao,
        participantes: participantes,
        onGerarPdf: () => _gerarPdfSessao(sessao['id'] as int),
      ),
    );
  }

  Future<void> _gerarPdfSessao(int sessaoId) async {
    try {
      final api = Get.find<ApiService>();
      if (kIsWeb) {
        final url = ApiConfig.getUrl(
            '/api/dds/sessao/$sessaoId/pdf?token=${api.token}');
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }
      final url = ApiConfig.getUrl('/api/dds/sessao/$sessaoId/pdf');
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.getAuthHeaders(api.token!, api.tenantCode!),
      );
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/DDS_Sessao_$sessaoId.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Lista de Presença DDS',
        );
      }
    } catch (e) {
      Get.snackbar('Erro', 'Falha ao gerar PDF: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  String _diaStr(String? data) {
    if (data == null) return '--';
    try {
      return DateTime.parse(data).toLocal().day.toString();
    } catch (_) {
      return '--';
    }
  }

  String _mesStr(String? data) {
    if (data == null) return '';
    const meses = [
      '',
      'JAN','FEV','MAR','ABR','MAI','JUN',
      'JUL','AGO','SET','OUT','NOV','DEZ'
    ];
    try {
      return meses[DateTime.parse(data).toLocal().month];
    } catch (_) {
      return '';
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Sheet de detalhes de uma sessão
// ──────────────────────────────────────────────────────────────
class _DetalhesDdsSheet extends StatelessWidget {
  final Map<String, dynamic> sessao;
  final List<Map<String, dynamic>> participantes;
  final VoidCallback onGerarPdf;

  const _DetalhesDdsSheet({
    required this.sessao,
    required this.participantes,
    required this.onGerarPdf,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.health_and_safety,
                      color: Color(0xFF00FF88), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sessao['tema'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Text('${participantes.length} participante(s)',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf,
                        color: Color(0xFF00FF88)),
                    onPressed: onGerarPdf,
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: participantes.isEmpty
                  ? const Center(
                  child: Text('Nenhum participante registrado',
                      style:
                      TextStyle(color: Colors.white38)))
                  : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: participantes.length,
                itemBuilder: (_, i) =>
                    _buildParticipanteCard(participantes[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipanteCard(Map<String, dynamic> p) {
    final sig = p['assinatura_base64'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF00FF88),
            child: Icon(Icons.person, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(p['nome'] ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          if (sig != null)
            Builder(builder: (_) {
              try {
                final clean = sig.replaceFirst(
                    RegExp(r'^data:image/\w+;base64,'), '');
                return Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(base64Decode(clean),
                        fit: BoxFit.contain),
                  ),
                );
              } catch (_) {
                return const Icon(Icons.draw,
                    color: Color(0xFF00FF88), size: 20);
              }
            }),
        ],
      ),
    );
  }
}