import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../controllers/usuario_controller.dart';
import '../models/usuario.dart';
import '../login/loginview.controller.dart';

class AuthService extends GetxService {
  final ApiService _api = ApiService.instance;

  UsuarioController get _usuarioController => Get.find<UsuarioController>();
  

Future<bool> login(String email, String senha, String codigoEmpresa) async {
  try {
    _usuarioController.isLoading.value = true;
    clearSession();
    
    final response = await _api.post('/auth/login', {
      'email': email,
      'senha': senha,
      'codigoEmpresa': codigoEmpresa.toUpperCase(),
    }, requireAuth: false);

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      final token = data['token'];
      final userData = data['user'];

      _api.setAuth(token, userData['tenant']['codigo']);

      Usuario usuario = Usuario(
        id: userData['id'],
        nome: userData['nome'],
        email: userData['email'],
        senha: '',
        tipoUsuario: userData['tipo_usuario'],
        ativo: true,
        dataCriacao: DateTime.now(),
      );

      _usuarioController.usuarioLogado.value = usuario;

      print('✅ Login bem-sucedido: ${userData['nome']}');

      return true;
    } else {
      // ✅ DETECTAR TIPO DE ERRO E SETAR NO CAMPO CORRETO
      String errorType = response['type']?.toString() ?? '';
      String errorText = response['error']?.toString().toLowerCase() ?? '';
      int statusCode = response['statusCode'] ?? 0;
      
      // ✅ BUSCAR LoginController PARA SETAR ERRO NO CAMPO
      try {
        final loginController = Get.find<LoginController>();
        
        if (statusCode == 401) {
          // Senha incorreta
          if (errorType == 'INVALID_PASSWORD' || errorText.contains('senha')) {
            loginController.senhaError.value = 'Senha incorreta';
          } 
          // Usuário não encontrado
          else if (errorType == 'USER_NOT_FOUND' || errorText.contains('usuário') || errorText.contains('usuario')) {
            loginController.emailError.value = 'Usuário não encontrado';
          }
          // Fallback genérico
          else {
            loginController.emailError.value = 'Credenciais inválidas';
            loginController.senhaError.value = 'Credenciais inválidas';
          }
        } else if (errorText.contains('empresa') || errorText.contains('tenant')) {
          loginController.empresaError.value = 'Empresa não encontrada';
        }
      } catch (e) {
        print('⚠️ Erro ao setar mensagem no campo: $e');
      }
      
      return false;
    }
  } catch (e) {
    print('❌ Erro no login: $e');
    
    // Setar erro genérico nos campos
    try {
      final loginController = Get.find<LoginController>();
      loginController.emailError.value = 'Erro de conexão';
    } catch (_) {}
    
    return false;
  } finally {
    _usuarioController.isLoading.value = false;
  }
}

  Future<bool> register(String nome, String email, String senha, String codigoEmpresa) async {
    try {
      _usuarioController.isLoading.value = true;

      final response = await _api.post('/auth/register', {
        'nome': nome,
        'email': email,
        'senha': senha,
        'codigoEmpresa': codigoEmpresa.toUpperCase(),
      }, requireAuth: false);

      if (response['success']) {
        String empresaNome = response['data']?['tenantName'] ?? codigoEmpresa;

        Get.snackbar(
          'Sucesso',
          'Conta criada! Faça login para continuar.',
          backgroundColor: const Color(0xFF00FF99),
          colorText: Colors.black,
          snackPosition: SnackPosition.BOTTOM,
        );
        return true;
      } else {
        Get.snackbar(
          'Erro no Registro',
          response['error'] ?? 'Falha no registro',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      Get.snackbar(
        'Erro de Conexão',
        'Não foi possível conectar ao servidor.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      _usuarioController.isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>?> verificarCodigoEmpresa(String codigo) async {
    try {
      final response = await _api.get('/tenant/verify/$codigo', requireAuth: false);

      if (response['success']) {
        return response['data']['empresa'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', {});
    } catch (e) {
      print('⚠️ Erro no logout: $e');
    } finally {
      _clearSession();
      Get.offAllNamed('/login');
    }
  }

  void clearSession() {
    _api.clearAuth();
    _usuarioController.usuarioLogado.value = null;
  }

  void _clearSession() {
    clearSession();
  }

  Future<bool> verifyToken() async {
    try {
      final response = await _api.get('/auth/verify');
      return response['success'];
    } catch (e) {
      return false;
    }
  }

  bool get isLoggedIn => _usuarioController.isLoggedIn;
  Usuario? get currentUser => _usuarioController.usuarioLogado.value;
}