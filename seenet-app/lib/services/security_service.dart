// lib/services/security_service.dart - VERSÃO CORRIGIDA
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'dart:math';
import '../config/environment.dart'; // ← IMPORT NECESSÁRIO

enum PasswordStrength {
  weak,
  medium,
  strong,
}

class SecurityService {
  static const String _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  static final Random _rnd = Random();
  
  // Hash de senha com salt
  static String hashPassword(String password, {String? salt}) {
    salt ??= generateSalt();
    var bytes = utf8.encode(password + salt);
    var digest = sha256.convert(bytes);
    return '$salt:${digest.toString()}';
  }
  
  // Verificar senha
  static bool verifyPassword(String password, String hashedPassword) {
    try {
      var parts = hashedPassword.split(':');
      if (parts.length != 2) return false;
      
      String salt = parts[0];
      String hash = parts[1];
      
      var newHash = hashPassword(password, salt: salt);
      return newHash == hashedPassword;
    } catch (e) {
      return false;
    }
  }
  
  // Gerar salt aleatório
  static String generateSalt({int length = 16}) {
    return String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))
    ));
  }
  
  // Sanitizar input do usuário
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;
    
    return input
      .trim()
      .replaceAll(RegExp(r'[<>"\\]'), '') // Remove < > " \
      .replaceAll(RegExp(r"'"), '')        // Remove aspas simples
      .replaceAll(RegExp(r'\s+'), ' ') // Normaliza espaços
      .substring(0, input.length > 255 ? 255 : input.length); // Limita tamanho
  }
  
  // Validar email
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }
  
  // Validar senha forte
  static String? validatePassword(String password) {
    if (password.length < 6) {
      return 'Senha deve ter pelo menos 6 caracteres';
    }
    
    if (password.length > 128) {
      return 'Senha muito longa (máximo 128 caracteres)';
    }
    
    // Para produção, pode adicionar mais regras:
    if (Environment.isProduction) {
      if (!password.contains(RegExp(r'[0-9]'))) {
        return 'Senha deve conter pelo menos um número';
      }
      
      if (!password.contains(RegExp(r'[a-zA-Z]'))) {
        return 'Senha deve conter pelo menos uma letra';
      }
    }
    
    return null; // Senha válida
  }
  
  // Gerar token de sessão
  static String generateSessionToken() {
    return generateSalt(length: 32);
  }
  
  // Rate limiting simples (em memória)
  static final Map<String, List<DateTime>> _attemptHistory = {};
  
  static bool checkRateLimit(String identifier, {int maxAttempts = 5, Duration window = const Duration(minutes: 15)}) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    
    // Limpar tentativas antigas
    _attemptHistory[identifier]?.removeWhere((attempt) => attempt.isBefore(cutoff));
    
    // Verificar limite
    final attempts = _attemptHistory[identifier] ?? [];
    if (attempts.length >= maxAttempts) {
      return false; // Limite excedido
    }
    
    // Registrar tentativa
    _attemptHistory[identifier] = [...attempts, now];
    return true;
  }
  
  // Limpar histórico de tentativas (para quando login for bem-sucedido)
  static void clearRateLimit(String identifier) {
    _attemptHistory.remove(identifier);
  }
  
  // Mascarar dados sensíveis para logs
  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars * 2) {
      return '*' * data.length;
    }
    
    return '${data.substring(0, visibleChars)}${'*' * (data.length - visibleChars * 2)}${data.substring(data.length - visibleChars)}';
  }
  static String encrypt(String plainText, String key) {
    try {
      // Pad the key to exactly 32 bytes (256 bits)
      final paddedKey = key.padRight(32).substring(0, 32);
      
      final encrypter = Encrypter(AES(Key.fromUtf8(paddedKey)));
      final iv = IV.fromLength(16); // Generate IV for AES
      
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return '${encrypted.base64}:${iv.base64}'; // Store IV with encrypted data
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  static String decrypt(String encryptedText, String key) {
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 2) throw Exception('Invalid encrypted text format');

      // Pad the key to exactly 32 bytes (256 bits)
      final paddedKey = key.padRight(32).substring(0, 32);
      
      final encrypter = Encrypter(AES(Key.fromUtf8(paddedKey)));
      final iv = IV.fromBase64(parts[1]);
      final encrypted = Encrypted.fromBase64(parts[0]);
      
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  static PasswordStrength checkPasswordStrength(String password) {
  int strength = 0;
  
  if (password.length >= 8) strength++;
  if (password.length >= 12) strength++;
  if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
  if (RegExp(r'[a-z]').hasMatch(password)) strength++;
  if (RegExp(r'[0-9]').hasMatch(password)) strength++;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
  
  if (strength <= 2) return PasswordStrength.weak;
  if (strength <= 4) return PasswordStrength.medium;
  return PasswordStrength.strong;
}
}