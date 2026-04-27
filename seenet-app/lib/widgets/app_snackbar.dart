import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
export 'package:get/get.dart' show SnackPosition;

import 'package:get/get.dart' show SnackPosition;

/// Chave global do ScaffoldMessenger.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

/// Padrões de mensagens internas do framework que NÃO devem virar snackbar
/// para o usuário final. Se a mensagem casar com um desses, a snackbar
/// é silenciosamente ignorada (e logada no console em modo debug).
const List<String> _ruidoFramework = [
  'setState() or markNeedsBuild() called during build',
  'improper use of a GetX',
  'You should only use GetX or Obx',
  '_animation',
  'has not been initialized',
  'Navigator operation requested with a context',
];

bool _ehRuidoDoFramework(String title, String message) {
  final combined = '$title $message'.toLowerCase();
  for (final padrao in _ruidoFramework) {
    if (combined.contains(padrao.toLowerCase())) return true;
  }
  return false;
}

/// Substituto direto do `Get.snackbar` usando ScaffoldMessenger nativo.
class AppSnackbar {
  AppSnackbar._();

  static void show(
      String title,
      String message, {
        Color? backgroundColor,
        Color? colorText,
        Duration duration = const Duration(seconds: 3),
        SnackPosition snackPosition = SnackPosition.BOTTOM,
        Object? icon, // aceita Widget OU IconData
        EdgeInsets? margin,
        double? borderRadius,
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
    // ✅ Filtro: erros internos do framework nao viram snackbar para o usuario.
    //    Eles sao apenas registrados no console em modo debug.
    if (_ehRuidoDoFramework(title, message)) {
      if (kDebugMode) {
        debugPrint('🔇 [snackbar bloqueada] $title — ${message.split('\n').first}');
      }
      return;
    }

    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

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
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    Widget? iconWidget;
    if (icon is Widget) {
      iconWidget = icon;
    } else if (icon is IconData) {
      iconWidget = Icon(icon, color: fg, size: 24);
    }

    if (iconWidget != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
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

  static void error(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFFD32F2F));

  static void warning(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFFF57C00));

  static void success(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFF388E3C));

  static void info(String title, String message) =>
      show(title, message, backgroundColor: const Color(0xFF1976D2));
}