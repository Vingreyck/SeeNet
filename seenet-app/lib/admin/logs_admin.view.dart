// lib/admin/logs_admin.view.dart - VERSÃO CORRIGIDA
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../services/audit_service.dart';
import 'dart:developer' as developer;

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
  
  // Filtros
  String? filtroNivel;
  String? filtroAcao;
  DateTime? filtroDataInicio;
  DateTime? filtroDataFim;
  
  // Paginação
  int paginaAtual = 0;
  final int itensPorPagina = 50;
  
  late TabController _tabController;
  
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
      
      // Verificar autenticação
      try {
        await _audit.getEstatisticasRapidas();
        developer.log('✅ Autenticação OK - Token presente');
      } catch (authError) {
        developer.log('❌ ERRO DE AUTENTICAÇÃO: $authError');
        
        if (!mounted) return;
        
        Get.snackbar(
          '🔒 Sessão Expirada',
          'Sua sessão expirou. Por favor, faça login novamente.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.TOP,
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAllNamed('/login');
        });
        
        return;
      }
      
      // Carregar logs via API
      logs = await _audit.buscarLogs(
        nivel: filtroNivel,
        acao: filtroAcao,
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
        limite: itensPorPagina,
        offset: paginaAtual * itensPorPagina,
      );
      
      // Carregar estatísticas via API
      estatisticas = await _audit.gerarRelatorio(
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
      );
      
      // Estatísticas rápidas
      var stats = await _audit.getEstatisticasRapidas();
      estatisticas['rapidas'] = stats;
      
      developer.log('📊 ${logs.length} logs carregados da API');
    } catch (e) {
      developer.log('❌ Erro ao carregar logs: $e');
      
      if (!mounted) return;
      
      Get.snackbar(
        'Erro',
        'Erro ao carregar logs da API',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de Auditoria'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregarDados,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'exportar':
                  _exportarLogs();
                  break;
                case 'limpar':
                  _limparLogsAntigos();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'exportar',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Exportar Logs'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'limpar',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Limpar Logs Antigos'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Logs', icon: Icon(Icons.list)),
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Alertas', icon: Icon(Icons.warning)),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF2A2A2A),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Horários em ${DateTime.now().timeZoneName} (${DateTime.now().timeZoneOffset.inHours > 0 ? '+' : ''}${DateTime.now().timeZoneOffset.inHours}h)',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FF88),
                    ),
                  )
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
  
  // ========== TAB DE LOGS ==========
  Widget _buildLogsTab() {
    return Column(
      children: [
        _buildFiltros(),
        Expanded(
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum log encontrado',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return _buildLogCard(logs[index]);
                  },
                ),
        ),
        if (logs.isNotEmpty) _buildPaginacao(),
      ],
    );
  }
  
  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2A2A2A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: filtroNivel,
                  decoration: InputDecoration(
                    labelText: 'Nível',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  dropdownColor: const Color(0xFF3A3A3A),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Aviso')),
                    DropdownMenuItem(value: 'error', child: Text('Erro')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      filtroNivel = value;
                      paginaAtual = 0;
                    });
                    carregarDados();
                  },
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: filtroAcao,
                  decoration: InputDecoration(
                    labelText: 'Ação',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  dropdownColor: const Color(0xFF3A3A3A),
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
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
                  onChanged: (value) {
                    setState(() {
                      filtroAcao = value;
                      paginaAtual = 0;
                    });
                    carregarDados();
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selecionarData(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          filtroDataInicio != null
                              ? DateFormat('dd/MM/yyyy').format(filtroDataInicio!)
                              : 'Data Início',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: InkWell(
                  onTap: () => _selecionarData(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          filtroDataFim != null
                              ? DateFormat('dd/MM/yyyy').format(filtroDataFim!)
                              : 'Data Fim',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              IconButton(
                onPressed: () {
                  setState(() {
                    filtroNivel = null;
                    filtroAcao = null;
                    filtroDataInicio = null;
                    filtroDataFim = null;
                    paginaAtual = 0;
                  });
                  carregarDados();
                },
                icon: const Icon(Icons.clear_all, color: Colors.orange),
                tooltip: 'Limpar Filtros',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogCard(Map<String, dynamic> log) {
    String nivel = log['nivel'] ?? 'info';
    String acao = log['acao'] ?? 'N/A';
    String? detalhes = log['detalhes'];
    dynamic dataAcao = log['data_acao'];
    String usuarioNome = log['usuario_nome'] ?? 'Sistema';
    
    Color corNivel = _getCorNivel(nivel);
    IconData iconeAcao = _getIconeAcao(acao);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2A2A2A),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: corNivel.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            iconeAcao,
            color: corNivel,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _formatarAcao(acao),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              _formatarDataHora(dataAcao),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Text(
          detalhes ?? 'Sem detalhes',
          style: const TextStyle(color: Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetalheRow('ID', log['id'].toString()),
                if (log['usuario_id'] != null)
                  _buildDetalheRow('Usuário', '$usuarioNome (ID: ${log['usuario_id']})'),
                _buildDetalheRow('Ação', acao),
                _buildDetalheRow('Nível', nivel.toUpperCase()),
                if (log['tabela_afetada'] != null)
                  _buildDetalheRow('Tabela', log['tabela_afetada']),
                if (log['registro_id'] != null)
                  _buildDetalheRow('Registro ID', log['registro_id'].toString()),
                if (log['ip_address'] != null)
                  _buildDetalheRow('IP', log['ip_address']),
                _buildDetalheRow('Data/Hora', _formatarDataHoraCompleta(dataAcao)),
                
                if (detalhes != null && detalhes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Detalhes:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detalhes,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaginacao() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2A2A2A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: paginaAtual > 0
                ? () {
                    setState(() => paginaAtual--);
                    carregarDados();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            color: Colors.white,
          ),
          Text(
            'Página ${paginaAtual + 1}',
            style: const TextStyle(color: Colors.white),
          ),
          IconButton(
            onPressed: logs.length == itensPorPagina
                ? () {
                    setState(() => paginaAtual++);
                    carregarDados();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
  
// ========== TAB DASHBOARD ==========
Widget _buildDashboardTab() {
  if (estatisticas.isEmpty) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF00FF88)),
    );
  }
  
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cards de estatísticas rápidas
        if (estatisticas['rapidas'] != null) ...[
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Logs (24h)',
                  (estatisticas['rapidas']['logs_24h'] ?? 0).toString(),
                  Icons.history,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Ações Críticas',
                  (estatisticas['rapidas']['acoes_criticas'] ?? 0).toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ] else ...[
          // Se não tem dados rápidos, mostrar mensagem
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Estatísticas rápidas não disponíveis',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Resumo geral
        if (estatisticas['resumo'] != null) ...[
          const Text(
            'Resumo Geral',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildResumoCard(
            'Total de Logs',
            (estatisticas['resumo']['total_logs'] ?? 0).toString(),
            Icons.list_alt,
          ),
          
          const SizedBox(height: 20),
          
          // Logs por nível
          if (estatisticas['resumo']['por_nivel'] != null && 
              (estatisticas['resumo']['por_nivel'] as List).isNotEmpty) ...[
            const Text(
              'Logs por Nível',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
          // ✅ CORREÇÃO: Passar valores dinâmicos para _buildNivelBar
          ...((estatisticas['resumo']['por_nivel'] as List))
              .map((item) => _buildNivelBar(
                    item['nivel']?.toString() ?? 'unknown',
                    item['total'], // ← Não converter aqui, deixar como dynamic
                    estatisticas['resumo']['total_logs'], // ← Não converter aqui
                  )),
          ],
        ] else ...[
          const Text(
            'Nenhuma estatística disponível para o período selecionado',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
        
        const SizedBox(height: 30),
        
        // Usuários mais ativos
        if (estatisticas['usuarios_ativos'] != null &&
            (estatisticas['usuarios_ativos'] as List).isNotEmpty) ...[
          const Text(
            'Usuários Mais Ativos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          ...((estatisticas['usuarios_ativos'] as List).take(5))
              .map((user) => _buildUsuarioAtivoCard(user)),
        ],
      ],
    ),
  );
}
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResumoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00FF88), size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
Widget _buildNivelBar(String nivel, dynamic total, dynamic totalGeral) {
  // ✅ Converter para int se vier como String
  int totalInt = total is int ? total : (total is String ? int.tryParse(total) ?? 0 : 0);
  int totalGeralInt = totalGeral is int ? totalGeral : (totalGeral is String ? int.tryParse(totalGeral) ?? 1 : 1);
  
  double percentual = totalGeralInt > 0 ? (totalInt / totalGeralInt) * 100 : 0;
  Color cor = _getCorNivel(nivel);
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              nivel.toUpperCase(),
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$totalInt (${percentual.toStringAsFixed(1)}%)',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentual / 100,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation<Color>(cor),
          minHeight: 8,
        ),
      ],
    ),
  );
}
  
  Widget _buildUsuarioAtivoCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF00FF88),
            radius: 20,
            child: Icon(Icons.person, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['nome'] ?? 'Usuário',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user['email'] != null)
                  Text(
                    user['email'],
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${user['total_acoes']} ações',
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // ========== TAB ALERTAS ==========
  Widget _buildAlertasTab() {
    List<Map<String, dynamic>> alertas = logs
        .where((log) => log['nivel'] == 'warning' || log['nivel'] == 'error')
        .toList();
    
    if (alertas.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhum alerta no momento',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Text(
              'O sistema está operando normalmente',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alertas.length,
      itemBuilder: (context, index) {
        var alerta = alertas[index];
        bool isError = alerta['nivel'] == 'error';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isError 
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: ListTile(
            leading: Icon(
              isError ? Icons.error : Icons.warning,
              color: isError ? Colors.red : Colors.orange,
              size: 32,
            ),
            title: Text(
              _formatarAcao(alerta['acao']),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta['detalhes'] ?? 'Sem detalhes',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatarDataHora(alerta['data_acao']),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.visibility, color: Colors.white54),
              onPressed: () => _mostrarDetalhesAlerta(alerta),
            ),
          ),
        );
      },
    );
  }
  
  // ========== MÉTODOS AUXILIARES ==========
  
  Color _getCorNivel(String nivel) {
    switch (nivel.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
      default:
        return Colors.blue;
    }
  }
  
  IconData _getIconeAcao(String acao) {
    String acaoUpper = acao.toUpperCase();
    if (acaoUpper.contains('LOGIN')) return Icons.login;
    if (acaoUpper.contains('LOGOUT')) return Icons.logout;
    if (acaoUpper.contains('USER')) return Icons.person;
    if (acaoUpper.contains('PASSWORD')) return Icons.lock;
    if (acaoUpper.contains('CHECKMARK')) return Icons.check_box;
    if (acaoUpper.contains('CATEGORY')) return Icons.folder;
    if (acaoUpper.contains('EVALUATION')) return Icons.assessment;
    if (acaoUpper.contains('DIAGNOSTIC')) return Icons.medical_services;
    if (acaoUpper.contains('TRANSCRIPTION') || acaoUpper.contains('DOCUMENT')) return Icons.description;
    if (acaoUpper.contains('DATA')) return Icons.storage;
    if (acaoUpper.contains('CONFIG')) return Icons.settings;
    if (acaoUpper.contains('UNAUTHORIZED')) return Icons.block;
    if (acaoUpper.contains('SUSPICIOUS')) return Icons.warning;
    return Icons.info;
  }
  
  String _formatarAcao(String acao) {
    return acao.replaceAll('_', ' ').toLowerCase().split(' ')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
  
  String _formatarDataHora(dynamic data) {
    if (data == null) return 'N/A';
    
    try {
      DateTime dt = data is DateTime ? data : DateTime.parse(data.toString());
      DateTime dtLocal = dt.toLocal();
      return DateFormat('dd/MM HH:mm').format(dtLocal);
    } catch (e) {
      return 'Data inválida';
    }
  }
  
  String _formatarDataHoraCompleta(dynamic data) {
    if (data == null) return 'N/A';
    
    try {
      DateTime dt = data is DateTime ? data : DateTime.parse(data.toString());
      DateTime dtLocal = dt.toLocal();
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dtLocal);
    } catch (e) {
      return 'Data inválida';
    }
  }
  
  Future<void> _selecionarData(bool isInicio) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FF88),
              onPrimary: Colors.black,
              surface: Color(0xFF2A2A2A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        if (isInicio) {
          filtroDataInicio = picked;
        } else {
          filtroDataFim = picked;
        }
        paginaAtual = 0;
      });
      carregarDados();
    }
  }
  
  void _mostrarDetalhesAlerta(Map<String, dynamic> alerta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Row(
          children: [
            Icon(
              alerta['nivel'] == 'error' ? Icons.error : Icons.warning,
              color: alerta['nivel'] == 'error' ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 12),
            const Text(
              'Detalhes do Alerta',
              style: TextStyle(color: Colors.white),
            ),
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
              const Text(
                'Detalhes:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alerta['detalhes'] ?? 'Sem detalhes adicionais',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Color(0xFF00FF88)),
            ),
          ),
        ],
      ),
    );
  }
  
