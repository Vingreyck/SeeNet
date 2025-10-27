// lib/diagnostico/diagnostico_view.dart - VERSÃO PROFISSIONAL AVANÇADA
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:ui' show ImageFilter;
import '../controllers/diagnostico_controller.dart';
import '../controllers/checkmark_controller.dart';
import '../models/diagnostico.dart';
import '../models/checkmark.dart';


/// Diagnóstico View com técnicas avançadas de Flutter
/// Implementa: Micro-interactions, Shimmer effects, Pull-to-refresh,
/// Gesture handling, Performance optimizations, Custom animations
class DiagnosticoView extends StatefulWidget {
  const DiagnosticoView({super.key});

  @override
  State<DiagnosticoView> createState() => _DiagnosticoViewState();
}

class _DiagnosticoViewState extends State<DiagnosticoView>
    with TickerProviderStateMixin {
  // Controllers
  late DiagnosticoController _diagnosticoController;
  late CheckmarkController _checkmarkController;
  late TextEditingController _perguntaController;

  // Animation Controllers
  late AnimationController _shimmerController;
  late AnimationController _fabController;
  late AnimationController _logoController;
  late AnimationController _slideController;

  // Animations
  late Animation<double> _shimmerAnimation;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<Offset> _slideAnimation;

  // State variables
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
  GlobalKey<RefreshIndicatorState>();
  bool _isInputFocused = false;
  bool _showFloatingInput = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    _initializeDiagnostico();
  }

  /// Inicializa os controllers usando padrão Singleton e Dependency Injection
  void _initializeControllers() {
    _perguntaController = TextEditingController();

    // Pattern: Dependency Injection com GetX
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

  /// Configura animações avançadas com physics customizadas
  void _setupAnimations() {
    // Shimmer animation para loading states
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutSine,
    ));

    // FAB scale animation para micro-interactions
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    ));

    // Logo rotation para feedback visual
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Slide animation para transições suaves
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Iniciar animações
    _slideController.forward();
  }

  /// Inicializa o diagnóstico com feedback visual
  void _initializeDiagnostico() {
    _logoController.forward().then((_) {
      _gerarDiagnostico();
    });
  }

// Modificar o método _gerarDiagnostico() para limpar diagnósticos anteriores
  Future<void> _gerarDiagnostico() async {
    _shimmerController.repeat();
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
        checkmarksMarcadosIds, // ← Direto da propriedade do controller
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
      _shimmerController.stop();
    }
  }
