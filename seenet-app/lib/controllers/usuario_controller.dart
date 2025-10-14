// lib/controllers/usuario_controller.dart - VERSÃO FINAL (API)
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/auth_service.dart';

class UsuarioController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  
  Rx<Usuario?> usuarioLogado = Rx<Usuario?>(null);
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    print('📱 UsuarioController inicializado (modo API)');
  }

  // ========== LOGIN VIA API ==========
  Future<bool> login(String email, String senha, String codigoEmpresa) async {
    try {
      isLoading.value = true;
      
      // Validações básicas
      if (email.trim().isEmpty || senha.isEmpty || codigoEmpresa.trim().isEmpty) {
        Get.snackbar(
          'Erro',
          'Preencha todos os campos',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
      
      // Login via AuthService (que usa API)
      bool sucesso = await _authService.login(email, senha, codigoEmpresa);
      
      if (sucesso) {
        // AuthService já atualizou usuarioLogado
        print('✅ Login bem-sucedido via API');
        return true;
      }
      
      
      return false;
    } catch (e) {
      print('❌ Erro no login: $e');
      Get.snackbar(
        'Erro',
        'Erro ao fazer login',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== REGISTRO VIA API ==========
  Future<bool> registrar(String nome, String email, String senha, String codigoEmpresa) async {
    try {
      isLoading.value = true;
      
      // Validações
      if (nome.trim().length < 2) {
        Get.snackbar('Erro', 'Nome muito curto');
        return false;
      }
      
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        Get.snackbar('Erro', 'Email inválido');
        return false;
      }

      if (senha.length < 6) {
        Get.snackbar('Erro', 'Senha muito curta (mínimo 6 caracteres)');
        return false;
      }

      // Registro via AuthService (que usa API)
      bool sucesso = await _authService.register(nome, email, senha, codigoEmpresa);
      
      if (sucesso) {
        print('✅ Registro bem-sucedido via API');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Erro no registro: $e');
      Get.snackbar('Erro', 'Erro ao registrar usuário');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ========== LOGOUT ==========
  Future<void> logout() async {
    await _authService.logout();
    usuarioLogado.value = null;
    print('👋 Logout realizado');
  }

  // ========== ATUALIZAR PERFIL ==========
  Future<bool> atualizarPerfil({
    String? nome,
    String? email,
    String? senha,
  }) async {
    try {
      if (usuarioLogado.value == null) return false;
      
      // Aqui você pode adicionar endpoint PUT /auth/profile na API
      // Por enquanto, atualiza localmente
      
      Usuario usuarioAtual = usuarioLogado.value!;
      Usuario usuarioAtualizado = Usuario(
        id: usuarioAtual.id,
        nome: nome ?? usuarioAtual.nome,
        email: email ?? usuarioAtual.email,
        senha: senha ?? usuarioAtual.senha,
        tipoUsuario: usuarioAtual.tipoUsuario,
        ativo: usuarioAtual.ativo,
        dataCriacao: usuarioAtual.dataCriacao,
        dataAtualizacao: DateTime.now(),
      );
      
      usuarioLogado.value = usuarioAtualizado;
      
      Get.snackbar(
        'Sucesso',
        'Perfil atualizado com sucesso',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      return true;
    } catch (e) {
      print('❌ Erro ao atualizar perfil: $e');
      return false;
    }
  }

  // ========== GETTERS ==========
  
  bool get isLoggedIn => usuarioLogado.value != null;
  
  bool get isAdmin {
    if (usuarioLogado.value == null) return false;
    
    String tipo = usuarioLogado.value!.tipoUsuario.toLowerCase().trim();
    return tipo == 'administrador' || tipo == 'admin';
  }
  
  String get nomeUsuario => usuarioLogado.value?.nome ?? '';
  String get emailUsuario => usuarioLogado.value?.email ?? '';
  int? get idUsuario => usuarioLogado.value?.id;

  bool get temPermissaoAdmin => isAdmin;

  // ========== DEBUG ==========
  
  void debugUsuario() {
    if (usuarioLogado.value != null) {
      final user = usuarioLogado.value!;
      print('👤 === USUÁRIO LOGADO (API) ===');
      print('   ID: ${user.id}');
      print('   Nome: ${user.nome}');
      print('   Email: ${user.email}');
      print('   Tipo: ${user.tipoUsuario}');
      print('   Admin: $isAdmin');
      print('   Modo: API (PostgreSQL/Railway)');
      print('================================');
    } else {
      print('❌ Nenhum usuário logado');
    }
  }
}