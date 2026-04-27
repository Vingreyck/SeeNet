// lib/utils/error_handler.dart - ROUND 9: Error Handling Consistency
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:seenet/widgets/app_snackbar.dart';

/// Sistema centralizado de tratamento de erros
/// Garante mensagens e estilos consistentes em todo o app
class ErrorHandler {
  // ========== TIPOS DE ERRO ==========
  
  /// Erro de rede (sem internet, timeout, etc)
  static void handleNetworkError(dynamic error, {String? context}) {
    print('🌐 Network Error: $error');
    
    String message = _getNetworkErrorMessage(error);
    
    if (Get.context != null) {
      AppSnackbar.show(
        'Erro de Conexão',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFFF9800), // Laranja
        colorText: Colors.white,
        icon: const Icon(Icons.wifi_off, color: Colors.white),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Erro de autenticação (401, token inválido)
  static void handleAuthError({String? message}) {
    print('🔐 Auth Error: ${message ?? "Token inválido"}');
    
    if (Get.context != null) {
      AppSnackbar.show(
        'Sessão Expirada',
        message ?? 'Faça login novamente',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFFF9800), // Laranja
        colorText: Colors.white,
        icon: const Icon(Icons.lock_clock, color: Colors.white),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
    
    // Redirecionar para login se não estiver já lá
    Future.delayed(const Duration(seconds: 1), () {
      if (Get.currentRoute != '/login') {
        Get.offAllNamed('/login');
      }
    });
  }

  /// Erro do servidor (500, 502, 503)
  static void handleServerError({String? message, int? statusCode}) {
    print('🔥 Server Error: $statusCode - ${message ?? "Erro interno"}');
    
    String displayMessage = message ?? 'Erro no servidor. Tente novamente mais tarde.';
    
    if (statusCode == 503) {
      displayMessage = 'Servidor em manutenção. Tente em alguns minutos.';
    } else if (statusCode == 502) {
      displayMessage = 'Servidor temporariamente indisponível.';
    }
    
    if (Get.context != null) {
      AppSnackbar.show(
        'Erro no Servidor',
        displayMessage,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFF44336), // Vermelho
        colorText: Colors.white,
        icon: const Icon(Icons.cloud_off, color: Colors.white),
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Erro de validação (dados inválidos, campos obrigatórios)
  static void handleValidationError(String message) {
    print('⚠️ Validation Error: $message');
    
    if (Get.context != null) {
      AppSnackbar.show(
        'Validação',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFFF9800), // Laranja
        colorText: Colors.white,
        icon: const Icon(Icons.warning_amber, color: Colors.white),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Erro de permissão (403, acesso negado)
  static void handlePermissionError({String? message}) {
    print('🚫 Permission Error: ${message ?? "Acesso negado"}');
    
    if (Get.context != null) {
      AppSnackbar.show(
        'Acesso Negado',
        message ?? 'Você não tem permissão para esta ação',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFF44336), // Vermelho
        colorText: Colors.white,
        icon: const Icon(Icons.block, color: Colors.white),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Erro não encontrado (404)
  static void handleNotFoundError({String? resource}) {
    print('🔍 Not Found: ${resource ?? "Recurso não encontrado"}');
    
    String message = resource != null 
        ? '$resource não encontrado'
        : 'Recurso não encontrado';
    
    if (Get.context != null) {
      AppSnackbar.show(
        'Não Encontrado',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFFF9800), // Laranja
        colorText: Colors.white,
        icon: const Icon(Icons.search_off, color: Colors.white),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Erro genérico (fallback)
  static void handleGenericError(String message) {
    print('❌ Generic Error: $message');
    
    if (Get.context != null) {
      AppSnackbar.show(
        'Erro',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFF44336), // Vermelho
        colorText: Colors.white,
        icon: const Icon(Icons.error, color: Colors.white),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  // ========== HANDLER PRINCIPAL ==========
  
  /// Handler principal que detecta o tipo de erro automaticamente
  static void handle(dynamic error, {String? context}) {
    print('\n🔧 === ERROR HANDLER ===');
    print('Context: ${context ?? "N/A"}');
    print('Error Type: ${error.runtimeType}');
    print('Error: $error');
    
    // TimeoutException
    if (error is TimeoutException) {
      handleNetworkError(error, context: context);
      return;
    }
    
    // String com padrões conhecidos
    if (error is String) {
      final errorLower = error.toLowerCase();
      
      if (errorLower.contains('socket') || 
          errorLower.contains('network') ||
          errorLower.contains('connection') ||
          errorLower.contains('internet')) {
        handleNetworkError(error, context: context);
      } else if (errorLower.contains('401') || 
                 errorLower.contains('unauthorized') ||
                 errorLower.contains('token') ||
                 errorLower.contains('autenticação')) {
        handleAuthError(message: error);
      } else if (errorLower.contains('403') || 
                 errorLower.contains('forbidden') ||
                 errorLower.contains('permissão')) {
        handlePermissionError(message: error);
      } else if (errorLower.contains('404') || 
                 errorLower.contains('not found')) {
        handleNotFoundError();
      } else if (errorLower.contains('500') || 
                 errorLower.contains('502') ||
                 errorLower.contains('503') ||
                 errorLower.contains('server error')) {
        handleServerError(message: error);
      } else {
        handleGenericError(error);
      }
      return;
    }
    
    // Map com statusCode
    if (error is Map) {
      final statusCode = error['statusCode'] as int?;
      final message = error['error'] as String? ?? error['message'] as String?;
      
      if (statusCode != null) {
        if (statusCode == 401) {
          handleAuthError(message: message);
        } else if (statusCode == 403) {
          handlePermissionError(message: message);
        } else if (statusCode == 404) {
          handleNotFoundError(resource: message);
        } else if (statusCode >= 500) {
          handleServerError(message: message, statusCode: statusCode);
        } else {
          handleGenericError(message ?? 'Erro desconhecido');
        }
        return;
      }
    }
    
    // Exception com mensagem
    if (error is Exception) {
      handleGenericError(error.toString().replaceAll('Exception: ', ''));
      return;
    }
    
    // Fallback
    handleGenericError(error.toString());
  }

  // ========== MENSAGENS DE SUCESSO (para consistência) ==========
  
  static void showSuccess(String message, {String? title}) {
    print('✅ Success: $message');
    
    if (Get.context != null) {
      AppSnackbar.show(
        title ?? 'Sucesso',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF00FF88), // Verde SeeNet
        colorText: Colors.black,
        icon: const Icon(Icons.check_circle, color: Colors.black),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  static void showInfo(String message, {String? title}) {
    print('ℹ️ Info: $message');
    
    if (Get.context != null) {
      AppSnackbar.show(
        title ?? 'Informação',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF2196F3), // Azul
        colorText: Colors.white,
        icon: const Icon(Icons.info, color: Colors.white),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  static void showWarning(String message, {String? title}) {
    print('⚠️ Warning: $message');
    
    if (Get.context != null) {
      AppSnackbar.show(
        title ?? 'Aviso',
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFFF9800), // Laranja
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  // ========== HELPERS PRIVADOS ==========
  
  static String _getNetworkErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout')) {
      return 'Tempo limite excedido. Verifique sua conexão.';
    }
    
    if (errorStr.contains('socket') || errorStr.contains('failed host lookup')) {
      return 'Sem conexão com a internet. Verifique sua rede.';
    }
    
    if (errorStr.contains('connection refused')) {
      return 'Não foi possível conectar ao servidor.';
    }
    
    return 'Erro de conexão. Tente novamente.';
  }
}

/// Extension para facilitar uso em controllers
extension ErrorHandlerExtension on GetxController {
  void handleError(dynamic error, {String? context}) {
    ErrorHandler.handle(error, context: context);
  }
  
  void showSuccess(String message, {String? title}) {
    ErrorHandler.showSuccess(message, title: title);
  }
  
  void showInfo(String message, {String? title}) {
    ErrorHandler.showInfo(message, title: title);
  }
  
  void showWarning(String message, {String? title}) {
    ErrorHandler.showWarning(message, title: title);
  }
}