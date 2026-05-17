// lib/diagnostico/diagnostico_view.dart — REDESIGN (Round 8)
// Todas as funções e animações inalteradas
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../controllers/diagnostico_controller.dart';
import '../controllers/checkmark_controller.dart';
import '../models/diagnostico.dart';
import '../widgets/skeleton_loader.dart';
import 'package:seenet/widgets/app_snackbar.dart';

class DiagnosticoView extends StatefulWidget {
  const DiagnosticoView({super.key});

  @override
  State<DiagnosticoView> createState() => _DiagnosticoViewState();
}

class _DiagnosticoViewState extends State<DiagnosticoView>
    with SingleTickerProviderStateMixin {

  late DiagnosticoController _diagnosticoController;
  late CheckmarkController _checkmarkController;
  late TextEditingController _perguntaController;

  late AnimationController _masterController;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<Offset> _slideAnimation;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
  GlobalKey<RefreshIndicatorState>();

  final RxList<Map<String, String>> _historico = <Map<String, String>>[].obs;
  final RxBool _chatLoading = false.obs;
  int? _diagnosticoId;
  late ScrollController _scrollController;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    _initializeDiagnostico();
  }

  void _initializeControllers() {
    _perguntaController = TextEditingController();
    _scrollController = ScrollController();
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

  void _setupAnimations() {
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _masterController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeInOutSine)));
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _masterController,
            curve: const Interval(0.0, 0.15, curve: Curves.easeInOut)));
    _logoRotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _masterController,
            curve: const Interval(0.0, 1.0, curve: Curves.elasticOut)));
    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(parent: _masterController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));
    _masterController.forward();
  }

  void _initializeDiagnostico() {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['via_foto'] == true) {
      _carregarDiagnosticoDeFoto(args);
    } else {
      _gerarDiagnostico();
    }
  }

  void _carregarDiagnosticoDeFoto(Map<String, dynamic> args) {
    _diagnosticoController.diagnosticos.clear();
    _diagnosticoController.diagnosticos.add(
      Diagnostico(
        id: args['diagnosticoId'],
        avaliacaoId: 1, categoriaId: 1,
        promptEnviado: '[Diagnóstico via foto]',
        respostaGemini: args['resposta'] ?? '',
        resumoDiagnostico: 'Análise de imagem',
        statusApi: 'sucesso',
        dataCriacao: DateTime.now(),
      ),
    );
    _diagnosticoId = args['diagnosticoId'];
    _masterController.forward();
  }

  Future<void> _gerarDiagnostico() async {
    if (!_masterController.isAnimating) _masterController.repeat();
    _diagnosticoController.diagnosticos.clear();
    try {
      await HapticFeedback.lightImpact();
      if (_checkmarkController.avaliacaoAtual.value == null) {
        await _criarDiagnosticoDemo();
        return;
      }
      List<int> checkmarksMarcadosIds = _checkmarkController.checkmarksMarcados;
      if (checkmarksMarcadosIds.isEmpty) {
        _showSnackbar('Aviso', 'Nenhum problema foi selecionado', SnackbarType.warning);
        await _criarDiagnosticoDemo();
        return;
      }
      bool sucesso = await _diagnosticoController.gerarDiagnostico(
        _checkmarkController.avaliacaoAtual.value!.id!,
        _checkmarkController.categoriaAtual.value,
        checkmarksMarcadosIds,
      );
      if (!sucesso) {
        _showSnackbar('Erro', 'Erro ao gerar diagnóstico. Criando diagnóstico de exemplo.', SnackbarType.error);
        await _criarDiagnosticoDemo();
      } else {
        await HapticFeedback.heavyImpact();
        if (_diagnosticoController.diagnosticos.isNotEmpty) {
          _diagnosticoId = _diagnosticoController.diagnosticos.first.id;
        }
      }
    } finally {
      _masterController.stop();
      _masterController.reset();
      _masterController.forward();
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
        avaliacaoId: 1, categoriaId: 1,
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
      AppSnackbar.show(title, message,
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

  Future<void> _enviarMensagem() async {
    final texto = _perguntaController.text.trim();
    if (texto.isEmpty || _chatLoading.value) return;
    await HapticFeedback.lightImpact();
    _perguntaController.clear();
    setState(() {});
    _historico.add({'role': 'user', 'content': texto});
    _rolarParaBaixo();
    if (_diagnosticoId == null) {
      _historico.add({'role': 'assistant', 'content': '⚠️ Nenhum diagnóstico ativo.'});
      return;
    }
    _chatLoading.value = true;
    try {
      final resposta = await _diagnosticoController.enviarMensagemChat(
        diagnosticoId: _diagnosticoId!,
        mensagem: texto,
        historico: _historico.map((m) => {'role': m['role']!, 'content': m['content']!}).toList(),
      );
      _historico.add({'role': 'assistant', 'content': resposta ?? '❌ Erro ao obter resposta.'});
    } catch (e) {
      _historico.add({'role': 'assistant', 'content': '❌ Erro de conexão.'});
    } finally {
      _chatLoading.value = false;
      _rolarParaBaixo();
    }
  }

  void _rolarParaBaixo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _perguntaController.dispose();
    _masterController.dispose();
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: _buildAdvancedAppBar(),
      backgroundColor: const Color(0xFF111111),
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
              const Color(0xFF111111).withOpacity(0.98),
              const Color(0xFF1A1A1A).withOpacity(0.92),
            ],
          ),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF00FF88), width: 0.5),
          ),
        ),
      ),
      leading: _buildBackButton(),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology_rounded,
                color: Color(0xFF00FF88), size: 18),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFF00FF88)],
            ).createShader(bounds),
            child: const Text('Diagnóstico IA',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: -0.3)),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () async {
              await HapticFeedback.mediumImpact();
              _refreshIndicatorKey.currentState?.show();
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white54, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTapDown: (_) {
        _masterController.reset();
        _masterController.animateTo(0.15);
      },
      onTapUp: (_) => _masterController.forward(),
      onTapCancel: () => _masterController.forward(),
      onTap: () async {
        await HapticFeedback.selectionClick();
        Get.offAllNamed('/checklist');
      },
      child: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _fabScaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _handleRefresh,
      backgroundColor: const Color(0xFF1A1A1A),
      color: const Color(0xFF00FF88),
      strokeWidth: 2.5,
      displacement: 60,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(top: 110, bottom: 20),
        children: [
          _buildAnimatedLogo(),
          const SizedBox(height: 16),
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildDiagnosticContent(),
          const SizedBox(height: 16),
          Obx(() {
            if (_diagnosticoController.diagnosticos.isEmpty ||
                _diagnosticoController.isLoading.value) {
              return const SizedBox.shrink();
            }
            return _buildChatSection();
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoRotateAnimation,
      builder: (context, child) => Transform.rotate(
        angle: _logoRotateAnimation.value * 0.08,
        child: GestureDetector(
          onTap: () async {
            await HapticFeedback.lightImpact();
            _masterController.reset();
            _masterController.forward();
          },
          child: Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF00FF88).withOpacity(0.2),
                  Colors.transparent,
                ]),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF88).withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                    'assets/images/logo.svg', width: 64, height: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF00FF88).withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Obx(() {
          if (_diagnosticoController.statusMensagem.value.isNotEmpty) {
            return Row(
              children: [
                if (_diagnosticoController.isLoading.value) ...[
                  _buildShimmerIndicator(),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Text(
                    _diagnosticoController.statusMensagem.value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF00FF88), size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Diagnóstico Inteligente Pronto',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildShimmerIndicator() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) => Container(
        width: 22, height: 22,
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
      ),
    );
  }

  Widget _buildDiagnosticContent() {
    return Obx(() {
      if (_diagnosticoController.isLoading.value) return _buildLoadingShimmer();
      if (_diagnosticoController.diagnosticos.isNotEmpty) return _buildDiagnosticsList();
      return _buildEmptyState();
    });
  }

  Widget _buildLoadingShimmer() => const DiagnosticoSkeleton();

  Widget _buildDiagnosticsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _diagnosticoController.diagnosticos.map((d) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDiagnosticCard(d),
            ),
        ).toList(),
      ),
    );
  }

  Widget _buildDiagnosticCard(Diagnostico diagnostico) {
    final bool isDemo = diagnostico.promptEnviado.contains('demonstração');
    final Color cor = diagnostico.isSucesso
        ? const Color(0xFF00FF88)
        : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cor.withOpacity(0.07),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20)),
            ),
            child: _buildCardHeader(diagnostico, isDemo),
          ),
          // Conteúdo
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCardContent(diagnostico),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(Diagnostico diagnostico, bool isDemo) {
    final Color cor = diagnostico.isSucesso
        ? const Color(0xFF00FF88)
        : Colors.red;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            diagnostico.isSucesso
                ? Icons.check_circle_rounded
                : Icons.error_rounded,
            color: cor, size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            diagnostico.isSucesso
                ? 'Diagnóstico Concluído'
                : 'Erro no Diagnóstico',
            style: TextStyle(
                color: cor,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
        ),
        _buildTypeChip(isDemo),
      ],
    );
  }

  Widget _buildTypeChip(bool isDemo) {
    final isFoto = _diagnosticoController.diagnosticos.isNotEmpty &&
        _diagnosticoController.diagnosticos.first.promptEnviado
            .contains('[Diagnóstico via foto]');
    final label = isDemo ? 'DEMO' : isFoto ? 'FOTO' : 'GROQ';
    final color = isDemo
        ? Colors.orange
        : isFoto
        ? Colors.purple
        : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCardContent(Diagnostico diagnostico) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: SelectableText(
        diagnostico.respostaGemini,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.65),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_outlined,
                size: 56, color: Colors.white24),
          ),
          const SizedBox(height: 20),
          const Text('Nenhum diagnóstico disponível',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const Text(
            'Volte para o checklist e selecione problemas para gerar um diagnóstico',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF00FF88), Color(0xFF00CC6A)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, color: Colors.black, size: 18),
            SizedBox(width: 8),
            Text('Voltar ao Checklist',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Bottom input bar ─────────────────────────────────────────

  Widget _buildBottomInputBar() {
    return SafeArea(                          // ← envolve tudo
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          border: Border(top: BorderSide(
              color: Colors.white.withOpacity(0.06))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _buildInputField()),
            const SizedBox(width: 10),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _perguntaController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _enviarMensagem(),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Pergunte sobre o diagnóstico...',
          hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.35), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: () async {
        await HapticFeedback.mediumImpact();
        _showSnackbar('Funcionalidade',
            'Reconhecimento de voz será implementado em breve',
            SnackbarType.info);
      },
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12),
        ),
        child: const Icon(Icons.mic_rounded,
            color: Colors.white38, size: 20),
      ),
    );
  }

  Widget _buildSendButton() {
    return Obx(() {
      final temTexto = _perguntaController.text.trim().isNotEmpty;
      final carregando = _chatLoading.value;

      return GestureDetector(
        onTap: temTexto && !carregando ? _enviarMensagem : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: temTexto && !carregando
                ? const LinearGradient(colors: [
              Color(0xFF00FF88), Color(0xFF00CC6A)])
                : LinearGradient(colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.06)]),
            shape: BoxShape.circle,
            boxShadow: temTexto && !carregando
                ? [BoxShadow(
                color: const Color(0xFF00FF88).withOpacity(0.3),
                blurRadius: 10)]
                : null,
          ),
          child: carregando
              ? const Padding(
              padding: EdgeInsets.all(11),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF00FF88)))
              : Icon(Icons.send_rounded,
              color: temTexto ? Colors.black : Colors.white24,
              size: 20),
        ),
      );
    });
  }

  // ── Chat ─────────────────────────────────────────────────────

  Widget _buildChatSection() {
    return Obx(() {
      if (_historico.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Divider com label
            Row(
              children: [
                Container(
                    width: 3, height: 14,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(2))),
                const Text('Conversa',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ..._historico.map((msg) => _buildMensagem(msg)),
            Obx(() {
              if (!_chatLoading.value) return const SizedBox.shrink();
              return _buildTypingIndicator();
            }),
          ],
        ),
      );
    });
  }

  Widget _buildMensagem(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF00FF88).withOpacity(0.12)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? const Color(0xFF00FF88).withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          msg['content'] ?? '',
          style: TextStyle(
              color: isUser ? const Color(0xFF00FF88) : Colors.white70,
              fontSize: 13,
              height: 1.5),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4)),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              3,
                  (i) => Padding(
                padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                child: _buildDot(i),
              )),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      builder: (context, value, _) => Transform.translate(
        offset: Offset(
            0, -4 * (value < 0.5 ? value * 2 : (1 - value) * 2)),
        child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
              color: Color(0xFF00FF88), shape: BoxShape.circle),
        ),
      ),
    );
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