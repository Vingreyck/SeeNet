// lib/services/auth_service.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'api_service.dart';
import 'notification_service.dart'; // ✅ NOVO
import 'dart:convert';
import '../controllers/usuario_controller.dart';
import '../models/usuario.dart';
import '../login/loginview.controller.dart';

class AuthService extends GetxService {
  final ApiService _api = ApiService.instance;
  final _storage = GetStorage();

  static const _keyToken = 'auth_token';
  static const _keyTenantCode = 'tenant_code';
  static const _keyUserData = 'user_data';

  UsuarioController get _usuarioController => Get.find<UsuarioController>();

  // ========== LOGIN ==========
  Future<bool> login(String nome, String senha, String codigoEmpresa) async {
    try {
      _usuarioController.isLoading.value = true;
      clearSession();

      final response = await _api.post('/auth/login', {
        'nome': nome,
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
          email: userData['email'] ?? '',
          senha: '',
          tipoUsuario: userData['tipo_usuario'],
          ativo: true,
          dataCriacao: DateTime.now(),
        );

        _usuarioController.usuarioLogado.value = usuario;

        await _saveSession(token, userData['tenant']['codigo'], {
          'id': userData['id'],
          'nome': userData['nome'],
          'email': userData['email'] ?? '',
          'tipo_usuario': userData['tipo_usuario'],
        });

        // ✅ NOVO: Enviar FCM token pro backend após login
        _enviarFcmToken();

        print('✅ Login bem-sucedido: ${userData['nome']}');
        return true;
      } else {
        String errorType = response['type']?.toString() ?? '';
        String errorText = response['error']?.toString().toLowerCase() ?? '';
        int statusCode = response['statusCode'] ?? 0;

        try {
          final loginController = Get.find<LoginController>();

          if (statusCode == 401) {
            if (errorType == 'INVALID_PASSWORD' || errorText.contains('senha')) {
              loginController.senhaError.value = 'Senha incorreta';
            } else if (errorType == 'USER_NOT_FOUND' ||
                errorText.contains('usuário') ||
                errorText.contains('usuario') ||
                errorText.contains('nome')) {
              loginController.emailError.value = 'Usuário não encontrado';
            } else {
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
      try {
        final loginController = Get.find<LoginController>();
        loginController.emailError.value = 'Erro de conexão';
      } catch (_) {}
      return false;
    } finally {
      _usuarioController.isLoading.value = false;
    }
  }

  // ========== REGISTRO ==========
  // ========== REGISTRO ==========
  Future<bool> register(
      String nome,
      String senha,
      String codigoEmpresa, {
        int idAlmoxarifado = 0,
        String almoxarifadoNome = '',
      }) async {
    try {
      _usuarioController.isLoading.value = true;

      final response = await _api.post('/auth/register', {
        'nome': nome,
        'senha': senha,
        'codigoEmpresa': codigoEmpresa.toUpperCase(),
        if (idAlmoxarifado != 0) 'id_almoxarifado': idAlmoxarifado,
        if (almoxarifadoNome.isNotEmpty) 'almoxarifado_nome': almoxarifadoNome,
      }, requireAuth: false);

      if (response['success']) {
        return true;
      } else {
        Get.snackbar('Erro no Registro', response['error'] ?? 'Falha no registro',
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      Get.snackbar('Erro de Conexão', 'Não foi possível conectar ao servidor.',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      _usuarioController.isLoading.value = false;
    }
  }

  Future<Map<String, dynamic>?> verificarCodigoEmpresa(String codigo) async {
    try {
      final url = 'https://seenet-production.up.railway.app/api/tenant/verify/$codigo';
      final connect = GetConnect();
      connect.timeout = const Duration(seconds: 15);
      final response = await connect.get(url);
      if (response.statusCode == 200 && response.body?['success'] == true) {
        return response.body['data']['empresa'];
      }
      return null;
    } catch (e) {
      print('💥 [AUTH] EXCEÇÃO: $e');
      return null;
    }
  }

  // ========== AUTO-LOGIN ==========
  Future<bool> tryAutoLogin() async {
    try {
      final savedToken = _storage.read<String>(_keyToken);
      final savedTenantCode = _storage.read<String>(_keyTenantCode);
      final savedUserData = _storage.read(_keyUserData);

      if (savedToken == null || savedTenantCode == null || savedUserData == null) {
        print('ℹ️ Nenhuma sessão salva encontrada');
        return false;
      }

      // ✅ Verificar se o token JWT ainda é válido localmente (sem rede)
      try {
        final jwt = savedToken.split('.');
        if (jwt.length == 3) {
          final payload = String.fromCharCodes(
              base64Url.decode(base64Url.normalize(jwt[1]))
          );
          final data = jsonDecode(payload);
          final exp = data['exp'] as int?;
          if (exp != null) {
            final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
            if (DateTime.now().isAfter(expiry)) {
              print('⚠️ Token JWT expirado localmente — indo para login');
              await _clearPersistedSession();
              return false;
            }
          }
        }
      } catch (_) {
        // se falhar a verificação local, continua para verificação remota
      }

      print('🔄 Tentando auto-login...');
      _api.setAuth(savedToken, savedTenantCode);

      final isValid = await verifyToken();
      if (!isValid) {
        print('⚠️ Token expirado ou inválido');
        await _clearPersistedSession();
        _api.clearAuth();
        return false;
      }

      final userData = Map<String, dynamic>.from(savedUserData);
      _usuarioController.usuarioLogado.value = Usuario(
        id: userData['id'],
        nome: userData['nome'],
        email: userData['email'] ?? '',
        senha: '',
        tipoUsuario: userData['tipo_usuario'],
        ativo: true,
        dataCriacao: DateTime.now(),
      );

      // ✅ NOVO: Enviar FCM token após auto-login também
      _enviarFcmToken();

      print('✅ Auto-login bem-sucedido: ${userData['nome']}');
      return true;
    } catch (e) {
      print('❌ Erro no auto-login: $e');
      await _clearPersistedSession();
      _api.clearAuth();
      return false;
    }
  }

  // ========== LOGOUT ==========
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', {});
    } catch (e) {
      print('⚠️ Erro no logout: $e');
    } finally {
      await _clearPersistedSession();
      _clearSession();
      Get.offAllNamed('/login');
    }
  }

  // ========== HELPERS ==========

  /// ✅ NOVO: Envia FCM token pro backend (sem bloquear o fluxo)
  void _enviarFcmToken() {
    Future.delayed(const Duration(seconds: 1), () {
      try {
        final notifService = Get.find<NotificationService>();
        notifService.sendTokenToBackend();
      } catch (e) {
        print('⚠️ NotificationService não encontrado: $e');
      }
    });
  }

  Future<void> _saveSession(String token, String tenantCode, Map<String, dynamic> userData) async {
    await _storage.write(_keyToken, token);
    await _storage.write(_keyTenantCode, tenantCode);
    await _storage.write(_keyUserData, userData);
  }

  Future<void> _clearPersistedSession() async {
    await _storage.remove(_keyToken);
    await _storage.remove(_keyTenantCode);
    await _storage.remove(_keyUserData);
  }

  void clearSession() {
    _api.clearAuth();
    _usuarioController.usuarioLogado.value = null;
  }

  void _clearSession() => clearSession();

  Future<bool> verifyToken() async {
    try {
      final response = await _api.get(
        '/auth/verify',
        timeout: const Duration(seconds: 5),
      );
      return response['success'] == true;
    } catch (e) {
      print('⚠️ verifyToken falhou: $e');
      return false;
    }
  }

  bool get isLoggedIn => _usuarioController.isLoggedIn;
  Usuario? get currentUser => _usuarioController.usuarioLogado.value;
  String? get token => _api.token;
  String? get tenantCode => _api.tenantCode;
}