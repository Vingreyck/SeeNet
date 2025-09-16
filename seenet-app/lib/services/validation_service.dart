// lib/services/validation_service.dart
import 'package:flutter/material.dart';

/// Resultado de validação
class ValidationResult {
  final bool isValid;
  final String? error;
  final ValidationSeverity severity;
  final String? suggestion;
  
  const ValidationResult({
    required this.isValid,
    this.error,
    this.severity = ValidationSeverity.error,
    this.suggestion,
  });
  
  factory ValidationResult.valid() {
    return const ValidationResult(isValid: true);
  }
  
  factory ValidationResult.invalid(String error, {
    ValidationSeverity severity = ValidationSeverity.error,
    String? suggestion,
  }) {
    return ValidationResult(
      isValid: false,
      error: error,
      severity: severity,
      suggestion: suggestion,
    );
  }
}

/// Severidade da validação
enum ValidationSeverity {
  info(Colors.blue),
  warning(Colors.orange),
  error(Colors.red);
  
  const ValidationSeverity(this.color);
  final Color color;
}

/// Tipos de validação pré-definidos
enum ValidationType {
  email,
  password,
  name,
  phone,
  cpf,
  cnpj,
  cep,
  url,
  custom,
}

/// Regras de validação para senha
class PasswordRules {
  final int minLength;
  final int maxLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireDigits;
  final bool requireSpecialChars;
  final bool allowSpaces;
  final List<String> forbiddenPasswords;
  
  const PasswordRules({
    this.minLength = 6,
    this.maxLength = 128,
    this.requireUppercase = false,
    this.requireLowercase = false,
    this.requireDigits = false,
    this.requireSpecialChars = false,
    this.allowSpaces = false,
    this.forbiddenPasswords = const [],
  });
  
  // Regras pré-definidas
  static const PasswordRules basic = PasswordRules(
    minLength: 6,
    maxLength: 128,
  );
  
  static const PasswordRules strong = PasswordRules(
    minLength: 8,
    maxLength: 128,
    requireUppercase: true,
    requireLowercase: true,
    requireDigits: true,
    requireSpecialChars: true,
    forbiddenPasswords: [
      '123456', 'password', '123123', 'admin', 'qwerty',
      '111111', '000000', 'senha123', 'admin123'
    ],
  );
  
  static const PasswordRules enterprise = PasswordRules(
    minLength: 12,
    maxLength: 128,
    requireUppercase: true,
    requireLowercase: true,
    requireDigits: true,
    requireSpecialChars: true,
    forbiddenPasswords: [
      '123456', 'password', '123123', 'admin', 'qwerty',
      '111111', '000000', 'senha123', 'admin123', 'password123',
      'admin1234', 'user123', 'test123', 'empresa123'
    ],
  );
}

/// Serviço de validação avançado
class ValidationService {
  // Singleton
  ValidationService._();
  static final ValidationService instance = ValidationService._();
  
  // Caracteres especiais permitidos
  static const String _specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
  
