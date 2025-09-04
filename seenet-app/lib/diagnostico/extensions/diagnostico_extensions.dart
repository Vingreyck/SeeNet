// lib/diagnostico/extensions/diagnostico_extensions.dart
// Extensions e utilitários avançados para o DiagnosticoView

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;

/// Extension para Context com métodos úteis
extension DiagnosticoContextExtension on BuildContext {
  /// Obter o theme atual
  ThemeData get theme => Theme.of(this);
  
  /// Obter media query
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  
  /// Obter tamanho da tela
  Size get screenSize => mediaQuery.size;
  
  /// Verificar se é dark mode
  bool get isDarkMode => theme.brightness == Brightness.dark;
  
  /// Obter padding seguro
  EdgeInsets get safeAreaPadding => mediaQuery.padding;
  
  /// Verificar se é tablet
  bool get isTablet => screenSize.shortestSide >= 600;
  
  /// Verificar se é mobile
  bool get isMobile => screenSize.shortestSide < 600;
  
  /// Mostrar snackbar customizado
  void showCustomSnackbar({
    required String message,
    required Color color,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Extension para Widget com métodos de animação
extension WidgetAnimationExtension on Widget {
  /// Adicionar shimmer effect
  Widget shimmer({
    Color baseColor = const Color(0xFF2A2A2A),
    Color highlightColor = const Color(0xFF3A3A3A),
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return _ShimmerWrapper(
      baseColor: baseColor,
      highlightColor: highlightColor,
      duration: duration,
      child: this,
    );
  }
  
  /// Adicionar fade in animation
  Widget fadeIn({
    Duration duration = const Duration(milliseconds: 500),
    Duration delay = Duration.zero,
  }) {
    return _FadeInWrapper(
      duration: duration,
      delay: delay,
      child: this,
    );
  }
  
  /// Adicionar slide animation
  Widget slideIn({
    Duration duration = const Duration(milliseconds: 500),
    Offset begin = const Offset(0, 1),
    Duration delay = Duration.zero,
  }) {
    return _SlideInWrapper(
      duration: duration,
      begin: begin,
      delay: delay,
      child: this,
    );
  }
  
  /// Adicionar scale animation
  Widget scaleIn({
    Duration duration = const Duration(milliseconds: 500),
    double begin = 0.0,
    Duration delay = Duration.zero,
  }) {
    return _ScaleInWrapper(
      duration: duration,
      begin: begin,
      delay: delay,
      child: this,
    );
  }
  
  /// Adicionar bounce effect
  Widget bounce({
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    return _BounceWrapper(
      duration: duration,
      child: this,
    );
  }
  
  /// Adicionar glass morphism effect
  Widget glassMorphism({
    double blur = 10.0,
    double opacity = 0.1,
    Color color = Colors.white,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: this,
        ),
      ),
    );
  }
  
  /// Adicionar neumorphism effect
  Widget neumorphism({
    Color backgroundColor = const Color(0xFF2A2A2A),
    double borderRadius = 12.0,
    double distance = 6.0,
    double blur = 16.0,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: Offset(distance, distance),
            blurRadius: blur,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            offset: Offset(-distance, -distance),
            blurRadius: blur,
          ),
        ],
      ),
      child: this,
    );
  }
}

/// Extension para AnimationController
extension AnimationControllerExtension on AnimationController {
  /// Executar animação com callback
  Future<void> animateWithCallback(
    VoidCallback? onComplete, {
    Duration? duration,
  }) async {
    if (duration != null) {
      await animateTo(1.0, duration: duration);
    } else {
      await forward();
    }
    onComplete?.call();
  }
  
  /// Repetir animação N vezes
  Future<void> repeatN(int times) async {
    for (int i = 0; i < times; i++) {
      await forward();
      await reverse();
    }
  }
  
  /// Animação de pulso
  void pulse() {
    repeat(reverse: true);
  }
}

/// Extension para String com formatação
extension StringFormattingExtension on String {
  /// Capitalizar primeira letra
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
  
