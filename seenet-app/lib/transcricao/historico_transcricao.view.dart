// lib/transcricao/historico_transcricao.view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/transcricao_controller.dart';
import '../models/transcricao_tecnica.dart';
import '../widgets/skeleton_loader.dart';

class HistoricoTranscricaoView extends StatefulWidget {
  const HistoricoTranscricaoView({super.key});

  @override
  State<HistoricoTranscricaoView> createState() => _HistoricoTranscricaoViewState();
}

class _HistoricoTranscricaoViewState extends State<HistoricoTranscricaoView> {
  late TranscricaoController controller;
  late TextEditingController _searchController;
  List<TranscricaoTecnica> _transcricoesFiltradas = [];

  @override
  void initState() {
    super.initState();
    controller = Get.find<TranscricaoController>();
    _searchController = TextEditingController();
    _transcricoesFiltradas = controller.historico;
    
    // Carregar dados se necessário
    controller.carregarHistorico();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarTranscricoes(String termo) {
    setState(() {
      _transcricoesFiltradas = controller.buscarNoHistorico(termo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Documentações'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.carregarHistorico(),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          // Header com estatísticas
          _buildHeaderEstatisticas(),
          
          // Campo de busca
          _buildCampoBusca(),
          
          // Lista de transcrições
          Expanded(
            child: Obx(() => _buildLista()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.back(),
        backgroundColor: const Color(0xFF00FF88),
        tooltip: 'Nova Documentação',
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildHeaderEstatisticas() {
    Map<String, dynamic> stats = controller.estatisticasHistorico;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Estatísticas',
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
                child: _buildStatCard(
                  'Total',
                  stats['total'].toString(),
                  Icons.description,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Este Mês',
                  stats['esteMes'].toString(),
                  Icons.calendar_today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Tempo Total',
                  stats['tempoTotal'],
                  Icons.timer,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoBusca() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: _filtrarTranscricoes,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar documentações...',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    _filtrarTranscricoes('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00FF88)),
          ),
        ),
      ),
    );
  }

  Widget _buildLista() {
    // ✅ SKELETON DURANTE LOADING
    if (controller.isLoading.value) {
      return const HistoricoTranscricaoSkeleton(itemCount: 5);
    }
    
    if (controller.historico.isEmpty) {
      return _buildEstadoVazio();
    }

    if (_transcricoesFiltradas.isEmpty) {
      return _buildNenhumResultado();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transcricoesFiltradas.length,
      itemBuilder: (context, index) {
        return _buildItemTranscricao(_transcricoesFiltradas[index]);
      },
    );
  }

  Widget _buildEstadoVazio() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.white24,
          ),
          SizedBox(height: 16),
          Text(
            'Nenhuma documentação encontrada',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Suas documentações aparecerão aqui',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNenhumResultado() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.white24,
          ),
          SizedBox(height: 16),
          Text(
            'Nenhum resultado encontrado',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tente outros termos de busca',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTranscricao(TranscricaoTecnica transcricao) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2A2A2A),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(transcricao.status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(transcricao.status),
            color: _getStatusColor(transcricao.status),
            size: 20,
          ),
        ),
        title: Text(
          transcricao.titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatarDataHora(transcricao.dataCriacao),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (transcricao.duracaoFormatada != 'N/A')
              Text(
                '⏱️ ${transcricao.duracaoFormatada}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: const Color(0xFF3A3A3A),
          onSelected: (value) => _handleMenuAction(value, transcricao),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copiar_original',
              child: Row(
                children: [
                  Icon(Icons.content_copy, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Copiar Original', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copiar_processado',
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Copiar Processado', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'compartilhar',
              child: Row(
                children: [
                  Icon(Icons.share, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Compartilhar', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remover',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remover', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Texto original
                _buildSecaoTexto(
                  'Transcrição Original',
                  transcricao.transcricaoOriginal,
                  Icons.record_voice_over,
                  Colors.blue,
                ),
                
                const SizedBox(height: 16),
                
                // Texto processado
                _buildSecaoTexto(
                  'Ações Organizadas',
                  transcricao.pontosDaAcao,
                  Icons.auto_fix_high,
                  const Color(0xFF00FF88),
                ),
                
                const SizedBox(height: 16),
                
                // Informações adicionais
                _buildInformacoesExtras(transcricao),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoTexto(String titulo, String texto, IconData icon, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: cor, size: 16),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cor.withOpacity(0.3)),
          ),
          child: SelectableText(
            texto,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInformacoesExtras(TranscricaoTecnica transcricao) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações Adicionais',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Status', transcricao.status.toUpperCase()),
          if (transcricao.categoriaProblema != null)
            _buildInfoRow('Categoria', transcricao.categoriaProblema!),
          if (transcricao.clienteInfo != null)
            _buildInfoRow('Cliente', transcricao.clienteInfo!),
          _buildInfoRow('Duração', transcricao.duracaoFormatada),
          if (transcricao.dataInicio != null)
            _buildInfoRow('Início', _formatarDataHora(transcricao.dataInicio)),
          if (transcricao.dataConclusao != null)
            _buildInfoRow('Conclusão', _formatarDataHora(transcricao.dataConclusao)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, TranscricaoTecnica transcricao) {
    switch (action) {
      case 'copiar_original':
        _copiarTexto(transcricao.transcricaoOriginal, 'Texto original copiado');
        break;
      case 'copiar_processado':
        _copiarTexto(transcricao.pontosDaAcao, 'Texto processado copiado');
        break;
      case 'compartilhar':
        _compartilharTranscricao(transcricao);
        break;
      case 'remover':
        _confirmarRemocao(transcricao);
        break;
    }
  }

  void _copiarTexto(String texto, String mensagem) {
    Clipboard.setData(ClipboardData(text: texto));
    Get.snackbar(
      'Copiado',
      mensagem,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  void _compartilharTranscricao(TranscricaoTecnica transcricao) {
    // Implementar compartilhamento
    Get.snackbar(
      'Compartilhamento',
      'Funcionalidade em desenvolvimento',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }

  void _confirmarRemocao(TranscricaoTecnica transcricao) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Remover Documentação',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Deseja remover "${transcricao.titulo}"?\n\nEsta ação não pode ser desfeita.',
          style: const TextStyle(color: Colors.white70),
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
            onPressed: () {
              Navigator.pop(context);
              if (transcricao.id != null) {
                controller.removerTranscricao(transcricao.id!);
                setState(() {
                  _transcricoesFiltradas.remove(transcricao);
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'concluida':
        return Colors.green;
      case 'processando':
        return Colors.orange;
      case 'erro':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'concluida':
        return Icons.check_circle;
      case 'processando':
        return Icons.autorenew;
      case 'erro':
        return Icons.error;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _formatarDataHora(DateTime? data) {
    if (data == null) return 'N/A';
    
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }
}