// Modificar o método _criarDiagnosticoDemo() para remover a limpeza duplicada
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
📋 Diagnóstico de demonstração - Configure sua chave do ChatGPT para diagnósticos reais""";

    // REMOVER: A limpeza da lista (já foi feita em _gerarDiagnostico)
    // _diagnosticoController.diagnosticos.clear(); // <- REMOVER ESTA LINHA

    _diagnosticoController.diagnosticos.add(
        Diagnostico(
          id: DateTime.now().millisecondsSinceEpoch,
          avaliacaoId: 1,
          categoriaId: 1,
          promptEnviado: "Diagnóstico de demonstração",
          respostaChatgpt: diagnosticoExemplo,
          resumoDiagnostico: "Diagnóstico de demonstração - Configure ChatGPT para funcionalidade completa",
          statusApi: 'sucesso',
          dataCriacao: DateTime.now(),
        )
    );
  }
// ADICIONAR: Método para limpar diagnósticos manualmente (se necessário)
  void _limparDiagnosticos() {
    _diagnosticoController.diagnosticos.clear();
    _showSnackbar(
      'Limpeza',
      'Diagnósticos anteriores foram removidos',
      SnackbarType.info,
    );
  }

  /// Pull-to-refresh implementation
  Future<void> _handleRefresh() async {
    await HapticFeedback.mediumImpact();
    await _gerarDiagnostico();
  }

  /// Sistema de Snackbar tipado
  void _showSnackbar(String title, String message, SnackbarType type) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAdvancedAppBar(),
      backgroundColor: const Color(0xFF0A0A0A),
      body: _buildBody(),
      floatingActionButton: _buildAdvancedFAB(),
    );
  }

  /// AppBar avançada com blur effect
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
        // Removido o BackdropFilter (blur)
        // child: BackdropFilter(
        //   filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        //   child: Container(
        //     color: Colors.white.withOpacity(0.05),
        //   ),
        // ),
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

  /// Botão de voltar com animação
  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) => _fabController.forward(),
      onTapUp: (_) => _fabController.reverse(),
      onTapCancel: () => _fabController.reverse(),
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
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
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

  /// Body principal com RefreshIndicator customizado
  Widget _buildBody() {
    return Container(
      decoration: _buildGradientDecoration(),
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
                  const SizedBox(height: 100), // Space for FAB
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Decoração de gradiente avançada
  BoxDecoration _buildGradientDecoration() {
    return const BoxDecoration(
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
    );
  }

  /// Logo animada com micro-interactions
  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoRotateAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _logoRotateAnimation.value * 0.1,
          child: GestureDetector(
            onTap: () async {
              await HapticFeedback.lightImpact();
              _logoController.reset();
              _logoController.forward();
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00FF88).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.3),
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

  /// Card de status com animações
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
            color: const Color(0xFF00FF88).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
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

  /// Shimmer indicator customizado
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
                const Color(0xFF00FF88).withValues(alpha: 0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  /// Conteúdo do diagnóstico com loading states
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

  /// Loading shimmer avançado
  Widget _buildLoadingShimmer() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 - _shimmerAnimation.value, 0.0),
                    end: Alignment(1.0 - _shimmerAnimation.value, 0.0),
                    colors: const [
                      Color(0xFF2A2A2A),
                      Color(0xFF3A3A3A),
                      Color(0xFF2A2A2A),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// Lista de diagnósticos com animações
  Widget _buildDiagnosticsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _diagnosticoController.diagnosticos.asMap().entries.map((entry) {
          int index = entry.key;
          Diagnostico diagnostico = entry.value;

          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.only(bottom: 20),
            child: _buildDiagnosticCard(diagnostico),
          );
        }).toList(),
      ),
    );
  }

  /// Card individual de diagnóstico
  Widget _buildDiagnosticCard(Diagnostico diagnostico) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: diagnostico.isSucesso
              ? const Color(0xFF00FF88).withValues(alpha: 0.5)
              : Colors.red.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: diagnostico.isSucesso
                ? const Color(0xFF00FF88).withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(diagnostico),
          const SizedBox(height: 20),
          _buildCardContent(diagnostico),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Header do card com status
  Widget _buildCardHeader(Diagnostico diagnostico) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: diagnostico.isSucesso
                ? const Color(0xFF00FF88).withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
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
        _buildTypeChip(diagnostico),
      ],
    );
  }

  /// Chip indicador de tipo
  Widget _buildTypeChip(Diagnostico diagnostico) {
    bool isDemo = diagnostico.promptEnviado.contains('demonstração');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDemo ? Colors.orange.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
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

  /// Conteúdo do card
  Widget _buildCardContent(Diagnostico diagnostico) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        diagnostico.respostaChatgpt,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.6,
        ),
      ),
    );
  }

  /// Estado vazio com CTA
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white12,
          width: 1,
        ),
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
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildCTAButton(),
        ],
      ),
    );
  }

  /// Botão CTA animado
  Widget _buildCTAButton() {
    return GestureDetector(
      onTapDown: (_) => _fabController.forward(),
      onTapUp: (_) => _fabController.reverse(),
      onTapCancel: () => _fabController.reverse(),
      onTap: () async {
        await HapticFeedback.mediumImpact();
        Get.offAllNamed('/checklist');
      },
      child: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.4),
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
        },
      ),
    );
  }

  /// FAB avançado com micro-interactions
  Widget _buildAdvancedFAB() {
    return Positioned(
      bottom: 30,
      right: 20,
      left: 20,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: Colors.white12,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildInputField(),
            ),
            _buildMicButton(),
            const SizedBox(width: 8),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  /// Campo de input avançado
  Widget _buildInputField() {
    return Container(
      margin: const EdgeInsets.only(left: 20),
      child: TextField(
        controller: _perguntaController,
        onChanged: (value) {
          setState(() {
            _showFloatingInput = value.isNotEmpty;
          });
        },
        onTap: () async {
          await HapticFeedback.selectionClick();
          setState(() {
            _isInputFocused = true;
          });
        },
        onEditingComplete: () {
          setState(() {
            _isInputFocused = false;
          });
        },
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Pergunte sobre o diagnóstico...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  /// Botão do microfone com animação
  Widget _buildMicButton() {
    return GestureDetector(
      onTapDown: (_) => _fabController.forward(),
      onTapUp: (_) => _fabController.reverse(),
      onTapCancel: () => _fabController.reverse(),
      onTap: () async {
        await HapticFeedback.mediumImpact();
        _showSnackbar(
          'Funcionalidade',
          'Reconhecimento de voz será implementado em breve',
          SnackbarType.info,
        );
      },
      child: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white12,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white70,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Botão de envio com gradiente
  Widget _buildSendButton() {
    return GestureDetector(
      onTapDown: (_) => _fabController.forward(),
      onTapUp: (_) => _fabController.reverse(),
      onTapCancel: () => _fabController.reverse(),
      onTap: () async {
        if (_perguntaController.text.isNotEmpty) {
          await HapticFeedback.mediumImpact();

          // Simular envio de mensagem
          String pergunta = _perguntaController.text;
          _perguntaController.clear();

          _showSnackbar(
            'Mensagem Enviada',
            'Pergunta: "$pergunta" - Chat será implementado em breve',
            SnackbarType.success,
          );

          setState(() {
            _showFloatingInput = false;
          });
        }
      },
      child: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
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
                boxShadow: _perguntaController.text.isNotEmpty
                    ? [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
                    : [],
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
        },
      ),
    );
  }

  /// Formatar data brasileira
  String _formatarData(DateTime? data) {
    if (data == null) return 'Data não disponível';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _perguntaController.dispose();
    _shimmerController.dispose();
    _fabController.dispose();
    _logoController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}

/// Enum para tipos de Snackbar
enum SnackbarType {
  success(Color(0xFF4CAF50), Icons.check_circle),
  error(Color(0xFFF44336), Icons.error),
  warning(Color(0xFFFF9800), Icons.warning),
  info(Color(0xFF2196F3), Icons.info);

  const SnackbarType(this.color, this.icon);
  final Color color;
  final IconData icon;
}

/// Extension para facilitar uso de filtros
extension ImageFilterImport on ImageFilter {
  // Import necessário no topo do arquivo:
  // import 'dart:ui' show ImageFilter;
}

/// Classe para shimmer customizado (opcional - para casos mais avançados)
class CustomShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const CustomShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF2A2A2A),
    this.highlightColor = const Color(0xFF3A3A3A),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<CustomShimmer> createState() => _CustomShimmerState();
}

class _CustomShimmerState extends State<CustomShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));
    _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - _animation.value, 0.0),
              end: Alignment(1.0 - _animation.value, 0.0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Mixin para performance optimization
mixin PerformanceOptimization<T extends StatefulWidget> on State<T> {
  /// Cache para widgets pesados
  final Map<String, Widget> _widgetCache = {};

  /// Método para cachear widgets
  Widget cacheWidget(String key, Widget Function() builder) {
    return _widgetCache.putIfAbsent(key, builder);
  }

  /// Limpar cache quando necessário
  void clearCache() {
    _widgetCache.clear();
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}

/// Pattern: Observer para mudanças de estado
abstract class DiagnosticoObserver {
  void onDiagnosticoUpdated(List<Diagnostico> diagnosticos);
  void onLoadingStateChanged(bool isLoading);
  void onErrorOccurred(String error);
}

/// Pattern: Command para ações
abstract class DiagnosticoCommand {
  Future<void> execute();
  Future<void> undo();
}

class GenerateDiagnosticoCommand implements DiagnosticoCommand {
  final DiagnosticoController _controller;
  final List<Checkmark> _checkmarks;

  GenerateDiagnosticoCommand(this._controller, this._checkmarks);

  @override
  Future<void> execute() async {
    // Implementar geração de diagnóstico
  }

  @override
  Future<void> undo() async {
    // Implementar desfazer
  }
}

/// Pattern: Factory para criação de widgets
class DiagnosticoWidgetFactory {
  static Widget createLoadingIndicator({
    Color? color,
    double? size,
  }) {
    return CircularProgressIndicator(
      color: color ?? const Color(0xFF00FF88),
      strokeWidth: 3,
    );
  }

  static Widget createErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// Adicionar import necessário no topo:
// import 'dart:ui' show ImageFilter; (já adicionado acima)