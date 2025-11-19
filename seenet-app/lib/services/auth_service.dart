import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../controllers/usuario_controller.dart';
import '../models/usuario.dart';

class AuthService extends GetxService {
  final ApiService _api = ApiService.instance;

  // Getter lazy - busca o controller apenas quando necessário
  UsuarioController get _usuarioController => Get.find<UsuarioController>();
  

Future<bool> login(String email, String senha, String codigoEmpresa) async {
  try {
    _usuarioController.isLoading.value = true;

    clearSession();
    
    print('🔐 Iniciando novo login para: $email');

    final response = await _api.post('/auth/login', {
      'email': email,
      'senha': senha,
      'codigoEmpresa': codigoEmpresa.toUpperCase(),
    }, requireAuth: false);

    // 🔥 CORREÇÃO: Acessar data primeiro
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      final token = data['token'];
      final userData = data['user'];

      _api.setAuth(token, userData['tenant']['codigo']);

      print('🔐 Token configurado no ApiService');
      print('📌 Tenant Code: ${userData['tenant']['codigo']}');
      print('🎫 Token: ${token.substring(0, 20)}...');

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

      print('✅ Login bem-sucedido: ${userData['nome']} - Empresa: ${userData['tenant']['nome']}');

      Get.snackbar(
        'Sucesso',
        'Bem-vindo, ${userData['nome']}!',
        backgroundColor: Get.theme.colorScheme.primary,
        colorText: Get.theme.colorScheme.onPrimary,
      );

      return true;
      } else {
        print('❌ Login falhou: ${response['error']}');
        print('📦 Response completo: $response');
        print('🔍 Status Code: ${response['statusCode']}');
        print('🔍 Error Type: ${response['type']}');
        
        // ✅ MENSAGENS ESPECÍFICAS
        String errorMessage;
        String errorTitle;
        IconData errorIcon;
        
        // Verificar tipo de erro retornado pelo backend
        String errorType = response['type']?.toString() ?? '';
        String errorText = response['error']?.toString() ?? '';
        
        if (response['statusCode'] == 401) {
          // Diferenciar entre senha errada e usuário errado
          if (errorType == 'INVALID_PASSWORD' || errorText.contains('Senha incorreta')) {
            errorTitle = '🔒 Senha Incorreta';
            errorMessage = 'A senha digitada está incorreta.\n\nVerifique e tente novamente.';
            errorIcon = Icons.lock_outline;
          } else if (errorType == 'USER_NOT_FOUND' || errorText.contains('Usuário não encontrado')) {
            errorTitle = '👤 Usuário Não Encontrado';
            errorMessage = 'Email não cadastrado ou código da empresa inválido.\n\nVerifique seus dados.';
            errorIcon = Icons.person_outline;
          } else {
            // Fallback genérico para 401
            errorTitle = '❌ Credenciais Inválidas';
            errorMessage = 'Email, senha ou código da empresa incorretos.\n\nVerifique seus dados.';
            errorIcon = Icons.error_outline;
          }
        } else if (errorText.contains('empresa') || errorText.contains('tenant')) {
          errorTitle = '🏢 Empresa Não Encontrada';
          errorMessage = 'Código da empresa incorreto ou inativo.\n\nVerifique o código.';
          errorIcon = Icons.business_outlined;
        } else if (errorText.contains('inativ')) {
          errorTitle = '⚠️ Conta Inativa';
          errorMessage = 'Sua conta está desativada.\n\nContacte o administrador.';
          errorIcon = Icons.person_off_outlined;
        } else {
          errorTitle = '❌ Erro no Login';
          errorMessage = errorText.isNotEmpty ? errorText : 'Não foi possível realizar o login.';
          errorIcon = Icons.error_outline;
        }
        
        Get.snackbar(
          errorTitle,
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
          borderRadius: 12,
          icon: Icon(errorIcon, color: Colors.white, size: 28),
          shouldIconPulse: true,
          isDismissible: true,
        );
        
        return false;
      }
  } catch (e) {
    print('❌ Erro no login: $e');
    Get.snackbar(
      'Erro',
      'Erro de conexão com o servidor',
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
    );
    return false;
  } finally {
    _usuarioController.isLoading.value = false;
  }
}

  // Registro com token da empresa
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
        print('✅ Registro bem-sucedido para empresa: $codigoEmpresa');

        String empresaNome = response['data']?['tenantName'] ?? codigoEmpresa;

        Get.snackbar(
          'Sucesso',
          'Conta criada com sucesso!\nEmpresa: $empresaNome\n\nFaça login para continuar.',
          backgroundColor: const Color(0xFF00FF99),
          colorText: Colors.black,
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.all(20),
          borderRadius: 12,
          icon: const Icon(Icons.check_circle, color: Colors.black),
        );
        return true;
      } else {
        print('❌ Registro falhou: ${response['error']}');

        String errorMsg = response['error'] ?? 'Falha no registro';
        if (errorMsg.contains('já está cadastrado')) {
          errorMsg = 'Este email já está cadastrado nesta empresa';
        } else if (errorMsg.contains('Limite de usuários')) {
          errorMsg = 'Limite de usuários atingido para esta empresa';
        } else if (errorMsg.contains('inválido') || errorMsg.contains('não encontrado')) {
          errorMsg = 'Token da empresa inválido ou expirado';
        }

        Get.snackbar(
          'Erro no Registro',
          errorMsg,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(20),
          borderRadius: 12,
          icon: const Icon(Icons.error, color: Colors.white),
        );
        return false;
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      Get.snackbar(
        'Erro de Conexão',
        'Não foi possível conectar ao servidor.\nVerifique sua conexão e tente novamente.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(20),
        borderRadius: 12,
        icon: const Icon(Icons.wifi_off, color: Colors.white),
      );
      return false;
    } finally {
      _usuarioController.isLoading.value = false;
    }
  }

  // Verificar código da empresa
  Future<Map<String, dynamic>?> verificarCodigoEmpresa(String codigo) async {
    try {
      final response = await _api.get('/tenant/verify/$codigo', requireAuth: false);

      if (response['success']) {
        return response['data']['empresa'];
      }
      return null;
    } catch (e) {
      print('❌ Erro ao verificar empresa: $e');
      return null;
    }
  }

// Logout completo (com navegação para tela de login)
Future<void> logout() async {
  try {
    await _api.post('/auth/logout', {});
  } catch (e) {
    print('⚠️ Erro no logout do servidor: $e');
  } finally {
    _clearSession(); // 🔥 Chama o método interno de limpeza
    
    print('👋 Logout realizado');
    Get.offAllNamed('/login');
  }
}

// Método PÚBLICO para limpar sessão (sem navegação) - usado antes de novo login
void clearSession() {
  _api.clearAuth();
  _usuarioController.usuarioLogado.value = null;
  print('🧹 Sessão limpa');
}

// Método PRIVADO mantém a mesma lógica
void _clearSession() {
  clearSession(); // Reutiliza o código
}

  // Verificar token
  Future<bool> verifyToken() async {
    try {
      final response = await _api.get('/auth/verify');
      return response['success'];
    } catch (e) {
      print('❌ Token inválido: $e');
      return false;
    }
  }

  // Verificar se está logado
  bool get isLoggedIn => _usuarioController.isLoggedIn;

  // Obter usuário atual
  Usuario? get currentUser => _usuarioController.usuarioLogado.value;
}