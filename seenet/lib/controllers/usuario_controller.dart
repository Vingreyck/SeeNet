import 'package:get/get.dart';
import '../models/usuario.dart';
import '../services/database_helper.dart';

class UsuarioController extends GetxController {
  Rx<Usuario?> usuarioLogado = Rx<Usuario?>(null);

  // Login usando SQLite
  Future<bool> login(String email, String senha) async {
    try {
      Usuario? usuario = await DatabaseHelper.instance.loginUsuario(email, senha);
      
      if (usuario != null) {
        usuarioLogado.value = usuario;
        Get.snackbar(
          'Sucesso',
          'Bem-vindo, ${usuario.nome}!',
          snackPosition: SnackPosition.BOTTOM,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro no login: $e');
      return false;
    }
  }

  // Registrar usuário
  Future<bool> registrar(String nome, String email, String senha) async {
    try {
      Usuario novoUsuario = Usuario(
        nome: nome,
        email: email,
        senha: senha,
        tipoUsuario: 'tecnico',
      );
      
      bool sucesso = await DatabaseHelper.instance.criarUsuario(novoUsuario);
      
      if (sucesso) {
        // Fazer login automaticamente
        return await login(email, senha);
      }
      return false;
    } catch (e) {
      print('❌ Erro no registro: $e');
      return false;
    }
  }

  // Logout
  void logout() {
    usuarioLogado.value = null;
    Get.offAllNamed('/login');
  }

  // Getters
  bool get isLoggedIn => usuarioLogado.value != null;
  bool get isAdmin => usuarioLogado.value?.isAdmin ?? false;
  String get nomeUsuario => usuarioLogado.value?.nome ?? '';
}