  // Regexes pré-compilados para performance
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
  );
  
  static final RegExp _phoneRegex = RegExp(r'^\(\d{2}\)\s\d{4,5}-\d{4}$');
  static final RegExp _cpfRegex = RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$');
  static final RegExp _cnpjRegex = RegExp(r'^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$');
  static final RegExp _cepRegex = RegExp(r'^\d{5}-\d{3}$');
  static final RegExp _urlRegex = RegExp(
    r'^https?://(?:[-\w.])+(?:[:\d]+)?(?:/(?:[\w/_.])*(?:\?(?:[\w&=%.]*))?(?:#(?:[\w.]*))?)?$'
  );
  
  // Listas de domínios comuns para sugestões
  static const List<String> _commonDomains = [
    'gmail.com', 'hotmail.com', 'yahoo.com', 'outlook.com',
    'terra.com.br', 'uol.com.br', 'bol.com.br', 'ig.com.br'
  ];
  
  /// ========== SANITIZAÇÃO AVANÇADA ==========
  
  /// Sanitizar input geral
  String sanitizeInput(String input, {
    bool allowSpecialChars = false,
    bool allowSpaces = true,
    bool allowNumbers = true,
    bool allowEmojis = false,
    int? maxLength,
  }) {
    if (input.isEmpty) return input;
    
    String sanitized = input.trim();
    
    // Remover caracteres perigosos
    sanitized = _removeDangerousChars(sanitized);
    
    // Normalizar espaços
    if (allowSpaces) {
      sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    } else {
      sanitized = sanitized.replaceAll(RegExp(r'\s'), '');
    }
    
    // Filtrar caracteres especiais
    if (!allowSpecialChars) {
      sanitized = sanitized.replaceAll(RegExp(r'[^\w\s@.-]'), '');
    }
    
    // Filtrar números
    if (!allowNumbers) {
      sanitized = sanitized.replaceAll(RegExp(r'\d'), '');
    }
    
    // Filtrar emojis
    if (!allowEmojis) {
      sanitized = _removeEmojis(sanitized);
    }
    
    // Limitar tamanho
    if (maxLength != null && sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    return sanitized;
  }
  
  /// Sanitizar email
  String sanitizeEmail(String email) {
    return email
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w@.-]'), '')
        .substring(0, email.length > 254 ? 254 : email.length);
  }
  
  /// Sanitizar nome
  String sanitizeName(String name) {
    return sanitizeInput(
      name,
      allowSpecialChars: false,
      allowSpaces: true,
      allowNumbers: false,
      allowEmojis: false,
      maxLength: 100,
    ).split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ')
        .trim();
  }
  
  /// Sanitizar telefone
  String sanitizePhone(String phone) {
    // Remove tudo exceto números
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Formatar para padrão brasileiro
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 11) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
    }
    
    return phone; // Retorna original se não conseguir formatar
  }
  
  /// ========== VALIDAÇÕES ESPECÍFICAS ==========
  
  /// Validar email
  ValidationResult validateEmail(String email, {bool allowEmpty = false}) {
    if (email.isEmpty && allowEmpty) {
      return ValidationResult.valid();
    }
    
    if (email.isEmpty) {
      return ValidationResult.invalid('Email é obrigatório');
    }
    
    if (email.length > 254) {
      return ValidationResult.invalid('Email muito longo (máximo 254 caracteres)');
    }
    
    // Verificar formato básico
    if (!_emailRegex.hasMatch(email)) {
      // Tentar sugerir correção
      String? suggestion = _suggestEmailCorrection(email);
      return ValidationResult.invalid(
        'Formato de email inválido',
        suggestion: suggestion != null ? 'Você quis dizer: $suggestion?' : null,
      );
    }
    
    // Verificar domínio suspeito
    String domain = email.split('@').last.toLowerCase();
    if (_isSuspiciousDomain(domain)) {
      return ValidationResult.invalid(
        'Domínio suspeito ou inválido',
        severity: ValidationSeverity.warning,
      );
    }
    
    return ValidationResult.valid();
  }
  
  /// Validar senha
  ValidationResult validatePassword(String password, {
    PasswordRules rules = PasswordRules.basic,
    String? confirmPassword,
  }) {
    if (password.isEmpty) {
      return ValidationResult.invalid('Senha é obrigatória');
    }
    
    // Verificar tamanho
    if (password.length < rules.minLength) {
      return ValidationResult.invalid(
        'Senha deve ter pelo menos ${rules.minLength} caracteres'
      );
    }
    
    if (password.length > rules.maxLength) {
      return ValidationResult.invalid(
        'Senha muito longa (máximo ${rules.maxLength} caracteres)'
      );
    }
    
    // Verificar espaços
    if (!rules.allowSpaces && password.contains(' ')) {
      return ValidationResult.invalid('Senha não pode conter espaços');
    }
    
    // Verificar maiúsculas
    if (rules.requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      return ValidationResult.invalid(
        'Senha deve conter pelo menos uma letra maiúscula'
      );
    }
    
    // Verificar minúsculas
    if (rules.requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      return ValidationResult.invalid(
        'Senha deve conter pelo menos uma letra minúscula'
      );
    }
    
    // Verificar números
    if (rules.requireDigits && !password.contains(RegExp(r'\d'))) {
      return ValidationResult.invalid(
        'Senha deve conter pelo menos um número'
      );
    }
    
    // Verificar caracteres especiais
    if (rules.requireSpecialChars && !_containsSpecialChar(password)) {
      return ValidationResult.invalid(
        'Senha deve conter pelo menos um caractere especial ($_specialChars)'
      );
    }
    
    // Verificar senhas proibidas
    if (rules.forbiddenPasswords.contains(password.toLowerCase())) {
      return ValidationResult.invalid(
        'Esta senha é muito comum. Escolha uma senha mais segura.'
      );
    }
    
    // Verificar confirmação de senha
    if (confirmPassword != null && password != confirmPassword) {
      return ValidationResult.invalid('Senhas não coincidem');
    }
    
    return ValidationResult.valid();
  }
  
  /// Validar nome
  ValidationResult validateName(String name, {
    bool allowEmpty = false,
    int minLength = 2,
    int maxLength = 100,
  }) {
    if (name.isEmpty && allowEmpty) {
      return ValidationResult.valid();
    }
    
    if (name.isEmpty) {
      return ValidationResult.invalid('Nome é obrigatório');
    }
    
    if (name.length < minLength) {
      return ValidationResult.invalid(
        'Nome deve ter pelo menos $minLength caracteres'
      );
    }
    
    if (name.length > maxLength) {
      return ValidationResult.invalid(
        'Nome muito longo (máximo $maxLength caracteres)'
      );
    }
    
    // Verificar se contém apenas letras e espaços
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(name)) {
      return ValidationResult.invalid(
        'Nome deve conter apenas letras e espaços'
      );
    }
    
    // Verificar se não é apenas espaços
    if (name.trim().isEmpty) {
      return ValidationResult.invalid('Nome não pode ser apenas espaços');
    }
    
    return ValidationResult.valid();
  }
  
  /// Validar telefone brasileiro
  ValidationResult validatePhone(String phone, {bool allowEmpty = false}) {
    if (phone.isEmpty && allowEmpty) {
      return ValidationResult.valid();
    }
    
    if (phone.isEmpty) {
      return ValidationResult.invalid('Telefone é obrigatório');
    }
    
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleaned.length < 10 || cleaned.length > 11) {
      return ValidationResult.invalid(
        'Telefone deve ter 10 ou 11 dígitos',
        suggestion: 'Formato: (11) 99999-9999',
      );
    }
    
    // Verificar DDD válido
    if (cleaned.length >= 2) {
      int ddd = int.tryParse(cleaned.substring(0, 2)) ?? 0;
      if (!_isValidDDD(ddd)) {
        return ValidationResult.invalid('DDD inválido');
      }
    }
    
    return ValidationResult.valid();
  }
  
  /// Validar CPF
  ValidationResult validateCPF(String cpf, {bool allowEmpty = false}) {
    if (cpf.isEmpty && allowEmpty) {
      return ValidationResult.valid();
    }
    
    if (cpf.isEmpty) {
      return ValidationResult.invalid('CPF é obrigatório');
    }
    
    String cleaned = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleaned.length != 11) {
      return ValidationResult.invalid(
        'CPF deve ter 11 dígitos',
        suggestion: 'Formato: 000.000.000-00',
      );
    }
    
    // Verificar sequências inválidas
    if (RegExp(r'^(\d)\1*$').hasMatch(cleaned)) {
      return ValidationResult.invalid('CPF inválido');
    }
    
    // Validar dígitos verificadores
    if (!_isValidCPF(cleaned)) {
      return ValidationResult.invalid('CPF inválido');
    }
    
    return ValidationResult.valid();
  }
  
  /// Validar URL
  ValidationResult validateUrl(String url, {bool allowEmpty = false}) {
    if (url.isEmpty && allowEmpty) {
      return ValidationResult.valid();
    }
    
    if (url.isEmpty) {
      return ValidationResult.invalid('URL é obrigatória');
    }
    
    if (!_urlRegex.hasMatch(url)) {
      return ValidationResult.invalid(
        'Formato de URL inválido',
        suggestion: 'Deve começar com http:// ou https://',
      );
    }
    
    return ValidationResult.valid();
  }
  
  /// ========== VALIDAÇÃO CUSTOMIZADA ==========
  
  /// Validar campo customizado
  ValidationResult validateCustom(
    String value,
    List<ValidationRule> rules, {
    bool allowEmpty = false,
  }) {
    if (value.isEmpty && allowEmpty) {
      return ValidationResult.valid();
    }
    
    for (var rule in rules) {
      ValidationResult result = rule.validate(value);
      if (!result.isValid) {
        return result;
      }
    }
    
    return ValidationResult.valid();
  }
  
  /// ========== MÉTODOS AUXILIARES ==========
  
  /// Remover caracteres perigosos
  String _removeDangerousChars(String input) {
    return input
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('&', '')
        .replaceAll('\\', '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''); // Caracteres de controle
  }
  
  /// Remover emojis
  String _removeEmojis(String input) {
    return input.replaceAll(
      RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]',
          unicode: true),
      '',
    );
  }
  
  /// Verificar se contém caractere especial
  bool _containsSpecialChar(String password) {
    return password.split('').any((char) => _specialChars.contains(char));
  }

  /// Verificar se contém caractere especial (método público)
  bool containsSpecialChar(String text) {
    return _containsSpecialChar(text);
  }
  
  /// Sugerir correção de email
  String? _suggestEmailCorrection(String email) {
    if (!email.contains('@')) return null;
    
    List<String> parts = email.split('@');
    if (parts.length != 2) return null;
    
    String domain = parts[1].toLowerCase();
    
    // Verificar domínios similares
    for (String commonDomain in _commonDomains) {
      if (_calculateLevenshteinDistance(domain, commonDomain) <= 2) {
        return '${parts[0]}@$commonDomain';
      }
    }
    
    return null;
  }
  
  /// Verificar domínio suspeito
  bool _isSuspiciousDomain(String domain) {
    // Lista de domínios suspeitos ou temporários
    List<String> suspiciousDomains = [
      '10minutemail.com', 'mailinator.com', 'guerrillamail.com',
      'tempmail.org', 'throwaway.email'
    ];
    
    return suspiciousDomains.contains(domain.toLowerCase());
  }
  
  /// Verificar DDD válido
  bool _isValidDDD(int ddd) {
    List<int> validDDDs = [
      11, 12, 13, 14, 15, 16, 17, 18, 19, // São Paulo
      21, 22, 24, // Rio de Janeiro
      27, 28, // Espírito Santo
      31, 32, 33, 34, 35, 37, 38, // Minas Gerais
      41, 42, 43, 44, 45, 46, // Paraná
      47, 48, 49, // Santa Catarina
      51, 53, 54, 55, // Rio Grande do Sul
      61, // Distrito Federal
      62, 64, // Goiás
      63, // Tocantins
      65, 66, // Mato Grosso
      67, // Mato Grosso do Sul
      68, // Acre
      69, // Rondônia
      71, 73, 74, 75, 77, // Bahia
      79, // Sergipe
      81, 87, // Pernambuco
      82, // Alagoas
      83, // Paraíba
      84, // Rio Grande do Norte
      85, 88, // Ceará
      86, 89, // Piauí
      91, 93, 94, // Pará
      92, 97, // Amazonas
      95, // Roraima
      96, // Amapá
      98, 99, // Maranhão
    ];
    
    return validDDDs.contains(ddd);
  }
  
  /// Validar CPF (dígitos verificadores)
  bool _isValidCPF(String cpf) {
    // Primeiro dígito
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;
    
    if (digit1 != int.parse(cpf[9])) return false;
    
    // Segundo dígito
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;
    
    return digit2 == int.parse(cpf[10]);
  }
  
  /// Calcular distância de Levenshtein
  int _calculateLevenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );
    
    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[s1.length][s2.length];
  }
  
  /// ========== UTILITÁRIOS PARA FORÇA DE SENHA ==========
  
  /// Calcular força da senha
  PasswordStrength calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.veryWeak;
    
    int score = 0;
    
    // Comprimento
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;
    
    // Diversidade de caracteres
    if (password.contains(RegExp(r'[a-z]'))) score += 1;
    if (password.contains(RegExp(r'[A-Z]'))) score += 1;
    if (password.contains(RegExp(r'\d'))) score += 1;
    if (_containsSpecialChar(password)) score += 1;
    
    // Penalidades
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) score -= 1; // Repetições
    if (RegExp(r'123|abc|qwe').hasMatch(password.toLowerCase())) score -= 1; // Sequências
    
    if (score <= 2) return PasswordStrength.veryWeak;
    if (score <= 4) return PasswordStrength.weak;
    if (score <= 6) return PasswordStrength.medium;
    if (score <= 8) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }
  
  /// Gerar sugestão de senha forte
  String generateStrongPassword({int length = 12}) {
    const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return List.generate(length, (index) {
      return chars[(random + index) % chars.length];
    }).join();
  }
}

