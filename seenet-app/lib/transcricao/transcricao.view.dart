// lib/transcricao/transcricao.view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../controllers/transcricao_controller.dart';
import 'historico_transcricao.view.dart';

class TranscricaoView extends StatefulWidget {
  const TranscricaoView({super.key});

  @override
  State<TranscricaoView> createState() => _TranscricaoViewState();
}

class _TranscricaoViewState extends State<TranscricaoView>
    with TickerProviderStateMixin {
  
  late TranscricaoController controller;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.put(TranscricaoController());
    
    // Configurar animações
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds = timer.tick;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Métodos de controle da gravação
  Future<void> _toggleRecording() async {
    if (controller.isGravando.value) {
      await _finalizarGravacao();
    } else {
      await _iniciarGravacao();
    }
  }

  Future<void> _iniciarGravacao() async {
    bool sucesso = await controller.iniciarGravacao();
    if (sucesso) {
      _startTimer();
      
      // Iniciar animação de pulse
      _pulseController.repeat(reverse: true);
    } else {
      Get.snackbar(
        'Erro',
        'Não foi possível iniciar a gravação. Verifique as permissões.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _finalizarGravacao() async {
    await controller.pararGravacao();
    _stopTimer();
    _pulseController.stop();
    _pulseController.reset();
    
    Get.snackbar(
      'Sucesso',
      'Gravação finalizada com sucesso!',
      backgroundColor: const Color(0xFF00FF88),
      colorText: Colors.black,
    );
  }

  Future<void> _cancelarGravacao() async {
    await controller.cancelarGravacao();
    _stopTimer();
    _pulseController.stop();
    _pulseController.reset();
    
    Get.snackbar(
      'Cancelado',
      'Gravação cancelada',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
    );
  }

  Future<void> _salvarDocumentacao() async {
    if (controller.textoProcessado.isEmpty) {
      Get.snackbar(
        'Erro',
        'Não há documentação para salvar',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Dialog para inserir título
    String? titulo = await _mostrarDialogTitulo();
    
    if (titulo != null && titulo.isNotEmpty) {
      bool sucesso = await controller.salvarTranscricao(titulo);
      
      if (sucesso) {
        // Limpar dados após salvar
        controller.limpar();
        _seconds = 0;
        
        Get.snackbar(
          'Sucesso',
          'Documentação salva com sucesso!',
          backgroundColor: const Color(0xFF00FF88),
          colorText: Colors.black,
        );
      } else {
        Get.snackbar(
          'Erro',
          'Erro ao salvar documentação',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<String?> _mostrarDialogTitulo() async {
    TextEditingController tituloController = TextEditingController();
    
    // Sugerir título baseado na data/hora
    DateTime agora = DateTime.now();
    String tituloSugerido = 'Documentação ${agora.day}/${agora.month}/${agora.year} ${agora.hour}:${agora.minute.toString().padLeft(2, '0')}';
    tituloController.text = tituloSugerido;
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Salvar Documentação',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite um título para a documentação:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tituloController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Título da documentação',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00FF88)),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, tituloController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _mostrarHistorico() {
    Get.to(() => const HistoricoTranscricaoView());
  }

  void _copiarTexto(String texto) {
    if (texto.isEmpty) {
      Get.snackbar(
        'Aviso',
        'Não há texto para copiar',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    
    Clipboard.setData(ClipboardData(text: texto));
    Get.snackbar(
      'Copiado',
      'Texto copiado para a área de transferência',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentar Ações'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _mostrarHistorico(),
            tooltip: 'Ver histórico',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Obx(() => _buildBody()),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Header com informações
        _buildHeader(),
        
        // Área principal
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Status da gravação
                _buildRecordingStatus(),
                
                const SizedBox(height: 30),
                
                // Microfone e controles
                _buildMicrophoneArea(),
                
                const SizedBox(height: 30),
                
                // Texto transcrito
                _buildTranscriptionArea(),
                
                const SizedBox(height: 30),
                
                // Resultado processado
                if (controller.textoProcessado.isNotEmpty)
                  _buildProcessedArea(),
                
                const SizedBox(height: 100), // Espaço para FAB
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
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
            'Documentação por Voz',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grave as ações realizadas e a IA organizará em pontos profissionais',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          if (controller.isGravando.value)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GRAVANDO ${_formatDuration(_seconds)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingStatus() {
    if (!controller.isGravando.value && controller.textoTranscrito.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Toque no microfone e descreva as ações técnicas realizadas',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    
    if (controller.isProcessando.value) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Processando com IA...',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildMicrophoneArea() {
    return Column(
      children: [
        // Microfone principal
        GestureDetector(
          onTap: () => _toggleRecording(),
          child: AnimatedBuilder(
            animation: controller.isGravando.value ? _pulseAnimation : 
                      const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              if (controller.isGravando.value && !_pulseController.isAnimating) {
                _pulseController.repeat(reverse: true);
              } else if (!controller.isGravando.value) {
                _pulseController.stop();
                _pulseController.reset();
              }
              
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: controller.isGravando.value 
                        ? Colors.red 
                        : const Color(0xFF00FF88),
                    boxShadow: [
                      BoxShadow(
                        color: (controller.isGravando.value 
                                ? Colors.red 
                                : const Color(0xFF00FF88))
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    controller.isGravando.value 
                        ? Icons.stop 
                        : Icons.mic,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Botões de controle
        if (controller.isGravando.value)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botão cancelar
              ElevatedButton.icon(
                onPressed: () => _cancelarGravacao(),
                icon: const Icon(Icons.cancel, color: Colors.white),
                label: const Text('Cancelar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Botão finalizar
              ElevatedButton.icon(
                onPressed: () => _finalizarGravacao(),
                icon: const Icon(Icons.check, color: Colors.black),
                label: const Text('Finalizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        
        const SizedBox(height: 10),
        
        // Texto de instrução
        Text(
          controller.isGravando.value 
              ? 'Descreva as ações técnicas realizadas...'
              : 'Toque para iniciar gravação',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTranscriptionArea() {
    if (controller.textoTranscrito.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Texto Transcrito',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                onPressed: () => _copiarTexto(controller.textoTranscrito.value),
                tooltip: 'Copiar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            controller.textoTranscrito.value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessedArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_fix_high,
                  color: Color(0xFF00FF88),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ações Organizadas pela IA',
                style: TextStyle(
                  color: Color(0xFF00FF88),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                onPressed: () => _copiarTexto(controller.textoProcessado.value),
                tooltip: 'Copiar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            controller.textoProcessado.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _salvarDocumentacao(),
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar Documentação'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}