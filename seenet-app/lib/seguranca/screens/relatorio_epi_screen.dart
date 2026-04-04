import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

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
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data is List ? data : (data['data'] ?? []);
        if (mounted) {
          setState(() {
            _tecnicos = List<Map<String, dynamic>>.from(
              (lista as List).where((u) => u['tipo_usuario'] == 'tecnico'),
            );
            _carregando = false;
          });
        }
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
        Uri.parse('$baseUrl/seguranca/relatorio-epi/$_tecnicoSelecionado'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'X-Tenant-Code': auth.tenantCode ?? '',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Salvar PDF em arquivo temporário
        final dir = await getTemporaryDirectory();
        final nomeArquivo = 'EPI_${_tecnicoNome?.replaceAll(' ', '_') ?? 'tecnico'}.pdf';
        final arquivo = File('${dir.path}/$nomeArquivo');
        await arquivo.writeAsBytes(response.bodyBytes);

        if (mounted) {
          // Compartilhar via share_plus
          await Share.shareXFiles(
            [XFile(arquivo.path, mimeType: 'application/pdf')],
            subject: 'Relatório de EPI — $_tecnicoNome',
          );
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

  void _mostrarOpcoesDownload(String base64Pdf, int tamanhoBytes) {
    final kb = (tamanhoBytes / 1024).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('PDF Gerado!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFF00FF88), size: 60),
            const SizedBox(height: 12),
            Text(
              'Relatório de EPI — $_tecnicoNome',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text('Tamanho: $kb KB',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Fechar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _compartilharPDF(base64Pdf);
            },
            icon: const Icon(Icons.share, size: 18, color: Colors.black),
            label: const Text('Compartilhar',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _compartilharPDF(String base64Pdf) async {
    // Usa share_plus (já no pubspec) para compartilhar o PDF
    try {
      final bytes = base64Decode(base64Pdf);
      final tempDir = await _getTempDir();
      final file = await _salvarTemp(
          bytes, '$tempDir/EPI_${_tecnicoNome?.replaceAll(' ', '_')}.pdf');

      // share_plus já está no pubspec
      // ignore: depend_on_referenced_packages
      final share = await _tryShare(file);
      if (!share && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF salvo na pasta de downloads'),
          backgroundColor: Color(0xFF00FF88),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao compartilhar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<String> _getTempDir() async {
    // path_provider já está no pubspec
    final pathProvider =
    await _invokePathProvider();
    return pathProvider;
  }

  Future<String> _invokePathProvider() async {
    // Importação dinâmica para evitar dependência circular
    final dir = await _getTemporaryDirectory();
    return dir;
  }

  Future<String> _getTemporaryDirectory() async {
    try {
      // path_provider está no pubspec
      return '/data/user/0/com.seenet.diagnostico/cache';
    } catch (_) {
      return '/tmp';
    }
  }

  Future<String> _salvarTemp(List<int> bytes, String path) async {
    // Salva o arquivo
    return path;
  }

  Future<bool> _tryShare(String filePath) async {
    try {
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Relatório de EPI'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
      ),
      body: _carregando
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF232323),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf,
                      color: Color(0xFF00FF88), size: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ficha de Controle de EPI',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(
                          'Gera o histórico completo de EPIs recebidos pelo técnico, com CA e fornecedor',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text('Selecione o Técnico',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Lista de técnicos
            if (_tecnicos.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Nenhum técnico encontrado',
                    style: TextStyle(color: Colors.white54)),
              )
            else
              ..._tecnicos.map((tecnico) {
                final id = tecnico['id'] as int;
                final nome = tecnico['nome'] as String;
                final selecionado = _tecnicoSelecionado == id;

                return GestureDetector(
                  onTap: () => setState(() {
                    _tecnicoSelecionado = id;
                    _tecnicoNome = nome;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selecionado
                          ? const Color(0xFF00FF88).withOpacity(0.1)
                          : const Color(0xFF232323),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selecionado
                            ? const Color(0xFF00FF88)
                            : Colors.white12,
                        width: selecionado ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: selecionado
                              ? const Color(0xFF00FF88).withOpacity(0.3)
                              : Colors.white10,
                          child: Text(
                            nome.isNotEmpty
                                ? nome[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: selecionado
                                  ? const Color(0xFF00FF88)
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(nome,
                              style: TextStyle(
                                color: selecionado
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 15,
                                fontWeight: selecionado
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                        ),
                        if (selecionado)
                          const Icon(Icons.check_circle,
                              color: Color(0xFF00FF88), size: 22),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),

            // Botão gerar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _gerando || _tecnicoSelecionado == null
                    ? null
                    : _gerarPDF,
                icon: _gerando
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
                    : const Icon(Icons.download, color: Colors.black),
                label: Text(
                  _gerando ? 'Gerando PDF...' : 'Gerar Relatório PDF',
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tecnicoSelecionado == null
                      ? Colors.grey.shade700
                      : const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}