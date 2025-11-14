import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlayIntegrityService {
  static const platform = MethodChannel('com.seenet.diagnostico/integrity');
  
  /// Solicita token de integridade e valida no backend
  static Future<Map<String, dynamic>> verifyIntegrity() async {
    try {
      // 1. Gerar nonce único
      final nonce = _generateNonce();
      
      // 2. Obter número do projeto do Google Cloud
      final cloudProjectNumber = int.parse(
        dotenv.env['GOOGLE_CLOUD_PROJECT_NUMBER'] ?? '0'
      );
      
      if (cloudProjectNumber == 0) {
        throw Exception('GOOGLE_CLOUD_PROJECT_NUMBER não configurado');
      }
      
      // 3. Solicitar token de integridade (via código nativo)
      final String token = await platform.invokeMethod(
        'requestIntegrityToken',
        {
          'nonce': nonce,
          'cloudProjectNumber': cloudProjectNumber,
        },
      );
      
      print('✅ Token de integridade gerado');
      
      // 4. Validar token no backend
      final validationResult = await _validateTokenOnBackend(token);
      
      return validationResult;
      
    } on PlatformException catch (e) {
      print('❌ Erro na Play Integrity API: ${e.message}');
      return {
        'isValid': false,
        'error': 'Erro ao gerar token: ${e.message}',
      };
    } catch (e) {
      print('❌ Erro inesperado: $e');
      return {
        'isValid': false,
        'error': 'Erro inesperado: $e',
      };
    }
  }
  
  /// Gera nonce único baseado em timestamp
  static String _generateNonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    return '$timestamp-$random';
  }
  
/// Valida token no backend
static Future<Map<String, dynamic>> _validateTokenOnBackend(String token) async {
  try {
    final apiUrl = dotenv.env['API_URL'];
    
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('API_URL não configurado');
    }
    
    final response = await http.post(
      Uri.parse('$apiUrl/api/verify-integrity'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'integrityToken': token}),
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      
      // ✅ ADICIONAR: Log detalhado dos vereditos
      print('📊 Vereditos recebidos:');
      print('   Device: ${result['verdict']?['device']}');
      print('   App: ${result['verdict']?['app']}');
      print('   License: ${result['verdict']?['license']}');
      print('   isValid: ${result['isValid']}');
      
      // ✅ ADICIONAR: Para testes, aceitar MEETS_BASIC_INTEGRITY
      if (result['verdict']?['device'] != null) {
        final deviceVerdict = result['verdict']['device'].toString();
        if (deviceVerdict.contains('MEETS_BASIC_INTEGRITY') || 
            deviceVerdict.contains('MEETS_DEVICE_INTEGRITY')) {
          print('⚠️ MODO TESTE: Dispositivo tem integridade básica');
          // Não força isValid = true, apenas informa
        }
      }
      
      return result;
    } else {
      return {
        'isValid': false,
        'error': 'Backend retornou status ${response.statusCode}',
      };
    }
  } catch (e) {
    print('❌ Erro ao validar no backend: $e');
    return {
      'isValid': false,
      'error': 'Erro de conexão com backend',
    };
  }
}
}