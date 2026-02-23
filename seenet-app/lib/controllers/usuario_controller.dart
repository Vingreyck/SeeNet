// lib/controllers/usuario_controller.dart - VERSÃO FINAL (API)
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../utils/error_handler.dart';
import '../services/auth_service.dart';

class UsuarioController extends GetxController {
  // ✅ CORREÇÃO: Usar getter lazy ao invés de inicialização direta
  AuthService get _authService => Get.find<AuthService>();
  
  Rx<Usuario?> usuarioLogado = Rx<Usuario?>(null);
  RxBool isLoading = false.obs;
  Worker? _usuarioWorker; 

  @override
  void onInit() {
    super.onInit();
    _setupWorkers();
    print('📱 UsuarioController inicializado (modo API)');
  }

  void _setupWorkers() {
  // Worker: Monitorar mudanças no usuário logado
  _usuarioWorker = ever(usuarioLogado, (usuario) {
    if (usuario != null) {
      print('👤 Usuário logado: ${usuario.nome} (${usuario.email})');
      print('🔑 Tipo: ${usuario.tipoUsuario}');
    } else {
      print('👤 Usuário deslogado');
    }
  });
}

// ========== LOGIN VIA API ==========
Future<bool> login(String email, String senha, String codigoEmpresa) async {
  try {
    isLoading.value = true;
    
    // Validações básicas
    if (email.trim().isEmpty || senha.isEmpty || codigoEmpresa.trim().isEmpty) {
      ErrorHandler.handleValidationError('Preencha todos os campos');
      return false;
    }
    
    // 🔥 CORREÇÃO: Chamar clearSession() ao invés de logout()
    _authService.clearSession();
    
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
    ErrorHandler.handle(e, context: 'login');
    return false;
  } finally {
    isLoading.value = false;
  }
}

  // ========== REGISTRO VIA API ==========
  Future<bool> registrar(String nome, String senha, String codigoEmpresa) async {
    try {
      isLoading.value = true;

      if (nome.trim().length < 2) {
        ErrorHandler.handleValidationError('Nome muito curto');
        return false;
      }

      if (senha.length < 6) {
        ErrorHandler.handleValidationError('Senha muito curta (mínimo 6 caracteres)');
        return false;
      }

      bool sucesso = await _authService.register(nome, senha, codigoEmpresa);

      if (sucesso) {
        print('✅ Registro bem-sucedido via API');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Erro no registro: $e');
      ErrorHandler.handle(e, context: 'registrar');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

// 2. registrarComAutoLogin() — remover parâmetro email
  Future<bool> registrarComAutoLogin(
      String nome,
      String senha,
      String codigoEmpresa,
      ) async {
    try {
      isLoading.value = true;

      bool registroSucesso = await _authService.register(nome, senha, codigoEmpresa);

      if (!registroSucesso) {
        print('❌ Falha no registro');
        return false;
      }

      print('✅ Registro bem-sucedido, iniciando auto-login...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Login agora usa nome em vez de email
      bool loginSucesso = await login(nome, senha, codigoEmpresa);

      if (loginSucesso) {
        print('✅ Auto-login bem-sucedido');
        return true;
      } else {
        print('❌ Auto-login falhou');
        ErrorHandler.showSuccess('Sua conta foi criada. Por favor, faça login.');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Erro em registrarComAutoLogin: $e');
      ErrorHandler.handle(e, context: 'registrarComAutoLogin');
      return false;
    } finally {
      isLoading.value = false;
    }
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
      
      ErrorHandler.showSuccess('Perfil atualizado com sucesso');
      
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
  @override
void onClose() {
  // ✅ LIMPAR WORKERS
  _usuarioWorker?.dispose();
  super.onClose();
}
}