  /// Truncar texto
  String truncate(int length, {String suffix = '...'}) {
    if (this.length <= length) return this;
    return '${substring(0, length)}$suffix';
  }
  
  /// Remover acentos
  String get removeAccents {
    const withAccents = 'àáâãäåòóôõöøèéêëðçðďíìíîïùúûüýžþñßÀÁÂÃÄÅÒÓÔÕÖØÈÉÊËÐÇĎÍÌÍÎÏÙÚÛÜÝŽÞÑŠ';
    const withoutAccents = 'aaaaaaooooooeeeeddciiiiiuuuuyznßAAAAAAOOOOOOEEEEDCDIIIIIUUUUYZPNS';
    
    String result = this;
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }
  
  /// Validar se é email
  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }
  
  /// Extrair palavras-chave
  List<String> get keywords {
    return toLowerCase()
        .removeAccents
        .split(' ')
        .where((word) => word.length > 3)
        .toList();
  }
}

/// Extension para DateTime
extension DateTimeExtension on DateTime {
  /// Formatar para brasileiro
  String get brazilianFormat {
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
  }
  
  /// Formatar com hora
  String get brazilianFormatWithTime {
    return '$brazilianFormat às ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
  
  /// Tempo relativo (há X tempo)
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);
    
    if (difference.inDays > 0) {
      return 'há ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'há ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'há ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'agora';
    }
  }
}

/// Extension para Color
extension ColorExtension on Color {
  /// Obter cor contrastante
  Color get contrastColor {
    return computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
  
  /// Escurecer cor
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
  
  /// Clarear cor
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
  
  /// Converter para hex
  String get hexString {
    return '#${toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}

/// Extension para List
extension ListExtension<T> on List<T> {
  /// Obter item seguro por índice
  T? safeGet(int index) {
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }
  
  /// Dividir lista em chunks
  List<List<T>> chunk(int size) {
    List<List<T>> chunks = [];
    for (int i = 0; i < length; i += size) {
      chunks.add(sublist(i, (i + size < length) ? i + size : length));
    }
    return chunks;
  }
  
  /// Remover duplicatas mantendo ordem
  List<T> unique() {
    return toSet().toList();
  }
}

// Widgets wrapper para animações

class _ShimmerWrapper extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const _ShimmerWrapper({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    required this.duration,
  });

  @override
  State<_ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<_ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: -1.0, end: 2.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
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
              colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
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

class _FadeInWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const _FadeInWrapper({
    required this.child,
    required this.duration,
    required this.delay,
  });

  @override
  State<_FadeInWrapper> createState() => _FadeInWrapperState();
}

class _FadeInWrapperState extends State<_FadeInWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _SlideInWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset begin;
  final Duration delay;

  const _SlideInWrapper({
    required this.child,
    required this.duration,
    required this.begin,
    required this.delay,
  });

  @override
  State<_SlideInWrapper> createState() => _SlideInWrapperState();
}

class _SlideInWrapperState extends State<_SlideInWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<Offset>(begin: widget.begin, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ScaleInWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double begin;
  final Duration delay;

  const _ScaleInWrapper({
    required this.child,
    required this.duration,
    required this.begin,
    required this.delay,
  });

  @override
  State<_ScaleInWrapper> createState() => _ScaleInWrapperState();
}

class _ScaleInWrapperState extends State<_ScaleInWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: widget.begin, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _BounceWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _BounceWrapper({
    required this.child,
    required this.duration,
  });

  @override
  State<_BounceWrapper> createState() => _BounceWrapperState();
}

class _BounceWrapperState extends State<_BounceWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.bounceOut));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Utilitários para HapticFeedback
class HapticUtils {
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }
  
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }
  
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }
  
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }
  
  static Future<void> success() async {
    await HapticFeedback.heavyImpact(); // Usar heavy para simular success
  }
  
  static Future<void> warning() async {
    await HapticFeedback.mediumImpact(); // Usar medium para simular warning
  }
  
  static Future<void> error() async {
    await HapticFeedback.heavyImpact(); // Usar heavy para simular error
  }
}

