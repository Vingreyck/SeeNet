// lib/seguranca/screens/relatorio_epi_screen.dart — REDESIGN
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../widgets/pdf_viewer_screen.dart';

class RelatorioEpiScreen extends StatefulWidget {
  const RelatorioEpiScreen({super.key});

  @override
  State<RelatorioEpiScreen> createState() => _RelatorioEpiScreenState();
}

class _RelatorioEpiScreenState extends State<RelatorioEpiScreen> {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  List<Map<String, dynamic>> _tecnicos = [];
  bool _carregando = true;
  bool _gerando = false;
  int? _tecnicoSelecionado;
  String? _tecnicoNome;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  Map<String, String> get _headers {
    final auth = Get.find<AuthService>();
    return {
      'Authorization': 'Bearer ${auth.token}',
      'X-Tenant-Code': auth.tenantCode ?? '',
    };
  }

  @override
  void initState() {
    super.initState();
    _carregarTecnicos();
  }

  Future<void> _carregarTecnicos() async {
    try {
      // ✅ /seguranca/tecnicos: o gestor_seguranca PODE acessar (isGestorOuAdmin).
      // ANTES usava /admin/users (SÓ admin) → o gestor tomava 403 e a tela travava.
      final response = await http.get(
        Uri.parse('$baseUrl/seguranca/tecnicos'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final root = (body is Map ? (body['data'] ?? body) : body);
        final lista = (root is Map ? (root['tecnicos'] ?? []) : []) as List;
        if (mounted) {
          setState(() {
            _tecnicos = List<Map<String, dynamic>>.from(
              lista.where((u) => u['tipo_usuario'] == 'tecnico'),
            );
            _carregando = false;
          });
        }
      } else {
        // ✅ 403/erro NÃO pode deixar a tela "carregando" pra sempre.
        if (mounted) setState(() => _carregando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _gerarPDF() async {
    if (_tecnicoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um técnico primeiro'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() => _gerando = true);
    try {
      final auth = Get.find<AuthService>();
      final response = await http.get(
        Uri.parse(
            '$baseUrl/seguranca/relatorio-epi/$_tecnicoSelecionado'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'X-Tenant-Code': auth.tenantCode ?? '',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          await abrirVisualizadorPdf(context, response.bodyBytes,
              titulo: 'Relatório de EPI — ${_tecnicoNome ?? 'Técnico'}');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao gerar PDF: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  String _iniciais(String nome) {
    final p = nome.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[p.length - 1][0]}'.toUpperCase();
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16, left: 8, right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A2A1A), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFF00FF88), size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Relatório de EPI',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      Text('Ficha de Controle Individual',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _carregando
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00FF88), strokeWidth: 2.5))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.06)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.description_outlined,
                            color: Color(0xFF00FF88), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('Ficha de Controle de EPI',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight:
                                      FontWeight.w600)),
                              SizedBox(height: 3),
                              Text(
                                'Histórico completo com CA e fornecedor',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text('Selecione o Técnico',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 10),

                  // Lista de técnicos
                  if (_tecnicos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                          'Nenhum técnico encontrado',
                          style: TextStyle(
                              color: Colors.white54)),
                    )
                  else
                    ...List.generate(_tecnicos.length, (i) {
                      final tec = _tecnicos[i];
                      final id = tec['id'] as int;
                      final nome = tec['nome'] as String;
                      final sel = _tecnicoSelecionado == id;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                            milliseconds: 200 + i * 40),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _tecnicoSelecionado = id;
                            _tecnicoNome = nome;
                          }),
                          child: AnimatedContainer(
                            duration:
                            const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(
                                bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF00FF88)
                                  .withOpacity(0.08)
                                  : const Color(0xFF181818),
                              borderRadius:
                              BorderRadius.circular(14),
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF00FF88)
                                    : Colors.white
                                    .withOpacity(0.07),
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: sel
                                          ? [
                                        const Color(
                                            0xFF00FF88)
                                            .withOpacity(0.3),
                                        const Color(
                                            0xFF00FF88)
                                            .withOpacity(0.1),
                                      ]
                                          : [
                                        Colors.white
                                            .withOpacity(0.08),
                                        Colors.white
                                            .withOpacity(0.04),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: sel
                                          ? const Color(0xFF00FF88)
                                          .withOpacity(0.4)
                                          : Colors.white12,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _iniciais(nome),
                                      style: TextStyle(
                                        color: sel
                                            ? const Color(
                                            0xFF00FF88)
                                            : Colors.white38,
                                        fontWeight:
                                        FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(nome,
                                      style: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : Colors.white60,
                                        fontSize: 14,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      )),
                                ),
                                if (sel)
                                  const Icon(
                                      Icons
                                          .check_circle_rounded,
                                      color: Color(0xFF00FF88),
                                      size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Botão fixo embaixo — sempre visível, sem precisar rolar a lista
          if (!_carregando)
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _gerando ||
                      _tecnicoSelecionado == null
                      ? null
                      : _gerarPDF,
                  icon: _gerando
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black))
                      : const Icon(Icons.download_rounded,
                      color: Colors.black),
                  label: Text(
                    _gerando
                        ? 'Gerando PDF...'
                        : 'Gerar Relatório PDF',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    _tecnicoSelecionado == null
                        ? Colors.white12
                        : const Color(0xFF00FF88),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}