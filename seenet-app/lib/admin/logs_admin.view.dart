// lib/admin/logs_admin.view.dart — REDESIGN (funções inalteradas)
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../services/audit_service.dart';
import 'dart:developer' as developer;
import 'package:seenet/widgets/app_snackbar.dart';

class LogsAdminView extends StatefulWidget {
  const LogsAdminView({super.key});

  @override
  State<LogsAdminView> createState() => _LogsAdminViewState();
}

class _LogsAdminViewState extends State<LogsAdminView>
    with SingleTickerProviderStateMixin {
  final AuditService _audit = AuditService.instance;

  List<Map<String, dynamic>> logs = [];
  Map<String, dynamic> estatisticas = {};
  bool isLoading = true;

  String? filtroNivel;
  String? filtroAcao;
  DateTime? filtroDataInicio;
  DateTime? filtroDataFim;

  int paginaAtual = 0;
  final int itensPorPagina = 50;

  late TabController _tabController;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> carregarDados() async {
    try {
      setState(() => isLoading = true);
      try {
        await _audit.getEstatisticasRapidas();
        developer.log('✅ Autenticação OK - Token presente');
      } catch (authError) {
        developer.log('❌ ERRO DE AUTENTICAÇÃO: $authError');
        if (!mounted) return;
        AppSnackbar.show('🔒 Sessão Expirada',
            'Sua sessão expirou. Por favor, faça login novamente.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.TOP);
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAllNamed('/login');
        });
        return;
      }
      logs = await _audit.buscarLogs(
        nivel: filtroNivel,
        acao: filtroAcao,
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
        limite: itensPorPagina,
        offset: paginaAtual * itensPorPagina,
      );
      estatisticas = await _audit.gerarRelatorio(
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
      );
      var stats = await _audit.getEstatisticasRapidas();
      estatisticas['rapidas'] = stats;
      developer.log('📊 ${logs.length} logs carregados da API');
    } catch (e) {
      developer.log('❌ Erro ao carregar logs: $e');
      if (!mounted) return;
      AppSnackbar.show('Erro', 'Erro ao carregar logs da API',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _getCorNivel(String nivel) {
    switch (nivel.toLowerCase()) {
      case 'error': return Colors.red;
      case 'warning': return Colors.orange;
      case 'info':
      default: return Colors.blue;
    }
  }

  IconData _getIconeAcao(String acao) {
    String u = acao.toUpperCase();
    if (u.contains('LOGIN')) return Icons.login;
    if (u.contains('LOGOUT')) return Icons.logout;
    if (u.contains('USER')) return Icons.person;
    if (u.contains('PASSWORD')) return Icons.lock;
    if (u.contains('CHECKMARK')) return Icons.check_box;
    if (u.contains('CATEGORY')) return Icons.folder;
    if (u.contains('EVALUATION')) return Icons.assessment;
    if (u.contains('DIAGNOSTIC')) return Icons.medical_services;
    if (u.contains('TRANSCRIPTION') || u.contains('DOCUMENT')) return Icons.description;
    if (u.contains('DATA')) return Icons.storage;
    if (u.contains('CONFIG')) return Icons.settings;
    if (u.contains('UNAUTHORIZED')) return Icons.block;
    if (u.contains('SUSPICIOUS')) return Icons.warning;
    return Icons.info;
  }

  String _formatarAcao(String acao) {
    return acao.replaceAll('_', ' ').toLowerCase().split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatarDataHora(dynamic data) {
    if (data == null) return 'N/A';
    try {
      DateTime dt = data is DateTime ? data : DateTime.parse(data.toString());
      return DateFormat('dd/MM HH:mm').format(dt.toLocal());
    } catch (_) { return 'Data inválida'; }
  }

  String _formatarDataHoraCompleta(dynamic data) {
    if (data == null) return 'N/A';
    try {
      DateTime dt = data is DateTime ? data : DateTime.parse(data.toString());
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt.toLocal());
    } catch (_) { return 'Data inválida'; }
  }

  Future<void> _selecionarData(bool isInicio) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00FF88),
            onPrimary: Colors.black,
            surface: Color(0xFF2A2A2A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isInicio) filtroDataInicio = picked;
        else filtroDataFim = picked;
        paginaAtual = 0;
      });
      carregarDados();
    }
  }

  void _mostrarDetalhesAlerta(Map<String, dynamic> alerta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              alerta['nivel'] == 'error' ? Icons.error : Icons.warning,
              color: alerta['nivel'] == 'error' ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 12),
            const Text('Detalhes do Alerta',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetalheRow('Ação', alerta['acao']),
              _buildDetalheRow('Nível', alerta['nivel'] ?? 'N/A'),
              _buildDetalheRow('Data/Hora', _formatarDataHoraCompleta(alerta['data_acao'])),
              if (alerta['usuario_id'] != null)
                _buildDetalheRow('Usuário ID', alerta['usuario_id'].toString()),
              const SizedBox(height: 12),
              const Text('Detalhes:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(alerta['detalhes'] ?? 'Sem detalhes adicionais',
                    style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Color(0xFF00FF88))),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarLogs() async {
    try {
      developer.log('🔍 Iniciando exportação de logs...');
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      String dados = await _audit.exportarLogs(
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
        formato: 'csv',
      );
      developer.log('🔍 Dados: ${dados.length} chars');
      Navigator.of(Get.overlayContext!).pop();
      await Future.delayed(const Duration(milliseconds: 100));
      if (dados.isEmpty) {
        if (!mounted) return;
        AppSnackbar.show('Aviso', 'Nenhum dado para exportar no período selecionado',
            backgroundColor: Colors.orange, colorText: Colors.white,
            duration: const Duration(seconds: 3));
        return;
      }
      await _salvarArquivoCSV(dados);
    } catch (e, st) {
      developer.log('❌ ERRO em _exportarLogs: $e\n$st');
      try { Navigator.of(Get.overlayContext!).pop(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      AppSnackbar.show('Erro', 'Erro ao exportar logs: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white,
          duration: const Duration(seconds: 3));
    }
  }

  Future<void> _salvarArquivoCSV(String conteudo) async {
    try {
      if (kIsWeb) {
        AppSnackbar.show('Aviso', 'Download não disponível na versão web',
            backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }
      dynamic directory;
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) status = await Permission.storage.request();
        if (status.isGranted) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) directory = await getExternalStorageDirectory();
        } else {
          throw Exception('Permissão de armazenamento negada');
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        directory = await getDownloadsDirectory();
      }
      if (directory == null) throw Exception('Não foi possível acessar o diretório');
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String nomeArquivo = 'logs_auditoria_$timestamp.csv';
      await File('${directory.path}/$nomeArquivo').writeAsString(conteudo);
      if (!mounted) return;
      AppSnackbar.show('Sucesso', 'Arquivo salvo: $nomeArquivo',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      developer.log('❌ Erro ao salvar arquivo: $e');
      if (!mounted) return;
      AppSnackbar.show('Erro', 'Erro ao salvar arquivo: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _limparLogsAntigos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Limpar Logs Antigos', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Isso removerá logs informativos com mais de 90 dias.',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 12),
            Text('✅ Logs de INFO com mais de 90 dias serão removidos',
                style: TextStyle(color: Colors.green, fontSize: 13)),
            SizedBox(height: 6),
            Text('⚠️ Logs de WARNING e ERROR serão mantidos',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
            SizedBox(height: 12),
            Text('Deseja continuar?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                await _audit.limparLogsAntigos(diasParaManter: 90);
                Navigator.of(Get.overlayContext!).pop();
                await Future.delayed(const Duration(milliseconds: 100));
                if (!mounted) return;
                AppSnackbar.show('Sucesso', 'Logs antigos removidos com sucesso!',
                    backgroundColor: Colors.green, colorText: Colors.white,
                    duration: const Duration(seconds: 3));
                carregarDados();
              } catch (e) {
                try { Navigator.of(Get.overlayContext!).pop(); } catch (_) {}
                await Future.delayed(const Duration(milliseconds: 100));
                if (!mounted) return;
                AppSnackbar.show('Erro', 'Erro ao limpar logs: ${e.toString()}',
                    backgroundColor: Colors.red, colorText: Colors.white,
                    duration: const Duration(seconds: 3));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Limpar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 0, left: 8, right: 8,
            ),
            color: const Color(0xFF111111),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.security_outlined, color: Colors.orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Logs de Auditoria',
                              style: TextStyle(color: Colors.white, fontSize: 19,
                                  fontWeight: FontWeight.w700)),
                          Text('Rastreio de ações do sistema',
                              style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20),
                      onPressed: carregarDados,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white38),
                      color: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'exportar') _exportarLogs();
                        else if (v == 'limpar') _limparLogsAntigos();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'exportar',
                            child: Row(children: [
                              Icon(Icons.download_rounded, color: Colors.blue, size: 18),
                              SizedBox(width: 10),
                              Text('Exportar Logs', style: TextStyle(color: Colors.white70)),
                            ])),
                        PopupMenuItem(value: 'limpar',
                            child: Row(children: [
                              Icon(Icons.cleaning_services_rounded, color: Colors.orange, size: 18),
                              SizedBox(width: 10),
                              Text('Limpar Logs Antigos', style: TextStyle(color: Colors.white70)),
                            ])),
                      ],
                    ),
                  ],
                ),
                // Fuso
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.white24, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        'Horários em ${DateTime.now().timeZoneName} '
                            '(${DateTime.now().timeZoneOffset.inHours >= 0 ? '+' : ''}'
                            '${DateTime.now().timeZoneOffset.inHours}h)',
                        style: const TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                // Tabs
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(fontSize: 12),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Logs'),
                      Tab(text: 'Dashboard'),
                      Tab(text: 'Alertas'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2.5))
                : TabBarView(
              controller: _tabController,
              children: [
                _buildLogsTab(),
                _buildDashboardTab(),
                _buildAlertasTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB LOGS ─────────────────────────────────────────────────

  Widget _buildLogsTab() {
    return Column(
      children: [
        _buildFiltros(),
        Expanded(
          child: logs.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security_outlined, size: 52,
                    color: Colors.white.withOpacity(0.06)),
                const SizedBox(height: 12),
                const Text('Nenhum log encontrado',
                    style: TextStyle(color: Colors.white38, fontSize: 15)),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: logs.length,
            itemBuilder: (context, i) => _buildLogCard(logs[i]),
          ),
        ),
        if (logs.isNotEmpty) _buildPaginacao(),
      ],
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: const Color(0xFF181818),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _dropdownFiltro<String>(
                label: 'Nível',
                value: filtroNivel,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: 'info', child: Text('Info')),
                  DropdownMenuItem(value: 'warning', child: Text('Aviso')),
                  DropdownMenuItem(value: 'error', child: Text('Erro')),
                ],
                onChanged: (v) { setState(() { filtroNivel = v; paginaAtual = 0; }); carregarDados(); },
              )),
              const SizedBox(width: 10),
              Expanded(child: _dropdownFiltro<String>(
                label: 'Ação',
                value: filtroAcao,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todas')),
                  DropdownMenuItem(value: 'LOGIN_SUCCESS', child: Text('Login')),
                  DropdownMenuItem(value: 'LOGIN_FAILED', child: Text('Login Falhou')),
                  DropdownMenuItem(value: 'LOGOUT', child: Text('Logout')),
                  DropdownMenuItem(value: 'USER_CREATED', child: Text('Usuário Criado')),
                  DropdownMenuItem(value: 'USER_UPDATED', child: Text('Usuário Atualizado')),
                  DropdownMenuItem(value: 'USER_DELETED', child: Text('Usuário Deletado')),
                  DropdownMenuItem(value: 'PASSWORD_CHANGED', child: Text('Senha Alterada')),
                  DropdownMenuItem(value: 'PASSWORD_RESET', child: Text('Senha Resetada')),
                  DropdownMenuItem(value: 'CHECKMARK_CREATED', child: Text('Checkmark Criado')),
                  DropdownMenuItem(value: 'CHECKMARK_UPDATED', child: Text('Checkmark Atualizado')),
                  DropdownMenuItem(value: 'CHECKMARK_DELETED', child: Text('Checkmark Deletado')),
                  DropdownMenuItem(value: 'CATEGORY_CREATED', child: Text('Categoria Criada')),
                  DropdownMenuItem(value: 'CATEGORY_UPDATED', child: Text('Categoria Atualizada')),
                  DropdownMenuItem(value: 'CATEGORY_DELETED', child: Text('Categoria Deletada')),
                  DropdownMenuItem(value: 'EVALUATION_STARTED', child: Text('Avaliação Iniciada')),
                  DropdownMenuItem(value: 'EVALUATION_COMPLETED', child: Text('Avaliação Finalizada')),
                  DropdownMenuItem(value: 'EVALUATION_CANCELLED', child: Text('Avaliação Cancelada')),
                  DropdownMenuItem(value: 'DIAGNOSTIC_GENERATED', child: Text('Diagnóstico Gerado')),
                  DropdownMenuItem(value: 'DIAGNOSTIC_FAILED', child: Text('Diagnóstico Falhou')),
                  DropdownMenuItem(value: 'DOCUMENT_CREATED', child: Text('Documento Criado')),
                  DropdownMenuItem(value: 'TRANSCRIPTION_STARTED', child: Text('Transcrição Iniciada')),
                  DropdownMenuItem(value: 'TRANSCRIPTION_COMPLETED', child: Text('Transcrição Completa')),
                  DropdownMenuItem(value: 'DATA_EXPORTED', child: Text('Dados Exportados')),
                  DropdownMenuItem(value: 'CONFIG_CHANGED', child: Text('Config Alterada')),
                  DropdownMenuItem(value: 'UNAUTHORIZED_ACCESS', child: Text('Acesso Não Autorizado')),
                ],
                onChanged: (v) { setState(() { filtroAcao = v; paginaAtual = 0; }); carregarDados(); },
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _datePicker(true)),
              const SizedBox(width: 10),
              Expanded(child: _datePicker(false)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    filtroNivel = null; filtroAcao = null;
                    filtroDataInicio = null; filtroDataFim = null;
                    paginaAtual = 0;
                  });
                  carregarDados();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.clear_all_rounded, color: Colors.orange, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdownFiltro<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          dropdownColor: const Color(0xFF1A1A1A),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePicker(bool isInicio) {
    final data = isInicio ? filtroDataInicio : filtroDataFim;
    return GestureDetector(
      onTap: () => _selecionarData(isInicio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: data != null ? Colors.orange.withOpacity(0.4) : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: data != null ? Colors.orange : Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(
              data != null ? DateFormat('dd/MM/yy').format(data) : (isInicio ? 'Início' : 'Fim'),
              style: TextStyle(
                  color: data != null ? Colors.orange : Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final nivel = log['nivel'] as String? ?? 'info';
    final acao = log['acao'] as String? ?? 'N/A';
    final detalhes = log['detalhes'] as String?;
    final dataAcao = log['data_acao'];
    final usuarioNome = log['usuario_nome'] as String? ?? 'Sistema';
    final cor = _getCorNivel(nivel);
    final icone = _getIconeAcao(acao);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.15)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, color: cor, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(_formatarAcao(acao),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(nivel.toUpperCase(),
                  style: TextStyle(color: cor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(detalhes ?? 'Sem detalhes',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(_formatarDataHora(dataAcao),
                  style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white24,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetalheRow('ID', log['id'].toString()),
                if (log['usuario_id'] != null)
                  _buildDetalheRow('Usuário', '$usuarioNome (ID: ${log['usuario_id']})'),
                _buildDetalheRow('Ação', acao),
                _buildDetalheRow('Nível', nivel.toUpperCase()),
                if (log['tabela_afetada'] != null) _buildDetalheRow('Tabela', log['tabela_afetada']),
                if (log['registro_id'] != null) _buildDetalheRow('Registro ID', log['registro_id'].toString()),
                if (log['ip_address'] != null) _buildDetalheRow('IP', log['ip_address']),
                _buildDetalheRow('Data/Hora', _formatarDataHoraCompleta(dataAcao)),
                if (detalhes != null && detalhes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Detalhes:',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(detalhes, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalheRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildPaginacao() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: paginaAtual > 0
                ? () { setState(() => paginaAtual--); carregarDados(); }
                : null,
            icon: Icon(Icons.chevron_left_rounded,
                color: paginaAtual > 0 ? Colors.white : Colors.white24),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Text('Página ${paginaAtual + 1}',
                style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ),
          IconButton(
            onPressed: logs.length == itensPorPagina
                ? () { setState(() => paginaAtual++); carregarDados(); }
                : null,
            icon: Icon(Icons.chevron_right_rounded,
                color: logs.length == itensPorPagina ? Colors.white : Colors.white24),
          ),
        ],
      ),
    );
  }

  // ── TAB DASHBOARD ────────────────────────────────────────────

  Widget _buildDashboardTab() {
    if (estatisticas.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2.5));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (estatisticas['rapidas'] != null) ...[
            Row(children: [
              Expanded(child: _buildStatCard('Logs (24h)',
                  (estatisticas['rapidas']['logs_24h'] ?? 0).toString(),
                  Icons.history_rounded, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Ações Críticas',
                  (estatisticas['rapidas']['acoes_criticas'] ?? 0).toString(),
                  Icons.warning_rounded, Colors.orange)),
            ]),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF181818),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(child: Text('Estatísticas rápidas não disponíveis',
                    style: TextStyle(color: Colors.white54))),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          if (estatisticas['resumo'] != null) ...[
            _sectionLabel('Resumo Geral'),
            const SizedBox(height: 10),
            _buildResumoCard('Total de Logs',
                (estatisticas['resumo']['total_logs'] ?? 0).toString(),
                Icons.list_alt_rounded),
            const SizedBox(height: 16),
            if (estatisticas['resumo']['por_nivel'] != null &&
                (estatisticas['resumo']['por_nivel'] as List).isNotEmpty) ...[
              _sectionLabel('Logs por Nível'),
              const SizedBox(height: 10),
              ...((estatisticas['resumo']['por_nivel'] as List).map((item) =>
                  _buildNivelBar(item['nivel']?.toString() ?? 'unknown',
                      item['total'], estatisticas['resumo']['total_logs']))),
            ],
          ] else ...[
            const Text('Nenhuma estatística disponível',
                style: TextStyle(color: Colors.white38)),
          ],
          if (estatisticas['usuarios_ativos'] != null &&
              (estatisticas['usuarios_ativos'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionLabel('Usuários Mais Ativos'),
            const SizedBox(height: 10),
            ...((estatisticas['usuarios_ativos'] as List).take(5)
                .map((user) => _buildUsuarioAtivoCard(user))),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(width: 3, height: 14,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: Colors.orange, borderRadius: BorderRadius.circular(2))),
        Text(label, style: const TextStyle(
            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildResumoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 24),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text(value, style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNivelBar(String nivel, dynamic total, dynamic totalGeral) {
    int totalInt = total is int ? total : (total is String ? int.tryParse(total) ?? 0 : 0);
    int totalGeralInt = totalGeral is int ? totalGeral : (totalGeral is String ? int.tryParse(totalGeral) ?? 1 : 1);
    double percentual = totalGeralInt > 0 ? (totalInt / totalGeralInt) * 100 : 0;
    Color cor = _getCorNivel(nivel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(nivel.toUpperCase(),
                  style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12)),
              Text('$totalInt (${percentual.toStringAsFixed(1)}%)',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentual / 100,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(cor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsuarioAtivoCard(Map<String, dynamic> user) {
    final nome = user['nome'] as String? ?? 'Usuário';
    final iniciais = nome.trim().split(' ')
        .where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00FF88).withOpacity(0.12),
              border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
            ),
            child: Center(child: Text(iniciais,
                style: const TextStyle(color: Color(0xFF00FF88),
                    fontWeight: FontWeight.bold, fontSize: 12))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w500, fontSize: 13)),
                if (user['email'] != null)
                  Text(user['email'], style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${user['total_acoes']} ações',
                style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── TAB ALERTAS ──────────────────────────────────────────────

  Widget _buildAlertasTab() {
    final alertas = logs
        .where((log) => log['nivel'] == 'warning' || log['nivel'] == 'error')
        .toList();

    if (alertas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF00FF88)),
            ),
            const SizedBox(height: 14),
            const Text('Nenhum alerta no momento',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('O sistema está operando normalmente',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: alertas.length,
      itemBuilder: (context, index) {
        final alerta = alertas[index];
        final isError = alerta['nivel'] == 'error';
        final cor = isError ? Colors.red : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cor.withOpacity(0.25)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Icon(isError ? Icons.error_rounded : Icons.warning_rounded,
                color: cor, size: 28),
            title: Text(_formatarAcao(alerta['acao']),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alerta['detalhes'] ?? 'Sem detalhes',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_formatarDataHora(alerta['data_acao']),
                    style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
            trailing: GestureDetector(
              onTap: () => _mostrarDetalhesAlerta(alerta),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.visibility_rounded, color: cor, size: 16),
              ),
            ),
          ),
        );
      },
    );
  }
}