/// Classe para gerenciar cores do tema
class DiagnosticoColors {
  // Cores primárias
  static const Color primary = Color(0xFF00FF88);
  static const Color primaryDark = Color(0xFF00CC6A);
  static const Color secondary = Color(0xFF6B7280);
  
  // Cores de fundo
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color backgroundMedium = Color(0xFF1A1A1A);
  static const Color backgroundLight = Color(0xFF2A2A2A);
  
  // Cores de texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  
  // Cores de status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  
  // Cores de borda
  static const Color borderLight = Color(0xFF3A3A3A);
  static const Color borderMedium = Color(0xFF4A4A4A);
  static const Color borderAccent = Color(0xFF00FF88);
  
  /// Obter cor com opacidade
  static Color withAlpha(Color color, double alpha) {
    return color.withValues(alpha: alpha);
  }
  
  /// Gradiente primário
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Gradiente de fundo
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1A1A),
      Color(0xFF2D2D2D),
      Color(0xFF1F1F1F),
      Color(0xFF0A0A0A),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );
}

/// Classe para constantes de animação
class DiagnosticoAnimations {
  // Durações
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slower = Duration(milliseconds: 800);
  static const Duration shimmer = Duration(milliseconds: 1500);
  
  // Curves personalizadas
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve bounceOut = Curves.bounceOut;
  
  /// Curve customizada para micro-interactions
  static final Curve microInteraction = Curves.easeInOutCubic;
  
  /// Curve customizada para entrada de elementos
  static final Curve elementEntry = Curves.easeOutBack;
}

/// Classe para dimensões e espaçamentos
class DiagnosticoDimensions {
  // Padding
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 40.0;
  
  // Margin
  static const double marginXS = 4.0;
  static const double marginS = 8.0;
  static const double marginM = 16.0;
  static const double marginL = 24.0;
  static const double marginXL = 32.0;
  
  // Border radius
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusCircle = 999.0;
  
  // Elevação
  static const double elevationS = 2.0;
  static const double elevationM = 4.0;
  static const double elevationL = 8.0;
  static const double elevationXL = 16.0;
  
  // Tamanhos de ícones
  static const double iconXS = 16.0;
  static const double iconS = 20.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 40.0;
  
  // Tamanhos de avatar/logo
  static const double avatarS = 32.0;
  static const double avatarM = 48.0;
  static const double avatarL = 64.0;
  static const double avatarXL = 80.0;
  static const double avatarXXL = 120.0;
}

/// Classe para tipografia
class DiagnosticoTypography {
  // Tamanhos de fonte
  static const double fontSizeXS = 10.0;
  static const double fontSizeS = 12.0;
  static const double fontSizeM = 14.0;
  static const double fontSizeL = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSizeXXL = 20.0;
  static const double fontSizeTitle = 24.0;
  static const double fontSizeHeading = 28.0;
  
  // Pesos de fonte
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
  
  // Altura de linha
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightRelaxed = 1.6;
  static const double lineHeightLoose = 1.8;
  
  /// Estilos de texto pré-definidos
  static const TextStyle heading = TextStyle(
    fontSize: fontSizeHeading,
    fontWeight: bold,
    color: DiagnosticoColors.textPrimary,
    height: lineHeightTight,
  );
  
  static const TextStyle title = TextStyle(
    fontSize: fontSizeTitle,
    fontWeight: semiBold,
    color: DiagnosticoColors.textPrimary,
    height: lineHeightNormal,
  );
  
  static const TextStyle subtitle = TextStyle(
    fontSize: fontSizeXL,
    fontWeight: medium,
    color: DiagnosticoColors.textPrimary,
    height: lineHeightNormal,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: fontSizeL,
    fontWeight: regular,
    color: DiagnosticoColors.textPrimary,
    height: lineHeightRelaxed,
  );
  
