// lib/diagnostico/diagnostico_view.dart - VERSÃO OTIMIZADA (ROUND 7)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../controllers/diagnostico_controller.dart';
import '../controllers/checkmark_controller.dart';
import '../models/diagnostico.dart';
import '../widgets/skeleton_loader.dart';

/// Diagnóstico View OTIMIZADO - Memory Leak Prevention
/// Round 7: Consolidação de AnimationControllers (4 → 1)
class DiagnosticoView extends StatefulWidget {
  const DiagnosticoView({super.key});

  @override
  State<DiagnosticoView> createState() => _DiagnosticoViewState();
}

class _DiagnosticoViewState extends State<DiagnosticoView>
    with SingleTickerProviderStateMixin { // ✅ Single em vez de Ticker
  
  // Controllers
  late DiagnosticoController _diagnosticoController;
  late CheckmarkController _checkmarkController;
  late TextEditingController _perguntaController;

  // ✅ UM ÚNICO AnimationController MASTER
  late AnimationController _masterController;
  
  // ✅ Múltiplas animações derivadas do mesmo controller
  late Animation<double> _shimmerAnimation;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<Offset> _slideAnimation;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    _initializeDiagnostico();
  }

  void _initializeControllers() {
    _perguntaController = TextEditingController();

    if (Get.isRegistered<DiagnosticoController>()) {
      _diagnosticoController = Get.find<DiagnosticoController>();
    } else {
      _diagnosticoController = Get.put(DiagnosticoController());
    }

    if (Get.isRegistered<CheckmarkController>()) {
      _checkmarkController = Get.find<CheckmarkController>();
    } else {
      _checkmarkController = Get.put(CheckmarkController());
    }
  }

  /// ✅ ANIMAÇÕES CONSOLIDADAS - 1 Controller, Múltiplas Animações
  void _setupAnimations() {
    // MASTER CONTROLLER - 2 segundos de duração
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Shimmer (0-50% do tempo total)
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOutSine),
    ));

    // FAB Scale (0-15% do tempo total - rápido)
    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 0.15, curve: Curves.easeInOut),
    ));

    // Logo Rotate (0-100% do tempo total)
    _logoRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
    ));

    // Slide (0-80% do tempo total)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));

    // Iniciar animação
    _masterController.forward();
  }

  void _initializeDiagnostico() {
    _gerarDiagnostico();
  }

  Future<void> _gerarDiagnostico() async {
    // Animar shimmer durante loading
    if (!_masterController.isAnimating) {
      _masterController.repeat();
    }

    _diagnosticoController.diagnosticos.clear();

    try {
      await HapticFeedback.lightImpact();

      if (_checkmarkController.avaliacaoAtual.value == null) {
        await _criarDiagnosticoDemo();
        return;
      }

      List<int> checkmarksMarcadosIds = _checkmarkController.checkmarksMarcados;

      if (checkmarksMarcadosIds.isEmpty) {
        _showSnackbar(
          'Aviso',
          'Nenhum problema foi selecionado',
          SnackbarType.warning,
        );
        await _criarDiagnosticoDemo();
        return;
      }

      bool sucesso = await _diagnosticoController.gerarDiagnostico(
        _checkmarkController.avaliacaoAtual.value!.id!,
        _checkmarkController.categoriaAtual.value,
        checkmarksMarcadosIds,
      );

      if (!sucesso) {
        _showSnackbar(
          'Erro',
          'Erro ao gerar diagnóstico. Criando diagnóstico de exemplo.',
          SnackbarType.error,
        );
        await _criarDiagnosticoDemo();
      } else {
        await HapticFeedback.heavyImpact();
      }
    } finally {
      // Parar animação de loading
      _masterController.stop();
      _masterController.reset();
      _masterController.forward(); // Voltar ao estado inicial
    }
  }

  Future<void> _criarDiagnosticoDemo() async {
    await Future.delayed(const Duration(seconds: 2));

    const String diagnosticoExemplo = """🔍 **DIAGNÓSTICO TÉCNICO DEMONSTRAÇÃO**

📊 **ANÁLISE REALIZADA:**
Sistema em modo de demonstração. Este é um exemplo de como o diagnóstico apareceria com problemas reais selecionados.

🎯 **CAUSA PROVÁVEL:**
• Sobrecarga na rede local
• Interferência no sinal WiFi
• Possível degradação do sinal da operadora

🛠️ **SOLUÇÕES RECOMENDADAS:**

**1. REINICIALIZAÇÃO BÁSICA (5 min)**
   ✓ Desligue o roteador por 30 segundos
   ✓ Aguarde inicialização completa (2-3 minutos)
   ✓ Teste novamente a conexão

**2. VERIFICAÇÃO FÍSICA (10 min)**
   ✓ Confira todos os cabos de rede
   ✓ Procure por conectores soltos
   ✓ Teste conexão cabeada diretamente

**3. OTIMIZAÇÃO WiFi (15 min)**
   ✓ Mude o canal WiFi (1, 6 ou 11)
   ✓ Aproxime dispositivos do roteador
   ✓ Remova interferências (micro-ondas, etc.)

**4. TESTE DE VELOCIDADE**
   ✓ Realize teste em horário alternativo
   ✓ Compare com velocidade contratada

⚠️ **SE PERSISTIR:**
Entre em contato com a operadora informando os testes realizados.

✅ **PREVENÇÃO:**
• Atualize firmware mensalmente
• Monitore dispositivos conectados
• Evite sobrecarga simultânea

---
📋 Diagnóstico de demonstração - Configure sua chave do Gemini para diagnósticos reais""";

    _diagnosticoController.diagnosticos.add(
      Diagnostico(
        id: DateTime.now().millisecondsSinceEpoch,
        avaliacaoId: 1,
        categoriaId: 1,
        promptEnviado: "Diagnóstico de demonstração",
        respostaGemini: diagnosticoExemplo,
        resumoDiagnostico: "Diagnóstico de demonstração - Configure Gemini para funcionalidade completa",
        statusApi: 'sucesso',
        dataCriacao: DateTime.now(),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await HapticFeedback.mediumImpact();
    await _gerarDiagnostico();
  }

  void _showSnackbar(String title, String message, SnackbarType type) {
    if (Get.context != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: type.color,
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
        icon: Icon(type.icon, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAdvancedAppBar(),
      backgroundColor: const Color(0xFF0A0A0A),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomInputBar(),
    );
  }

  PreferredSizeWidget _buildAdvancedAppBar() {
    return AppBar(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6B7280).withOpacity(0.95),
              const Color(0xFF4B5563).withOpacity(0.85),
            ],
          ),
        ),
      ),
      leading: _buildBackButton(),
      title: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.white, Color(0xFF00FF88)],
        ).createShader(bounds),
        child: const Text(
          'Diagnóstico IA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) {
        _masterController.reset();
        _masterController.animateTo(0.15); // Animar FAB scale
      },
      onTapUp: (_) {
        _masterController.forward();
      },
      onTapCancel: () {
        _masterController.forward();
      },
      onTap: () async {
        await HapticFeedback.selectionClick();
        Get.offAllNamed('/checklist');
      },
      child: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF2D2D2D),
            Color(0xFF1F1F1F),
            Color(0xFF0A0A0A),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _handleRefresh,
        backgroundColor: const Color(0xFF1A1A1A),
        color: const Color(0xFF00FF88),
        strokeWidth: 3,
        displacement: 60,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(top: 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAnimatedLogo(),
                  const SizedBox(height: 20),
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  _buildDiagnosticContent(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoRotateAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _logoRotateAnimation.value * 0.1,
          child: GestureDetector(
            onTap: () async {
              await HapticFeedback.lightImpact();
              _masterController.reset();
              _masterController.forward();
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00FF88).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00FF88).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Obx(() {
          if (_diagnosticoController.statusMensagem.value.isNotEmpty) {
            return Row(
              children: [
                if (_diagnosticoController.isLoading.value)
                  _buildShimmerIndicator(),
                if (_diagnosticoController.isLoading.value)
                  const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _diagnosticoController.statusMensagem.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          }

          return const Text(
            '🤖 Diagnóstico Inteligente Pronto',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShimmerIndicator() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _shimmerAnimation.value, 0.0),
              end: Alignment(1.0 - _shimmerAnimation.value, 0.0),
              colors: [
                Colors.transparent,
                const Color(0xFF00FF88).withOpacity(0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticContent() {
    return Obx(() {
      if (_diagnosticoController.isLoading.value) {
        return _buildLoadingShimmer();
      }

      if (_diagnosticoController.diagnosticos.isNotEmpty) {
        return _buildDiagnosticsList();
      }

      return _buildEmptyState();
    });
  }

  Widget _buildLoadingShimmer() {
    // ✅ SKELETON SCREEN MELHORADO
    return const DiagnosticoSkeleton();
  }

  Widget _buildDiagnosticsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _diagnosticoController.diagnosticos.map((diagnostico) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: _buildDiagnosticCard(diagnostico),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDiagnosticCard(Diagnostico diagnostico) {
    bool isDemo = diagnostico.promptEnviado.contains('demonstração');
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: diagnostico.isSucesso
              ? const Color(0xFF00FF88).withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: diagnostico.isSucesso
                ? const Color(0xFF00FF88).withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(diagnostico, isDemo),
          const SizedBox(height: 20),
          _buildCardContent(diagnostico),
        ],
      ),
    );
  }

  Widget _buildCardHeader(Diagnostico diagnostico, bool isDemo) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: diagnostico.isSucesso
                ? const Color(0xFF00FF88).withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            diagnostico.isSucesso ? Icons.check_circle : Icons.error,
            color: diagnostico.isSucesso ? const Color(0xFF00FF88) : Colors.red,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            diagnostico.isSucesso ? 'Diagnóstico Concluído' : 'Erro no Diagnóstico',
            style: TextStyle(
              color: diagnostico.isSucesso ? const Color(0xFF00FF88) : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        _buildTypeChip(isDemo),
      ],
    );
  }

  Widget _buildTypeChip(bool isDemo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDemo ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDemo ? Colors.orange : Colors.blue,
          width: 1,
        ),
      ),
      child: Text(
        isDemo ? 'DEMO' : 'GEMINI',
        style: TextStyle(
          color: isDemo ? Colors.orange : Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCardContent(Diagnostico diagnostico) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        diagnostico.respostaGemini,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.6,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.psychology_outlined,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum diagnóstico disponível',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Volte para o checklist e selecione problemas para gerar um diagnóstico',
            style: TextStyle(color: Colors.white60, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildCTAButton(),
        ],
      ),
    );
  }

  Widget _buildCTAButton() {
    return GestureDetector(
      onTap: () async {
        await HapticFeedback.mediumImpact();
        Get.offAllNamed('/checklist');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'Voltar ao Checklist',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInputBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(child: _buildInputField()),
            const SizedBox(width: 8),
            _buildMicButton(),
            const SizedBox(width: 8),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      margin: const EdgeInsets.only(left: 20),
      child: TextField(
        controller: _perguntaController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Pergunte sobre o diagnóstico...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () async {
        await HapticFeedback.mediumImpact();
        _showSnackbar(
          'Funcionalidade',
          'Reconhecimento de voz será implementado em breve',
          SnackbarType.info,
        );
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: const Icon(Icons.mic, color: Colors.white70, size: 24),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: () async {
        if (_perguntaController.text.isNotEmpty) {
          await HapticFeedback.mediumImpact();
          String pergunta = _perguntaController.text;
          _perguntaController.clear();

          _showSnackbar(
            'Mensagem Enviada',
            'Pergunta: "$pergunta" - Chat será implementado em breve',
            SnackbarType.success,
          );
        }
      },
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _perguntaController.text.isNotEmpty
                ? [const Color(0xFF00FF88), const Color(0xFF00CC6A)]
                : [const Color(0xFF2A2A2A), const Color(0xFF2A2A2A)],
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send,
          color: _perguntaController.text.isNotEmpty
              ? Colors.black
              : Colors.white54,
          size: 24,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _perguntaController.dispose();
    _masterController.dispose(); // ✅ Apenas 1 dispose
    super.dispose();
  }
}

enum SnackbarType {
  success(Color(0xFF4CAF50), Icons.check_circle),
  error(Color(0xFFF44336), Icons.error),
  warning(Color(0xFFFF9800), Icons.warning),
  info(Color(0xFF2196F3), Icons.info);

  const SnackbarType(this.color, this.icon);
  final Color color;
  final IconData icon;
}