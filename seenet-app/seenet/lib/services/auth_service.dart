import 'package:get/get.dart';
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
      
      final response = await _api.post('login', {
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
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        
        return true;
      } else {
        print('❌ Login falhou: ${response['error']}');
        Get.snackbar(
          'Erro', 
          response['error'] ?? 'Falha no login',
          snackPosition: SnackPosition.BOTTOM,
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
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
      return false;
    } finally {
      _usuarioController.isLoading.value = false;
    }
  }
  
  // Registro
  Future<bool> register(String nome, String email, String senha, String codigoEmpresa) async {
    try {
      _usuarioController.isLoading.value = true;
      
      final response = await _api.post('register', {
        'nome': nome,
        'email': email,
        'senha': senha,
        'codigoEmpresa': codigoEmpresa.toUpperCase(),
      }, requireAuth: false);
      
      if (response['success']) {
        print('✅ Registro bem-sucedido');
        Get.snackbar(
          'Sucesso', 
          'Usuário criado com sucesso! Faça login para continuar.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
        );
        return true;
      } else {
        print('❌ Registro falhou: ${response['error']}');
        Get.snackbar(
          'Erro', 
          response['error'] ?? 'Falha no registro',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
        );
        return false;
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      Get.snackbar(
        'Erro', 
        'Erro de conexão com o servidor',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
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
      await _api.post('logout', {});
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
      final response = await _api.get('verify');
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