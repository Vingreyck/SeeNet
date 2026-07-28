// lib/services/auth_service.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'notification_service.dart'; // ✅ NOVO
import 'dart:convert';
import '../controllers/usuario_controller.dart';
import '../models/usuario.dart';
import '../login/loginview.controller.dart';
import 'package:seenet/widgets/app_snackbar.dart';

/// Resultado da checagem do código da empresa. Precisa distinguir "código
/// ERRADO" de "não consegui checar (rede)": tratar os dois como inválido fazia
/// o técnico ver "empresa não encontrada" quando na verdade era só o sinal
/// ruim — e o botão de entrar ficava travado sem explicação.
enum ResultadoEmpresa { valida, naoEncontrada, erroRede }

class VerificacaoEmpresa {
  final ResultadoEmpresa resultado;
  final Map<String, dynamic>? empresa;

  const VerificacaoEmpresa(this.resultado, [this.empresa]);

  bool get ok => resultado == ResultadoEmpresa.valida;
}

class AuthService extends GetxService {
  ApiService get _api => Get.find<ApiService>();
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

      // Envia como 'login' genérico: o backend decide se é TELEFONE (números) ou NOME.
      final response = await _api.post('/auth/login', {
        'login': nome,
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
        String telefone = '',
        String cpf = '',
        int idAlmoxarifado = 0,
        String almoxarifadoNome = '',
      }) async {
    try {
      _usuarioController.isLoading.value = true;

      final response = await _api.post('/auth/register', {
        'nome': nome,
        if (cpf.isNotEmpty) 'cpf': cpf,
        if (telefone.isNotEmpty) 'telefone': telefone,
        if (senha.isNotEmpty) 'senha': senha,
        'codigoEmpresa': codigoEmpresa.toUpperCase(),
        if (idAlmoxarifado != 0) 'id_almoxarifado': idAlmoxarifado,
        if (almoxarifadoNome.isNotEmpty) 'almoxarifado_nome': almoxarifadoNome,
      }, requireAuth: false);

      if (response['success']) {
        return true;
      } else {
        AppSnackbar.show('Erro no Registro', response['error'] ?? 'Falha no registro',
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      AppSnackbar.show('Erro de Conexão', 'Não foi possível conectar ao servidor.',
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      _usuarioController.isLoading.value = false;
    }
  }

  /// Checa o código da empresa. Distingue "não existe" de "não deu pra checar"
  /// (ver [ResultadoEmpresa]). Tenta 2x: numa rede de celular instável, uma
  /// falha isolada é comum e não deve virar "empresa inválida" na cara do
  /// técnico. Trocado GetConnect → http (mesmo cliente do resto do app, com
  /// timeout previsível).
  Future<VerificacaoEmpresa> verificarCodigoEmpresa(String codigo) async {
    final url = Uri.parse(
      'https://seenet-production.up.railway.app/api/tenant/verify/$codigo',
    );

    for (int tentativa = 1; tentativa <= 2; tentativa++) {
      try {
        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final body = json.decode(response.body);
          if (body['success'] == true) {
            return VerificacaoEmpresa(
              ResultadoEmpresa.valida,
              (body['data']?['empresa'] as Map?)?.cast<String, dynamic>(),
            );
          }
        }
        // 404 (e qualquer 4xx) = o servidor RESPONDEU dizendo que não existe.
        // Resposta definitiva: não adianta tentar de novo.
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return const VerificacaoEmpresa(ResultadoEmpresa.naoEncontrada);
        }
        // 5xx cai no retry abaixo (problema do servidor, não do código).
      } catch (e) {
        print('💥 [AUTH] falha ao checar empresa (tentativa $tentativa): $e');
      }

      if (tentativa == 1) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    return const VerificacaoEmpresa(ResultadoEmpresa.erroRede);
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

      print('🔄 Auto-login: token local válido, entrando...');
      _api.setAuth(savedToken, savedTenantCode);

      // ✅ Token local válido → LOGA JÁ, sem esperar a rede (funciona até offline).
      // Assim o técnico NÃO cai mais no login toda vez por causa de internet ruim
      // ou de uma verificação que demora/falha.
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

      // Enviar FCM token
      _enviarFcmToken();

      // Confere o token no servidor EM BACKGROUND. Só encerra a sessão se o
      // servidor REJEITAR de verdade (401). Falha de rede NÃO desloga.
      _verificarTokenEmBackground();

      print('✅ Auto-login bem-sucedido: ${userData['nome']}');
      return true;
    } catch (e) {
      print('❌ Erro no auto-login: $e');
      await _clearPersistedSession();
      _api.clearAuth();
      return false;
    }
  }

  /// Confere o token no servidor SEM bloquear o auto-login. Só encerra a sessão
  /// se o servidor responder 401 (token realmente rejeitado/expirado no servidor).
  /// Falha de rede é ignorada (mantém a sessão — o token local já é válido).
  void _verificarTokenEmBackground() {
    _api.get('/auth/verify', timeout: const Duration(seconds: 8)).then((verif) {
      if (verif is Map && verif['success'] != true && verif['statusCode'] == 401) {
        print('⚠️ Token rejeitado pelo servidor (401) — encerrando sessão');
        _clearPersistedSession();
        _api.clearAuth();
        _usuarioController.usuarioLogado.value = null;
        Get.offAllNamed('/login');
      }
    }).catchError((e) {
      print('📶 Verify em background falhou (rede) — sessão mantida: $e');
    });
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