Future<void> _exportarLogs() async {
  try {
    developer.log('🔍 Iniciando exportação de logs...');
    
    // Mostrar loading
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    
    String dados = await _audit.exportarLogs(
      dataInicio: filtroDataInicio,
      dataFim: filtroDataFim,
      formato: 'csv',
    );
    
    developer.log('🔍 Dados recebidos da API:');
    developer.log('   Tamanho: ${dados.length} caracteres');
    developer.log('   Vazio: ${dados.isEmpty}');
    developer.log('   Primeiros 100 chars: ${dados.length > 100 ? dados.substring(0, 100) : dados}');
    
    Navigator.of(Get.overlayContext!).pop();
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (dados.isEmpty) {
      developer.log('⚠️ Dados vazios - mostrando aviso');
      
      if (!mounted) return;
      
      Get.snackbar(
        'Aviso',
        'Nenhum dado para exportar no período selecionado',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    
    developer.log('✅ Dados não vazios - chamando _salvarArquivoCSV');
    
    // ✅ SALVAR O ARQUIVO
    await _salvarArquivoCSV(dados);
    
  } catch (e, stackTrace) {
    developer.log('❌ ERRO em _exportarLogs: $e');
    developer.log('Stack trace: $stackTrace');
    
    try {
      Navigator.of(Get.overlayContext!).pop();
    } catch (_) {}
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    Get.snackbar(
      'Erro',
      'Erro ao exportar logs: ${e.toString()}',
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}

  Future<void> _salvarArquivoCSV(String conteudo) async {
    try {
      // ✅ Web: não tem acesso ao sistema de arquivos
      if (kIsWeb) {
        Get.snackbar(
          'Aviso',
          'Download de arquivo não disponível na versão web',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      developer.log('🔍 Iniciando salvamento do arquivo...');

      dynamic directory;

      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        if (status.isGranted) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
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
      String caminho = '${directory.path}/$nomeArquivo';

      File arquivo = File(caminho);
      await arquivo.writeAsString(conteudo);

      if (!mounted) return;

      Get.snackbar(
        'Sucesso',
        'Arquivo salvo: $nomeArquivo',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

    } catch (e) {
      developer.log('❌ Erro ao salvar arquivo: $e');
      if (!mounted) return;
      Get.snackbar(
        'Erro',
        'Erro ao salvar arquivo: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

void _limparLogsAntigos() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text(
        'Limpar Logs Antigos',
        style: TextStyle(color: Colors.white),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Isso removerá logs informativos com mais de 90 dias.',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 16),
          Text(
            '✅ Logs de INFO com mais de 90 dias serão removidos',
            style: TextStyle(color: Colors.green, fontSize: 13),
          ),
          SizedBox(height: 8),
          Text(
            '⚠️ Logs de WARNING e ERROR serão mantidos',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
          SizedBox(height: 16),
          Text(
            'Deseja continuar?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context); // Fecha o dialog de confirmação
            
            try {
              // Mostrar loading
              Get.dialog(
                const Center(child: CircularProgressIndicator()),
                barrierDismissible: false,
              );
              
              await _audit.limparLogsAntigos(diasParaManter: 90);
              
              // ✅ Fechar loading APENAS UMA VEZ
              Navigator.of(Get.overlayContext!).pop();
              
              // Aguardar antes de mostrar snackbar
              await Future.delayed(const Duration(milliseconds: 100));
              
              if (!mounted) return;
              
              Get.snackbar(
                'Sucesso',
                'Logs antigos removidos com sucesso!',
                backgroundColor: Colors.green,
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
              
              // Recarregar dados
              carregarDados();
              
            } catch (e) {
              // Fechar loading se ainda estiver aberto
              try {
                Navigator.of(Get.overlayContext!).pop();
              } catch (_) {
                // Ignorar se já foi fechado
              }
              
              await Future.delayed(const Duration(milliseconds: 100));
              
              if (!mounted) return;
              
              Get.snackbar(
                'Erro',
                'Erro ao limpar logs: ${e.toString()}',
                backgroundColor: Colors.red,
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('Limpar'),
        ),
      ],
    ),
  );
}
}