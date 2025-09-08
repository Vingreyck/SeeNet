// lib/admin/usuarios_admin.view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/usuario.dart';
import '../services/database_helper.dart';
import 'package:crypto/crypto.dart';
import '../services/api_service.dart';
import 'dart:convert';

class UsuariosAdminView extends StatefulWidget {
  const UsuariosAdminView({super.key});

  @override
  State<UsuariosAdminView> createState() => _UsuariosAdminViewState();
}

class _UsuariosAdminViewState extends State<UsuariosAdminView> {
  List<Usuario> usuarios = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    carregarUsuarios();
  }

  Future<void> carregarUsuarios() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Buscar usuários da API
      final apiService = Get.find<ApiService>();
      final response = await apiService.get('/auth/debug/usuarios', requireAuth: false);
      
      if (response['success'] && response['data'] != null) {
        List<dynamic> usuariosData = response['data']['usuarios'];
        
        usuarios = usuariosData.map((userData) => Usuario(
          id: userData['id'],
          nome: userData['nome'],
          email: userData['email'],
          senha: '', // Não vem da API
          tipoUsuario: userData['tipo_usuario'],
          ativo: userData['ativo'] == 1,
          dataCriacao: DateTime.tryParse(userData['data_criacao'] ?? '') ?? DateTime.now(),
        )).toList();
        
        print('📊 ${usuarios.length} usuários carregados da API');
      } else {
        print('❌ Erro na resposta da API: ${response['error']}');
        Get.snackbar(
          'Erro',
          'Erro ao conectar com servidor: ${response['error']}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        
        // Fallback para SQLite local se API falhar
        await _carregarUsuariosLocal();
      }
    } catch (e) {
      print('❌ Erro ao carregar usuários da API: $e');
      
      // Fallback para SQLite local
      await _carregarUsuariosLocal();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Método fallback para SQLite local
  Future<void> _carregarUsuariosLocal() async {
    try {
      print('⚠️ Usando SQLite local como fallback');
      
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> results = await db.query(
        'usuarios',
        orderBy: 'data_criacao DESC',
      );

      usuarios = results.map((map) => Usuario.fromMap(map)).toList();
      print('📊 ${usuarios.length} usuários carregados do SQLite local');
    } catch (e) {
      print('❌ Erro no fallback SQLite: $e');
      Get.snackbar(
        'Erro',
        'Erro ao carregar usuários',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários Cadastrados'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregarUsuarios,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00FF88),
              ),
            )
          : usuarios.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum usuário encontrado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header com estatísticas
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFF2A2A2A),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard(
                            'Total',
                            usuarios.length.toString(),
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Técnicos',
                            usuarios.where((u) => u.tipoUsuario == 'tecnico').length.toString(),
                            Colors.green,
                          ),
                          _buildStatCard(
                            'Admins',
                            usuarios.where((u) => u.tipoUsuario == 'administrador').length.toString(),
                            Colors.orange,
                          ),
                          _buildStatCard(
                            'Ativos',
                            usuarios.where((u) => u.ativo).length.toString(),
                            const Color(0xFF00FF88),
                          ),
                        ],
                      ),
                    ),
                    // Lista de usuários
                    Expanded(
                      child: ListView.builder(
                        itemCount: usuarios.length,
                        itemBuilder: (context, index) {
                          final usuario = usuarios[index];
                          return _buildUserCard(usuario);
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: carregarUsuarios,
        backgroundColor: const Color(0xFF00FF88),
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Usuario usuario) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF2A2A2A),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: usuario.isAdmin 
              ? Colors.orange 
              : const Color(0xFF00FF88),
          child: Icon(
            usuario.isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: Colors.black,
          ),
        ),
        title: Text(
          usuario.nome,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usuario.email,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: usuario.isAdmin ? Colors.orange : Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    usuario.tipoUsuario.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: usuario.ativo ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    usuario.ativo ? 'ATIVO' : 'INATIVO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF3A3A3A),
          onSelected: (value) {
            switch (value) {
              case 'detalhes':
                _mostrarDetalhesUsuario(usuario);
                break;
              case 'editar':
                _editarUsuario(usuario);
                break;
              case 'resetar_senha':
                _resetarSenhaUsuario(usuario);
                break;
              case 'ativar_desativar':
                _alternarStatusUsuario(usuario);
                break;
              case 'remover':
                _removerUsuario(usuario);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'detalhes',
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Ver Detalhes', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Editar', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'resetar_senha',
              child: Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Resetar Senha', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'ativar_desativar',
              child: Row(
                children: [
                  Icon(
                    usuario.ativo ? Icons.block : Icons.check_circle,
                    color: usuario.ativo ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    usuario.ativo ? 'Desativar' : 'Ativar',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remover',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remover', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          _mostrarDetalhesUsuario(usuario);
        },
      ),
    );
  }

  void _mostrarDetalhesUsuario(Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Detalhes do Usuário',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('ID', usuario.id.toString()),
            _buildDetailRow('Nome', usuario.nome),
            _buildDetailRow('Email', usuario.email),
            _buildDetailRow('Tipo', usuario.tipoUsuario),
            _buildDetailRow('Status', usuario.ativo ? 'Ativo' : 'Inativo'),
            if (usuario.dataCriacao != null)
              _buildDetailRow('Criado em', _formatarDataCompleta(usuario.dataCriacao!)),
            if (usuario.dataAtualizacao != null)
              _buildDetailRow('Atualizado em', _formatarDataCompleta(usuario.dataAtualizacao!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Color(0xFF00FF88)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String _formatarDataCompleta(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  // ========== MÉTODOS DE GERENCIAMENTO DE USUÁRIOS (MIGRADOS PARA API) ==========

  // Editar usuário
  void _editarUsuario(Usuario usuario) {
    final TextEditingController nomeController = TextEditingController(text: usuario.nome);
    final TextEditingController emailController = TextEditingController(text: usuario.email);
    final TextEditingController senhaController = TextEditingController();
    String tipoSelecionado = usuario.tipoUsuario;
    bool ativoSelecionado = usuario.ativo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Editar Usuário',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo Nome
                TextField(
                  controller: nomeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Campo Email
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Campo Nova Senha
                TextField(
                  controller: senhaController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova Senha',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                    helperText: 'Deixe vazio para manter a senha atual',
                    helperStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    prefixIcon: Icon(Icons.lock, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Dropdown Tipo
                DropdownButtonFormField<String>(
                  value: tipoSelecionado,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF3A3A3A),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Usuário',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'tecnico', child: Text('Técnico')),
                    DropdownMenuItem(value: 'administrador', child: Text('Administrador')),
                  ],
                  onChanged: (value) {
                    setStateDialog(() {
                      tipoSelecionado = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Switch Ativo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Usuário Ativo',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Switch(
                      value: ativoSelecionado,
                      activeColor: const Color(0xFF00FF88),
                      onChanged: (value) {
                        setStateDialog(() {
                          ativoSelecionado = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await _salvarEdicaoUsuario(
                  usuario.id!,
                  nomeController.text.trim(),
                  emailController.text.trim(),
                  senhaController.text.trim(),
                  tipoSelecionado,
                  ativoSelecionado,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  // Salvar edição do usuário (MIGRADO PARA API)
  Future<void> _salvarEdicaoUsuario(int id, String nome, String email, String novaSenha, String tipo, bool ativo) async {
    try {
      final apiService = Get.find<ApiService>();
      
      // Preparar dados para envio
      Map<String, dynamic> dadosAtualizacao = {
        'nome': nome,
        'email': email.toLowerCase(),
        'tipo_usuario': tipo,
        'ativo': ativo,
      };

      // Se nova senha foi fornecida, incluir
      if (novaSenha.isNotEmpty) {
        dadosAtualizacao['senha'] = novaSenha;
      }
      
      // Enviar para API
      final response = await apiService.put('/auth/usuarios/$id', dadosAtualizacao);
      
      if (response['success']) {
        String mensagemSucesso = 'Usuário atualizado com sucesso!';
        if (novaSenha.isNotEmpty) {
          mensagemSucesso += '\n🔐 Senha alterada';
        }

        Get.snackbar(
          'Sucesso',
          mensagemSucesso,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        await carregarUsuarios();
      } else {
        String mensagem = response['error'] ?? 'Erro ao atualizar usuário';
        
        Get.snackbar(
          'Erro',
          mensagem,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Erro ao editar usuário via API: $e');
      
      // Fallback para SQLite se API falhar
      await _salvarEdicaoUsuarioLocal(id, nome, email, novaSenha, tipo, ativo);
    }
  }

  // Fallback para SQLite local
  Future<void> _salvarEdicaoUsuarioLocal(int id, String nome, String email, String novaSenha, String tipo, bool ativo) async {
    try {
      print('⚠️ Usando SQLite local para edição - fallback');
      
      final db = await DatabaseHelper.instance.database;
      
      Map<String, dynamic> dadosAtualizacao = {
        'nome': nome,
        'email': email.toLowerCase(),
        'tipo_usuario': tipo,
        'ativo': ativo ? 1 : 0,
        'data_atualizacao': DateTime.now().toIso8601String(),
      };

      if (novaSenha.isNotEmpty) {
        dadosAtualizacao['senha'] = _hashPassword(novaSenha);
        print('✅ Senha será atualizada para usuário ID: $id');
      }
      
      await db.update(
        'usuarios',
        dadosAtualizacao,
        where: 'id = ?',
        whereArgs: [id],
      );

      String mensagemSucesso = 'Usuário atualizado com sucesso! (Offline)';
      if (novaSenha.isNotEmpty) {
        mensagemSucesso += '\n🔐 Senha alterada';
      }

      Get.snackbar(
        'Sucesso',
        mensagemSucesso,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await carregarUsuarios();
    } catch (e) {
      print('❌ Erro no fallback SQLite para edição: $e');
      
      String mensagem = 'Erro ao atualizar usuário';
      if (e.toString().contains('UNIQUE constraint failed')) {
        mensagem = 'Este email já está em uso por outro usuário';
      }
      
      Get.snackbar(
        'Erro',
        mensagem,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Método para hash de senha
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Resetar senha do usuário
  void _resetarSenhaUsuario(Usuario usuario) {
    final TextEditingController novaSenhaController = TextEditingController();
    final TextEditingController confirmarSenhaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          'Resetar Senha - ${usuario.nome}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Definir nova senha para:\n📧 ${usuario.email}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Campo Nova Senha
            TextField(
              controller: novaSenhaController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova Senha',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FF88)),
                ),
                prefixIcon: Icon(Icons.lock, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            
            // Campo Confirmar Senha
            TextField(
              controller: confirmarSenhaController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar Nova Senha',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FF88)),
                ),
                prefixIcon: Icon(Icons.lock_outline, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (novaSenhaController.text.isEmpty) {
                Get.snackbar(
                  'Erro',
                  'Nova senha não pode ser vazia',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              if (novaSenhaController.text.length < 6) {
                Get.snackbar(
                  'Erro',
                  'Nova senha deve ter pelo menos 6 caracteres',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              if (novaSenhaController.text != confirmarSenhaController.text) {
                Get.snackbar(
                  'Erro',
                  'Senhas não coincidem',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }

              await _confirmarResetarSenha(usuario.id!, novaSenhaController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resetar Senha'),
          ),
        ],
      ),
    );
  }

  // Confirmar reset de senha (MIGRADO PARA API)
  Future<void> _confirmarResetarSenha(int userId, String novaSenha) async {
    try {
      final apiService = Get.find<ApiService>();
      
      final response = await apiService.put('/auth/usuarios/$userId/resetar-senha', {
        'nova_senha': novaSenha,
      });
      
      if (response['success']) {
        Get.snackbar(
          'Sucesso',
          '🔐 Senha resetada com sucesso!\nO usuário deve fazer login com a nova senha.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      } else {
        throw Exception(response['error']);
      }
    } catch (e) {
      print('❌ Erro ao resetar senha via API: $e');
      
      // Fallback para SQLite
      await _confirmarResetarSenhaLocal(userId, novaSenha);
    }
  }

  // Fallback para reset de senha no SQLite
  Future<void> _confirmarResetarSenhaLocal(int userId, String novaSenha) async {
    try {
      print('⚠️ Usando SQLite local para reset de senha - fallback');
      
      final db = await DatabaseHelper.instance.database;
      
      await db.update(
        'usuarios',
        {
          'senha': _hashPassword(novaSenha),
          'data_atualizacao': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      Get.snackbar(
        'Sucesso',
        '🔐 Senha resetada com sucesso! (Offline)\nO usuário deve fazer login com a nova senha.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      print('❌ Erro no fallback SQLite para reset de senha: $e');
      Get.snackbar(
        'Erro',
        'Erro ao resetar senha',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Alternar status do usuário
  Future<void> _alternarStatusUsuario(Usuario usuario) async {
    bool novoStatus = !usuario.ativo;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          '${novoStatus ? 'Ativar' : 'Desativar'} Usuário',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          novoStatus 
              ? 'Deseja ativar o usuário ${usuario.nome}?'
              : 'Deseja desativar o usuário ${usuario.nome}?\n\nUsuários desativados não conseguem fazer login.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _atualizarStatusUsuario(usuario.id!, novoStatus);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: novoStatus ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(novoStatus ? 'Ativar' : 'Desativar'),
          ),
        ],
      ),
    );
  }

  // Atualizar status do usuário (MIGRADO PARA API)
  Future<void> _atualizarStatusUsuario(int id, bool ativo) async {
    try {
      final apiService = Get.find<ApiService>();
      
      final response = await apiService.put('/auth/usuarios/$id/status', {
        'ativo': ativo,
      });
      
      if (response['success']) {
        Get.snackbar(
          'Sucesso',
          'Status do usuário ${ativo ? 'ativado' : 'desativado'} com sucesso!',
          backgroundColor: ativo ? Colors.green : Colors.orange,
          colorText: Colors.white,
        );

        await carregarUsuarios();
      } else {
        throw Exception(response['error']);
      }
    } catch (e) {
      print('❌ Erro ao atualizar status via API: $e');
      
      // Fallback para SQLite
      await _atualizarStatusUsuarioLocal(id, ativo);
    }
  }

  // Fallback para atualizar status no SQLite
  Future<void> _atualizarStatusUsuarioLocal(int id, bool ativo) async {
    try {
      print('⚠️ Usando SQLite local para atualizar status - fallback');
      
      final db = await DatabaseHelper.instance.database;
      
      await db.update(
        'usuarios',
        {
          'ativo': ativo ? 1 : 0,
          'data_atualizacao': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      Get.snackbar(
        'Sucesso',
        'Status do usuário ${ativo ? 'ativado' : 'desativado'} com sucesso! (Offline)',
        backgroundColor: ativo ? Colors.green : Colors.orange,
        colorText: Colors.white,
      );

      await carregarUsuarios();
    } catch (e) {
      print('❌ Erro no fallback SQLite para atualizar status: $e');
      Get.snackbar(
        'Erro',
        'Erro ao atualizar status do usuário',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Remover usuário
  void _removerUsuario(Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Remover Usuário',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tem certeza que deseja remover o usuário?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '👤 ${usuario.nome}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '📧 ${usuario.email}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '👔 ${usuario.tipoUsuario}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Esta ação não pode ser desfeita!\n\nTodos os dados relacionados a este usuário (avaliações, diagnósticos, etc.) serão perdidos.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _confirmarRemocaoUsuario(usuario.id!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  // Confirmar remoção do usuário (MIGRADO PARA API)
  Future<void> _confirmarRemocaoUsuario(int id) async {
    try {
      final apiService = Get.find<ApiService>();
      
      final response = await apiService.delete('/auth/usuarios/$id');
      
      if (response['success']) {
        Get.snackbar(
          'Sucesso',
          'Usuário removido com sucesso!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        await carregarUsuarios();
      } else {
        throw Exception(response['error']);
      }
    } catch (e) {
      print('❌ Erro ao remover usuário via API: $e');
      
      // Fallback para SQLite
      await _confirmarRemocaoUsuarioLocal(id);
    }
  }

  // Fallback para remoção no SQLite
  Future<void> _confirmarRemocaoUsuarioLocal(int id) async {
    try {
      print('⚠️ Usando SQLite local para remoção - fallback');
      
      final db = await DatabaseHelper.instance.database;
      
      await db.delete(
        'usuarios',
        where: 'id = ?',
        whereArgs: [id],
      );

      Get.snackbar(
        'Sucesso',
        'Usuário removido com sucesso! (Offline)',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await carregarUsuarios();
    } catch (e) {
      print('❌ Erro no fallback SQLite para remoção: $e');
      Get.snackbar(
        'Erro',
        'Erro ao remover usuário',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}