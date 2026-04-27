import 'package:get/get.dart';

class NavHelper {
  /// Navega com segurança, sem crashar snackbars em fila
  static void go(String route, {dynamic arguments}) {
    _fecharSnackbarsSafe();
    Future.microtask(() => Get.toNamed(route, arguments: arguments));
  }

  static void off(String route, {dynamic arguments}) {
    _fecharSnackbarsSafe();
    Future.microtask(() => Get.offNamed(route, arguments: arguments));
  }

  static void offAll(String route, {dynamic arguments}) {
    _fecharSnackbarsSafe();
    Future.microtask(() => Get.offAllNamed(route, arguments: arguments));
  }

  static void back() {
    _fecharSnackbarsSafe();
    Future.microtask(() => Get.back());
  }

  static void _fecharSnackbarsSafe() {
    try {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
    } catch (_) {}
  }
}