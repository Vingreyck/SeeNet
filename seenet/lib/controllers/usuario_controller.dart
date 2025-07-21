// lib/controllers/usuario_controller.dart - VERSÃO MELHORADA
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/database_helper.dart';
import '../services/security_service.dart';

class UsuarioController extends GetxController {
  Rx<Usuario?> usuarioLogado = Rx<Usuario?>(null);
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Verificar se existe usuário salvo (você pode implementar SharedPreferences se quiser)
    print('🎯 UsuarioController inicializado');
  }

  // Login usando SQLite
  Future<bool> login(String email, String senha) async {
  try {
    isLoading.value = true;
    
    // Validações de segurança
    if (email.trim().isEmpty) {
      Get.snackbar(
        'Erro',
        'Email não pode ser vazio',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    
    if (!SecurityService.isValidEmail(email)) {
      Get.snackbar(
        'Erro',
        'Formato de email inválido',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    
    if (senha.isEmpty) {
      Get.snackbar(
        'Erro',
        'Senha não pode ser vazia',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    
    // Validar força da senha
    String? senhaError = SecurityService.validatePassword(senha);
    if (senhaError != null) {
      Get.snackbar(
        'Erro',
        senhaError,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
    
    // Tentar fazer login
    Usuario? usuario = await DatabaseHelper.instance.loginUsuario(
      email.trim(),
      senha
    );

    if (usuario != null) {
      usuarioLogado.value = usuario;
      
      print('✅ Login realizado: ${SecurityService.maskSensitiveData(email)}');
      
      Get.snackbar(
        'Sucesso',
        'Bem-vindo, ${usuario.nome}!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return true;
    } else {
      print('❌ Login falhou para: ${SecurityService.maskSensitiveData(email)}');
      
      Get.snackbar(
        'Erro',
        'Email ou senha incorretos',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  } catch (e) {
    print('❌ Erro no login: $e');
    
    String mensagem = 'Erro ao conectar com servidor';
    if (e.toString().contains('Muitas tentativas')) {
      mensagem = e.toString();
    }
    
    Get.snackbar(
      'Erro',
      mensagem,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return false;
  } finally {
    isLoading.value = false;
  }
}

  // Registrar usuário - CORRIGIDO
  Future<bool> registrar(String nome, String email, String senha) async {
    try {
      isLoading.value = true;
      
      // Validações extras
      if (nome.trim().length < 2) {
        throw Exception('Nome muito curto');
      }
      
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        throw Exception('Email inválido');
      }
      
      if (senha.length < 6) {
        throw Exception('Senha muito curta');
      }

      // Criar usuário
      Usuario novoUsuario = Usuario(
        nome: nome.trim(),
        email: email.toLowerCase().trim(),
        senha: senha,
        tipoUsuario: 'tecnico', // Padrão para novos usuários
        ativo: true,
        dataCriacao: DateTime.now(),
      );
      
      // Salvar no banco
      bool sucesso = await DatabaseHelper.instance.criarUsuario(novoUsuario);
      
      if (sucesso) {
        print('✅ Usuário registrado: ${novoUsuario.email}');
        
        // Fazer login automaticamente após registro
        bool loginSucesso = await login(email, senha);
        
        if (loginSucesso) {
          print('✅ Login automático após registro realizado');
          return true;
        } else {
          print('⚠️ Usuário criado mas login automático falhou');
          return true; // Ainda é sucesso, o usuário pode fazer login manual
        }
      } else {
        print('❌ Falha ao criar usuário no banco');
        return false;
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      
      // Mensagens de erro específicas
      String mensagem = 'Erro ao registrar usuário';
      if (e.toString().contains('UNIQUE constraint failed')) {
        mensagem = 'Este email já está em uso';
      } else if (e.toString().contains('Nome muito curto')) {
        mensagem = 'Nome deve ter pelo menos 2 caracteres';
      } else if (e.toString().contains('Email inválido')) {
        mensagem = 'Formato de email inválido';
      } else if (e.toString().contains('Senha muito curta')) {
        mensagem = 'Senha deve ter pelo menos 6 caracteres';
      }
      
      Get.snackbar(
        'Erro',
        mensagem,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Logout
  void logout() {
    usuarioLogado.value = null;
    print('👋 Logout realizado');
    Get.offAllNamed('/login');
  }

  // Atualizar dados do usuário
  Future<bool> atualizarPerfil({
    String? nome,
    String? email,
    String? senha,
  }) async {
    try {
      if (usuarioLogado.value == null) return false;
      
      // Aqui você implementaria a atualização no banco
      // Por enquanto, apenas atualizamos localmente
      
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
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      return true;
    } catch (e) {
      print('❌ Erro ao atualizar perfil: $e');
      return false;
    }
  }

  // Getters úteis
  bool get isLoggedIn => usuarioLogado.value != null;
  
  // ✅ CORRIGIDO - Verificação de admin mais robusta
  bool get isAdmin {
    if (usuarioLogado.value == null) return false;
    
    String tipo = usuarioLogado.value!.tipoUsuario.toLowerCase().trim();
    bool ehAdmin = tipo == 'administrador' || tipo == 'admin';
    
    // Debug para verificar
    print('🔍 Verificando admin:');
    print('   Email: ${usuarioLogado.value!.email}');
    print('   Tipo original: "${usuarioLogado.value!.tipoUsuario}"');
    print('   Tipo processado: "$tipo"');
    print('   É admin: $ehAdmin');
    
    return ehAdmin;
  }
  
  String get nomeUsuario => usuarioLogado.value?.nome ?? '';
  String get emailUsuario => usuarioLogado.value?.email ?? '';
  int? get idUsuario => usuarioLogado.value?.id;

  // Verificar se tem permissão admin
  bool get temPermissaoAdmin {
    return isAdmin;
  }

  // Debug - informações do usuário
  void debugUsuario() {
    if (usuarioLogado.value != null) {
      final user = usuarioLogado.value!;
      print('👤 Usuário logado:');
      print('   ID: ${user.id}');
      print('   Nome: ${user.nome}');
      print('   Email: ${user.email}');
      print('   Tipo: ${user.tipoUsuario}');
      print('   Ativo: ${user.ativo}');
      print('   Admin (getter isAdmin): $isAdmin');
      print('   Admin (método direto): ${user.tipoUsuario.toLowerCase() == 'administrador'}');
    } else {
      print('👤 Nenhum usuário logado');
    }
  }

  // ✅ NOVO - Forçar correção e relogin do admin
  Future<void> corrigirERelogarAdmin() async {
    try {
      // Corrigir no banco
      await DatabaseHelper.instance.corrigirUsuarioAdmin();
      
      // Se o usuário atual é admin, fazer relogin
      if (usuarioLogado.value != null && 
          usuarioLogado.value!.email.toLowerCase() == 'admin@seenet.com') {
        
        print('🔄 Fazendo relogin do admin...');
        
        // Fazer logout
        usuarioLogado.value = null;
        
        // Fazer login novamente para pegar dados atualizados
        bool loginSucesso = await login('admin@seenet.com', 'admin123');
        
        if (loginSucesso) {
          print('✅ Admin relogado com sucesso!');
          debugUsuario();
        }
      }
      
    } catch (e) {
      print('❌ Erro ao corrigir admin: $e');
    }
  }

  // Testar conexão com banco E corrigir admin
  Future<bool> testarBanco() async {
    try {
      bool conexaoOk = await DatabaseHelper.instance.testarConexao();
      if (conexaoOk) {
        print('✅ Conexão com SQLite OK');
        
        // Corrigir admin se necessário
        await DatabaseHelper.instance.corrigirUsuarioAdmin();
        
        await DatabaseHelper.instance.verificarEstrutura();
        await DatabaseHelper.instance.verificarTodosUsuarios();
      }
      return conexaoOk;
    } catch (e) {
      print('❌ Erro ao testar banco: $e');
      return false;
    }
  }
}