  static const TextStyle bodySecondary = TextStyle(
    fontSize: fontSizeL,
    fontWeight: regular,
    color: DiagnosticoColors.textSecondary,
    height: lineHeightRelaxed,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: fontSizeS,
    fontWeight: regular,
    color: DiagnosticoColors.textTertiary,
    height: lineHeightNormal,
  );
  
  static const TextStyle label = TextStyle(
    fontSize: fontSizeM,
    fontWeight: medium,
    color: DiagnosticoColors.textPrimary,
    height: lineHeightNormal,
  );
}

/// Utilitários para validação
class ValidationUtils {
  /// Validar email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }
  
  /// Validar telefone brasileiro
  static bool isValidBrazilianPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 10 || cleaned.length == 11;
  }
  
  /// Validar CPF
  static bool isValidCPF(String cpf) {
    String cleaned = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 11) return false;
    
    // Verificar se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1*$').hasMatch(cleaned)) return false;
    
    // Validar dígitos verificadores
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cleaned[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;
    
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cleaned[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;
    
    return digit1 == int.parse(cleaned[9]) && digit2 == int.parse(cleaned[10]);
  }
  
  /// Validar se string não está vazia
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
  
  /// Validar comprimento mínimo
  static bool hasMinLength(String? value, int minLength) {
    return value != null && value.length >= minLength;
  }
  
  /// Validar se contém apenas números
  static bool isNumeric(String? value) {
    if (value == null) return false;
    return RegExp(r'^[0-9]+$').hasMatch(value);
  }
}

/// Utilitários para formatação
class FormatUtils {
  /// Formatar CPF
  static String formatCPF(String cpf) {
    String cleaned = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 11) {
      return '${cleaned.substring(0, 3)}.${cleaned.substring(3, 6)}.${cleaned.substring(6, 9)}-${cleaned.substring(9)}';
    }
    return cpf;
  }
  
  /// Formatar telefone
  static String formatPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 11) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
    }
    return phone;
  }
  
  /// Formatar moeda brasileira
  static String formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
  
  /// Formatar porcentagem
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
  }
  
  /// Truncar texto
  static String truncateText(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}$suffix';
  }
}

/// Utilitários para performance
class PerformanceUtils {
  /// Debounce function
  static Timer? _debounceTimer;
  
  static void debounce(Duration duration, VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, callback);
  }
  
  /// Throttle function
  static DateTime? _lastThrottleTime;
  
  static void throttle(Duration duration, VoidCallback callback) {
    final now = DateTime.now();
    if (_lastThrottleTime == null || 
        now.difference(_lastThrottleTime!) >= duration) {
      _lastThrottleTime = now;
      callback();
    }
  }
  
  /// Dispose timers
  static void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _lastThrottleTime = null;
  }
}

/// Enum para breakpoints responsivos
enum ScreenBreakpoint {
  mobile(480),
  tablet(768),
  desktop(1024),
  large(1200);
  
  const ScreenBreakpoint(this.width);
  final double width;
  
  static ScreenBreakpoint fromWidth(double width) {
    if (width >= large.width) return large;
    if (width >= desktop.width) return desktop;
    if (width >= tablet.width) return tablet;
    return mobile;
  }
}

/// Extension para responsive design
extension ResponsiveExtension on BuildContext {
  ScreenBreakpoint get breakpoint {
    return ScreenBreakpoint.fromWidth(screenSize.width);
  }
  
  bool get isMobileBreakpoint => breakpoint == ScreenBreakpoint.mobile;
  bool get isTabletBreakpoint => breakpoint == ScreenBreakpoint.tablet;
  bool get isDesktopBreakpoint => breakpoint == ScreenBreakpoint.desktop;
  bool get isLargeBreakpoint => breakpoint == ScreenBreakpoint.large;
  
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? large,
  }) {
    switch (breakpoint) {
      case ScreenBreakpoint.large:
        return large ?? desktop ?? tablet ?? mobile;
      case ScreenBreakpoint.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenBreakpoint.tablet:
        return tablet ?? mobile;
      case ScreenBreakpoint.mobile:
        return mobile;
    }
  }
}

// Import necessário já está no topo do arquivo