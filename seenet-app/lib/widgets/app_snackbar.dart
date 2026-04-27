import 'package:flutter/material.dart';

/// Chave global do ScaffoldMessenger.
///
/// Conecte ao GetMaterialApp com `scaffoldMessengerKey: appScaffoldMessengerKey`.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

/// Posição da snackbar — espelha o enum SnackPosition do GetX para
/// permitir drop-in replacement do `Get.snackbar`.
enum SnackPosition { TOP, BOTTOM }

/// Substituto direto do `Get.snackbar` usando ScaffoldMessenger nativo.
///
/// Aceita os MESMOS parâmetros do `Get.snackbar` (incluindo
/// `backgroundColor`, `colorText`, `snackPosition`, `duration`, `icon`)
/// para que a migração seja só trocar `Get.snackbar(` por
/// `AppSnackbar.show(`.
///
/// Por que existe: `Get.snackbar` tem bug `LateInitializationError:
/// _animation has not been initialized` no Flutter Web 3.38+ (issues
/// #2196, #2257, #2761, #3055, #3420 do GetX). O ScaffoldMessenger
/// nativo do Flutter não tem esse bug.
class AppSnackbar {
  AppSnackbar._();

  /// Drop-in replacement de `Get.snackbar(title, message, ...)`.
  ///
  /// Aceita parâmetros nomeados extras silenciosamente (alguns do GetX
  /// não têm equivalente exato — são ignorados sem quebrar a API).
  static void show(
      String title,
      String message, {
        Color? backgroundColor,
        Color? colorText,
        Duration duration = const Duration(seconds: 3),
        SnackPosition snackPosition = SnackPosition.BOTTOM,
        IconData? icon,
        Widget? iconWidget,
        EdgeInsets? margin,
        double? borderRadius,
        // Parâmetros do Get.snackbar que ignoramos silenciosamente
        // (não fazem diferença prática ou não têm equivalente):
        Color? borderColor,
        double? borderWidth,
        double? barBlur,
        double? overlayBlur,
        Color? overlayColor,
        bool? isDismissible,
        Object? forwardAnimationCurve,
        Object? reverseAnimationCurve,
        Object? animationDuration,
        Object? mainButton,
        Object? onTap,
        Object? shouldIconPulse,
        Object? maxWidth,
        Object? padding,
        Object? boxShadows,
        Object? backgroundGradient,
        Object? dismissDirection,
        Object? showProgressIndicator,
        Object? progressIndicatorController,
        Object? progressIndicatorBackgroundColor,
        Object? progressIndicatorValueColor,
        Object? snackStyle,
        Object? messageText,
        Object? titleText,
        Object? userInputForm,
        Object? leftBarIndicatorColor,
      }) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    // Limpa fila pra não acumular snackbars
    messenger.clearSnackBars();

    final bg = backgroundColor ?? const Color(0xFF323232);
    final fg = colorText ?? Colors.white;
    final radius = borderRadius ?? 8.0;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: TextStyle(color: fg, fontSize: 13),
        ),
      ],
    );

    // Se tem ícone, coloca à esquerda do conteúdo
    if (icon != null || iconWidget != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ?? Icon(icon, color: fg, size: 24),
          const SizedBox(width: 12),
          Flexible(child: content),
        ],
      );
    }

    final isTop = snackPosition == SnackPosition.TOP;

    messenger.showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: bg,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: margin ??
            (isTop
                ? const EdgeInsets.fromLTRB(16, 16, 16, 16)
                : const EdgeInsets.fromLTRB(16, 16, 16, 80)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  // ─── Atalhos por tipo (opcionais, para código novo) ──────────────────

  static void error(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFFD32F2F));

  static void warning(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFFF57C00));

  static void success(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFF388E3C));

  static void info(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFF1976D2));
}