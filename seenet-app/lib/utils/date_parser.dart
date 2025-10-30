import 'package:flutter/foundation.dart';

class DateParser {
  /// Parse DateTime de forma segura, retornando null em caso de erro
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      
      // Tentar converter para string e fazer parse
      return DateTime.parse(value.toString());
    } catch (e) {
      debugPrint('DateParser error: Failed to parse "$value" - $e');
      return null;
    }
  }

  /// Parse com fallback para valor padrão
  static DateTime parseDateTimeOrDefault(dynamic value, DateTime defaultValue) {
    return parseDateTime(value) ?? defaultValue;
  }

  /// Parse com exceção se falhar
  static DateTime parseDateTimeStrict(dynamic value) {
    final result = parseDateTime(value);
    if (result == null) {
      throw ArgumentError('Failed to parse DateTime from: $value');
    }
    return result;
  }
}