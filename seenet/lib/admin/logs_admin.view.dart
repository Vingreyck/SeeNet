// lib/admin/logs_admin.view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/log_sistema.dart';
import '../services/audit_service.dart';
import '../services/database_helper.dart';

class LogsAdminView extends StatefulWidget {
  const LogsAdminView({super.key});

  @override
  State<LogsAdminView> createState() => _LogsAdminViewState();
}

class _LogsAdminViewState extends State<LogsAdminView> 
    with SingleTickerProviderStateMixin {
  List<LogSistema> logs = [];
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
      
      // Carregar logs
      logs = await AuditService.instance.buscarLogs(
        nivel: filtroNivel,
        acao: filtroAcao,
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
        limite: itensPorPagina,
        offset: paginaAtual * itensPorPagina,
      );
      
      // Carregar estatísticas
      estatisticas = await AuditService.instance.gerarRelatorio(
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
      );
      
      // Estatísticas rápidas
      var stats = await AuditService.instance.getEstatisticasRapidas();
      estatisticas['rapidas'] = stats;
      
      print('📊 ${logs.length} logs carregados');
    } catch (e) {
      print('❌ Erro ao carregar logs: $e');
      Get.snackbar(
        'Erro',
        'Erro ao carregar logs',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
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
                case 'integridade':
                  _verificarIntegridade();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'exportar',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Exportar Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'limpar',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Limpar Logs Antigos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'integridade',
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Verificar Integridade'),
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
      body: isLoading
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
    );
  }
  
  // ========== TAB DE LOGS ==========
  Widget _buildLogsTab() {
    return Column(
      children: [
        // Filtros
        _buildFiltros(),
        
        // Lista de logs
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
        
        // Paginação
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
              // Filtro por nível
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
              
              // Filtro por ação
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
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...AuditAction.values.map((action) => DropdownMenuItem(
                      value: action.code,
                      child: Text(
                        StringCapitalize(action.code.replaceAll('_', ' ').toLowerCase()).capitalize,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
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
              // Data início
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
              
              // Data fim
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
              
              // Botão limpar filtros
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
  
  Widget _buildLogCard(LogSistema log) {
    Color corNivel = _getCorNivel(log.nivel ?? 'info');
    IconData iconeAcao = _getIconeAcao(log.acao);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2A2A2A),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: corNivel.withOpacity(0.2),
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
                _formatarAcao(log.acao),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              _formatarDataHora(log.dataAcao),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Text(
          log.detalhes ?? 'Sem detalhes',
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
                _buildDetalheRow('ID', log.id.toString()),
                if (log.usuarioId != null)
                  _buildDetalheRow('Usuário ID', log.usuarioId.toString()),
                _buildDetalheRow('Ação', log.acao),
                _buildDetalheRow('Nível', log.nivel ?? 'info'),
                if (log.tabelaAfetada != null)
                  _buildDetalheRow('Tabela', log.tabelaAfetada!),
                if (log.registroId != null)
                  _buildDetalheRow('Registro ID', log.registroId.toString()),
                if (log.ipAddress != null)
                  _buildDetalheRow('IP', log.ipAddress!),
                if (log.userAgent != null)
                  _buildDetalheRow('User Agent', log.userAgent!),
                _buildDetalheRow('Data/Hora', _formatarDataHoraCompleta(log.dataAcao)),
                
                if (log.dadosAnteriores != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Dados Anteriores:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.dadosAnteriores!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                
                if (log.dadosNovos != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Dados Novos:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.dadosNovos!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
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
                    estatisticas['rapidas']['logs_24h'].toString(),
                    Icons.history,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Ações Críticas',
                    estatisticas['rapidas']['acoes_criticas'].toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
              ],
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
              estatisticas['resumo']['total_logs'].toString(),
              Icons.list_alt,
            ),
            
            const SizedBox(height: 20),
            
            // Logs por nível
            const Text(
              'Logs por Nível',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ...((estatisticas['resumo']['por_nivel'] as List?) ?? [])
                .map((item) => _buildNivelBar(
                      item['nivel'] ?? 'unknown',
                      item['total'] ?? 0,
                      estatisticas['resumo']['total_logs'] ?? 1,
                    )),
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
        border: Border.all(color: color.withOpacity(0.3)),
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
  
  Widget _buildNivelBar(String nivel, int total, int totalGeral) {
    double percentual = (total / totalGeral) * 100;
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
                '$total (${percentual.toStringAsFixed(1)}%)',
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
                  user['nome'] ?? 'Usuário ${user['usuario_id']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['email'] ?? '',
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
    List<LogSistema> alertas = logs
        .where((log) => log.nivel == 'warning' || log.nivel == 'error')
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
        LogSistema alerta = alertas[index];
        bool isError = alerta.nivel == 'error';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isError 
              ? Colors.red.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          child: ListTile(
            leading: Icon(
              isError ? Icons.error : Icons.warning,
              color: isError ? Colors.red : Colors.orange,
              size: 32,
            ),
            title: Text(
              _formatarAcao(alerta.acao),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta.detalhes ?? 'Sem detalhes',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatarDataHora(alerta.dataAcao),
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
    switch (nivel) {
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
    if (acao.contains('LOGIN')) return Icons.login;
    if (acao.contains('LOGOUT')) return Icons.logout;
    if (acao.contains('USER')) return Icons.person;
    if (acao.contains('PASSWORD')) return Icons.lock;
    if (acao.contains('CHECKMARK')) return Icons.check_box;
    if (acao.contains('CATEGORY')) return Icons.folder;
    if (acao.contains('EVALUATION')) return Icons.assessment;
    if (acao.contains('DIAGNOSTIC')) return Icons.medical_services;
    if (acao.contains('DATA')) return Icons.storage;
    if (acao.contains('CONFIG')) return Icons.settings;
    if (acao.contains('UNAUTHORIZED')) return Icons.block;
    if (acao.contains('SUSPICIOUS')) return Icons.warning;
    return Icons.info;
  }
  
  String _formatarAcao(String acao) {
    return acao.replaceAll('_', ' ').toLowerCase().split(' ')
        .map((word) => StringCapitalize(word).capitalize)
        .join(' ');
  }
  
  String _formatarDataHora(DateTime? data) {
    if (data == null) return 'N/A';
    return DateFormat('dd/MM HH:mm').format(data);
  }
  
  String _formatarDataHoraCompleta(DateTime? data) {
    if (data == null) return 'N/A';
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(data);
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
    
    if (picked != null) {
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
  
  void _mostrarDetalhesAlerta(LogSistema alerta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Row(
          children: [
            Icon(
              alerta.nivel == 'error' ? Icons.error : Icons.warning,
              color: alerta.nivel == 'error' ? Colors.red : Colors.orange,
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
              _buildDetalheRow('Ação', alerta.acao),
              _buildDetalheRow('Nível', alerta.nivel ?? 'N/A'),
              _buildDetalheRow('Data/Hora', _formatarDataHoraCompleta(alerta.dataAcao)),
              if (alerta.usuarioId != null)
                _buildDetalheRow('Usuário ID', alerta.usuarioId.toString()),
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
                  alerta.detalhes ?? 'Sem detalhes adicionais',
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
      String dados = await AuditService.instance.exportarLogs(
        dataInicio: filtroDataInicio,
        dataFim: filtroDataFim,
        formato: 'csv',
      );
      
      // Aqui você implementaria salvar o arquivo ou compartilhar
      // Por enquanto, apenas mostrar mensagem
      
      Get.snackbar(
        'Exportação',
        'Logs preparados para exportação (${dados.length} bytes)',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Erro ao exportar logs',
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
        content: const Text(
          'Isso removerá logs informativos com mais de 90 dias.\n\nLogs de aviso e erro serão mantidos.\n\nDeseja continuar?',
          style: TextStyle(color: Colors.white70),
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
              Navigator.pop(context);
              await AuditService.instance.limparLogsAntigos();
              Get.snackbar(
                'Sucesso',
                'Logs antigos removidos',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
              carregarDados();
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
  
  Future<void> _verificarIntegridade() async {
    setState(() => isLoading = true);
    
    try {
      var resultado = await DatabaseHelper.instance.verificarIntegridade();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Verificação de Integridade',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntegridadeItem(
                'Senhas Fracas',
                resultado['senhas_fracas']?.toString() ?? '0',
                int.parse(resultado['senhas_fracas']?.toString() ?? '0') > 0
                    ? Colors.orange
                    : Colors.green,
              ),
              const SizedBox(height: 12),
              _buildIntegridadeItem(
                'Usuários Bloqueados',
                (resultado['usuarios_bloqueados'] as List?)?.length.toString() ?? '0',
                (resultado['usuarios_bloqueados'] as List?)?.isNotEmpty == true
                    ? Colors.red
                    : Colors.green,
              ),
              const SizedBox(height: 12),
              _buildIntegridadeItem(
                'Logs Suspeitos (7 dias)',
                resultado['logs_suspeitos']?.toString() ?? '0',
                int.parse(resultado['logs_suspeitos']?.toString() ?? '0') > 0
                    ? Colors.orange
                    : Colors.green,
              ),
            ],
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
    } catch (e) {
      Get.snackbar(
        'Erro',
        'Erro ao verificar integridade',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  Widget _buildIntegridadeItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// Extension para capitalizar strings
extension StringCapitalize on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}