/// ========== CLASSES AUXILIARES ==========

/// Força da senha
enum PasswordStrength {
  veryWeak(0, 'Muito Fraca', Colors.red),
  weak(1, 'Fraca', Colors.orange),
  medium(2, 'Média', Colors.yellow),
  strong(3, 'Forte', Color(0xFF4CAF50)),
  veryStrong(4, 'Muito Forte', Color(0xFF00FF88));
  
  const PasswordStrength(this.level, this.label, this.color);
  final int level;
  final String label;
  final Color color;
}

/// Regra de validação customizada
abstract class ValidationRule {
  ValidationResult validate(String value);
}

/// Regra de comprimento mínimo
class MinLengthRule extends ValidationRule {
  final int minLength;
  final String? message;
  
  MinLengthRule(this.minLength, {this.message});
  
  @override
  ValidationResult validate(String value) {
    if (value.length < minLength) {
      return ValidationResult.invalid(
        message ?? 'Deve ter pelo menos $minLength caracteres'
      );
    }
    return ValidationResult.valid();
  }
}

/// Regra de expressão regular
class RegexRule extends ValidationRule {
  final RegExp regex;
  final String message;
  
  RegexRule(this.regex, this.message);
  
  @override
  ValidationResult validate(String value) {
    if (!regex.hasMatch(value)) {
      return ValidationResult.invalid(message);
    }
    return ValidationResult.valid();
  }
}

/// Regra customizada com função
class CustomRule extends ValidationRule {
  final bool Function(String) validator;
  final String message;
  
  CustomRule(this.validator, this.message);
  
  @override
  ValidationResult validate(String value) {
    if (!validator(value)) {
      return ValidationResult.invalid(message);
    }
    return ValidationResult.valid();
  }
}