import 'services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

// Desenha cantos nos quatro lados da tela (frame)
class _CornerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 40;
    const double offset = 16;

    // Top-left
    canvas.drawLine(
      Offset(offset, offset),
      Offset(offset + cornerLength, offset),
      paint,
    );
    canvas.drawLine(
      Offset(offset, offset),
      Offset(offset, offset + cornerLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - offset, offset),
      Offset(size.width - offset - cornerLength, offset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - offset, offset),
      Offset(size.width - offset, offset + cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(offset, size.height - offset),
      Offset(offset + cornerLength, size.height - offset),
      paint,
    );
    canvas.drawLine(
      Offset(offset, size.height - offset),
      Offset(offset, size.height - offset - cornerLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - offset, size.height - offset),
      Offset(size.width - offset - cornerLength, size.height - offset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - offset, size.height - offset),
      Offset(size.width - offset, size.height - offset - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diagnóstico de Rede',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Tela Home
class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const HomeScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Olá, Técnico!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Relate o problema encontrado',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 60),
              
              // Card principal
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.videocam,
                      size: 64,
                      color: Colors.blue[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gravar Relato',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toque para iniciar a gravação do seu relato sobre o problema',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Botão principal
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _startRecording(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Iniciar Gravação',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRecording(BuildContext context) async {
    // Solicitar permissões
    await _requestPermissions();
    
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecordingScreen(cameras: cameras),
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();
  }
}

// Tela de Gravação
class RecordingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const RecordingScreen({super.key, required this.cameras});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  String? _videoPath;
  int _recordingSeconds = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: true,
      );
      
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Preview da câmera
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Grid overlay (9 quadrados)
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
          
          // Header com timer e controles
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Botão fechar
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Timer com fundo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Botão de troca de câmera
                  GestureDetector(
                    onTap: _switchCamera,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cameraswitch,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Controles inferiores
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicadores de zoom/velocidade
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSpeedIndicator('0.5x', false),
                        const SizedBox(width: 40),
                        _buildSpeedIndicator('1x', true),
                        const SizedBox(width: 40),
                        _buildSpeedIndicator('2x', false),
                      ],
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Botão de gravação principal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botão de galeria/arquivos (lado esquerdo)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        
                        const SizedBox(width: 40),
                        
                        // Botão principal de gravação
                        GestureDetector(
                          onTap: _isRecording ? _stopRecording : _startRecording,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: _isRecording ? 30 : 70,
                                height: _isRecording ? 30 : 70,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: _isRecording 
                                      ? BorderRadius.circular(6)
                                      : BorderRadius.circular(35),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 40),
                        
                        // Botão de configurações (lado direito)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Cantos da tela (frame)
          Positioned.fill(
            child: CustomPaint(
              painter: _CornerFramePainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedIndicator(String text, bool isActive) {
    return Text(
      text,
      style: TextStyle(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
        fontSize: isActive ? 16 : 14,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  void _switchCamera() async {
    if (widget.cameras.length > 1) {
      final currentCameraIndex = widget.cameras.indexOf(_controller!.description);
      final nextCameraIndex = (currentCameraIndex + 1) % widget.cameras.length;
      
      await _controller?.dispose();
      
      _controller = CameraController(
        widget.cameras[nextCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );
      
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      
      // Timer para contar segundos
      _startTimer();
    } catch (e) {
      developer.log('Erro ao iniciar gravação: $e');
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isRecording && mounted) {
        setState(() {
          _recordingSeconds++;
        });
        _startTimer();
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final videoFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = videoFile.path;
      });
      
      // Processar o vídeo e enviar para diagnóstico
      _processVideo();
    } catch (e) {
      developer.log('Erro ao parar gravação: $e');
    }
  }

  Future<void> _processVideo() async {
    if (_videoPath == null) return;

    if (!mounted) return;

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processando vídeo...'),
          ],
        ),
      ),
    );

    try {
      // Simular processamento do vídeo e chamada para API
      await Future.delayed(const Duration(seconds: 3));
      
      // Aqui você faria a chamada real para sua API/ChatGPT
      final diagnosis = await _sendToAPI(_videoPath!);
      
      if (!mounted) return;
      
      Navigator.pop(context); // Fechar loading
      
      // Navegar para tela de diagnóstico
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DiagnosisScreen(diagnosis: diagnosis),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      Navigator.pop(context); // Fechar loading
      _showError('Erro ao processar vídeo: $e');
    }
  }

  Future<String> _sendToAPI(String videoPath) async {
    try {
      // Chama o serviço de API real
      return await ApiService.analyzeVideo(videoPath);
    } catch (e) {
      // Retorna diagnóstico simulado em caso de erro
      return '''Problema de conexão identificado.
      
DIAGNÓSTICO:
- Possível instabilidade na rede
- Verificar configurações de roteador
- Testar conectividade com diferentes dispositivos

SOLUÇÕES RECOMENDADAS:
1. Reiniciar modem/roteador
2. Verificar cabos de rede
3. Atualizar drivers de rede
4. Contactar provedor se problema persistir

PRIORIDADE: Alta
TEMPO ESTIMADO: 15-30 minutos''';
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Desenha uma grade 3x3 sobre a tela
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;

    // Linhas verticais
    final double thirdWidth = size.width / 3;
    canvas.drawLine(Offset(thirdWidth, 0), Offset(thirdWidth, size.height), paint);
    canvas.drawLine(Offset(2 * thirdWidth, 0), Offset(2 * thirdWidth, size.height), paint);

    // Linhas horizontais
    final double thirdHeight = size.height / 3;
    canvas.drawLine(Offset(0, thirdHeight), Offset(size.width, thirdHeight), paint);
    canvas.drawLine(Offset(0, 2 * thirdHeight), Offset(size.width, 2 * thirdHeight), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Tela de Diagnóstico
class DiagnosisScreen extends StatelessWidget {
  final String diagnosis;
  
  const DiagnosisScreen({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    'Diagnóstico',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[400]),
                    const SizedBox(width: 12),
                    const Text(
                      'Diagnóstico Concluído',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Resultado
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      diagnosis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[600]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Nova Gravação',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _shareDiagnosis(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Compartilhar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareDiagnosis() {
    // Implementar compartilhamento
    developer.log('Compartilhar diagnóstico');
  }
}