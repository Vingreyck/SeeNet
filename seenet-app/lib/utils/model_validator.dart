class ModelValidator {
  static void requireNotNull(dynamic value, String fieldName) {
    if (value == null) {
      throw ArgumentError('Campo "$fieldName" é obrigatório');
    }
  }

  static void requireNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      throw ArgumentError('Campo "$fieldName" não pode estar vazio');
    }
  }

  static void requirePositive(int? value, String fieldName) {
    if (value == null || value <= 0) {
      throw ArgumentError('Campo "$fieldName" deve ser positivo');
    }
  }

  static void requireValidEmail(String? value) {
    if (value == null || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      throw ArgumentError('Email inválido');
    }
  }

  static void requireValidStatus(String? value, List<String> validStatuses, String fieldName) {
    if (value == null || !validStatuses.contains(value)) {
      throw ArgumentError('Campo "$fieldName" deve ser um dos valores válidos: ${validStatuses.join(", ")}');
    }
  }
}