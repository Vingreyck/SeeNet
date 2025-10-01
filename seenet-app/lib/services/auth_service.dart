import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../controllers/usuario_controller.dart';
import '../models/usuario.dart';

class AuthService extends GetxService {
  final ApiService _api = ApiService.instance;
  late UsuarioController _usuarioController;
  
  @override
  void onInit() {
    super.onInit();
    // Buscar o controller que já existe no seu sistema
    _usuarioController = Get.find<UsuarioController>();
  }
  
  // Login com código da empresa
  Future<bool> login(String email, String senha, String codigoEmpresa) async {
    try {
      _usuarioController.isLoading.value = true;
      
      final response = await _api.post('/auth/login', {
        'email': email,
        'senha': senha,
        'codigoEmpresa': codigoEmpresa.toUpperCase(),
      }, requireAuth: false);
      
      if (response['success']) {
        final data = response['data'];
        final token = data['token'];
        final userData = data['user'];
        
        // Configurar autenticação no ApiService
        _api.setAuth(token, userData['tenant']['codigo']);
        
        // Criar objeto Usuario compatível com seu sistema
        Usuario usuario = Usuario(
          id: userData['id'],
          nome: userData['nome'],
          email: userData['email'],
          senha: '', // Não retornamos a senha do servidor
          tipoUsuario: userData['tipo_usuario'],
          ativo: true,
          dataCriacao: DateTime.now(), // Você pode ajustar isso
        );
        
        // Atualizar controller do usuário (mantém sua estrutura atual)
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
        Get.snackbar(
          'Erro', 
          response['error'] ?? 'Falha no login',
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
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
        
        // Obter nome da empresa da resposta
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
        
        // Mensagens de erro mais específicas
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
  
  // Logout
  Future<void> logout() async {
    try {
      // Tentar fazer logout no servidor
      await _api.post('/auth/logout', {});
    } catch (e) {
      print('⚠️ Erro no logout do servidor: $e');
    } finally {
      // Limpar dados locais sempre
      _api.clearAuth();
      _usuarioController.usuarioLogado.value = null;
      
      print('👋 Logout realizado');
      Get.offAllNamed('/login'); // Ajuste a rota conforme seu sistema
    }
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