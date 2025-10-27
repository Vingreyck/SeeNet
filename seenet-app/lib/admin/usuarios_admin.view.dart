// lib/admin/usuarios_admin.view.dart - VERSÃO 100% API
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';

class UsuariosAdminView extends StatefulWidget {
  const UsuariosAdminView({super.key});
  

  @override
  State<UsuariosAdminView> createState() => _UsuariosAdminViewState();
}

class _UsuariosAdminViewState extends State<UsuariosAdminView> {
  final ApiService _api = ApiService.instance;
  
  List<Usuario> usuarios = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    carregarUsuarios();
  }

  Future<void> carregarUsuarios() async {
    try {
      setState(() => isLoading = true);

      // ✅ Buscar usuários da API
      final response = await _api.get('adminUsers');
      
      if (response['success']) {
        List<dynamic> usuariosData = response['data']['usuarios'];
        
        usuarios = usuariosData.map((userData) => Usuario(
          id: userData['id'],
          nome: userData['nome'],
          email: userData['email'],
          senha: '', // Não vem da API
          tipoUsuario: userData['tipo_usuario'],
          ativo: userData['ativo'] == 1 || userData['ativo'] == true,
          dataCriacao: DateTime.tryParse(userData['data_criacao'] ?? '') ?? DateTime.now(),
        )).toList();
        
        print('📊 ${usuarios.length} usuários carregados da API');
      } else {
        throw Exception(response['error'] ?? 'Erro desconhecido');
      }
    } catch (e) {
      print('❌ Erro ao carregar usuários: $e');
      Get.snackbar(
        'Erro',
        'Erro ao conectar com servidor',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : usuarios.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum usuário encontrado',
                    style: TextStyle(color: Colors.white, fontSize: 18),
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
                          _buildStatCard('Total', usuarios.length.toString(), Colors.blue),
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
          style: const TextStyle(color: Colors.white70, fontSize: 12),
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
          backgroundColor: usuario.isAdmin ? Colors.orange : const Color(0xFF00FF88),
          child: Icon(
            usuario.isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: Colors.black,
          ),
        ),
        title: Text(
          usuario.nome,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usuario.email, style: const TextStyle(color: Colors.white70)),
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
        onTap: () => _mostrarDetalhesUsuario(usuario),
      ),
    );
  }

  void _mostrarDetalhesUsuario(Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Detalhes do Usuário', style: TextStyle(color: Colors.white)),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar', style: TextStyle(color: Color(0xFF00FF88))),
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
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatarDataCompleta(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  // ========== MÉTODOS COM API ==========

  void _editarUsuario(Usuario usuario) {
    final TextEditingController nomeController = TextEditingController(text: usuario.nome);
    final TextEditingController emailController = TextEditingController(text: usuario.email);
    String tipoSelecionado = usuario.tipoUsuario;
    bool ativoSelecionado = usuario.ativo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Editar Usuário', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: tipoSelecionado,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF3A3A3A),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Usuário',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'tecnico', child: Text('Técnico')),
                    DropdownMenuItem(value: 'administrador', child: Text('Administrador')),
                  ],
                  onChanged: (value) {
                    setStateDialog(() => tipoSelecionado = value!);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Usuário Ativo', style: TextStyle(color: Colors.white, fontSize: 16)),
                    Switch(
                      value: ativoSelecionado,
                      activeColor: const Color(0xFF00FF88),
                      onChanged: (value) {
                        setStateDialog(() => ativoSelecionado = value);
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
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _salvarEdicaoUsuario(
                  usuario.id!,
                  nomeController.text.trim(),
                  emailController.text.trim(),
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

Future<void> _salvarEdicaoUsuario(int id, String nome, String email, String tipo, bool ativo) async {
  try {
    Map<String, dynamic> dadosAtualizacao = {
      'nome': nome,
      'email': email.toLowerCase(),
      'tipo_usuario': tipo,
      'ativo': ativo,
    };
    
    final response = await _api.put('/auth/usuarios/$id', dadosAtualizacao);
    
    if (response['success']) {
      Get.snackbar(
        'Sucesso', 
        'Usuário atualizado com sucesso!',
        backgroundColor: Colors.green, 
        colorText: Colors.white
      );
      await carregarUsuarios();
    } else {
      throw Exception(response['error']);
    }
  } catch (e) {
    print('❌ Erro ao editar usuário: $e');
    Get.snackbar(
      'Erro', 
      'Erro ao atualizar usuário',
      backgroundColor: Colors.red, 
      colorText: Colors.white
    );
  }
}

  void _resetarSenhaUsuario(Usuario usuario) {
    final TextEditingController novaSenhaController = TextEditingController();
    final TextEditingController confirmarSenhaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text('Resetar Senha - ${usuario.nome}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Definir nova senha para:\n📧 ${usuario.email}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: novaSenhaController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova Senha',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
                prefixIcon: Icon(Icons.lock, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmarSenhaController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar Nova Senha',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
                prefixIcon: Icon(Icons.lock_outline, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (novaSenhaController.text.isEmpty) {
                Get.snackbar('Erro', 'Nova senha não pode ser vazia',
                  backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              if (novaSenhaController.text.length < 6) {
                Get.snackbar('Erro', 'Nova senha deve ter pelo menos 6 caracteres',
                  backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              if (novaSenhaController.text != confirmarSenhaController.text) {
                Get.snackbar('Erro', 'Senhas não coincidem',
                  backgroundColor: Colors.red, colorText: Colors.white);
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

  Future<void> _confirmarResetarSenha(int userId, String novaSenha) async {
    try {
        final response = await _api.put('/auth/usuarios/$userId/resetar-senha', {
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
      print('❌ Erro ao resetar senha: $e');
      Get.snackbar('Erro', 'Erro ao resetar senha',
        backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

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
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
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

  Future<void> _atualizarStatusUsuario(int id, bool ativo) async {
    try {
      final response = await _api.put('/auth/usuarios/$id/status', {
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
      print('❌ Erro ao atualizar status: $e');
      Get.snackbar('Erro', 'Erro ao atualizar status do usuário',
        backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _removerUsuario(Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Remover Usuário', style: TextStyle(color: Colors.white)),
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
                  Text('👤 ${usuario.nome}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('📧 ${usuario.email}', style: const TextStyle(color: Colors.white70)),
                  Text('👔 ${usuario.tipoUsuario}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Esta ação não pode ser desfeita!',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
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
  

  Future<void> _confirmarRemocaoUsuario(int id) async {
    try {
      final response = await _api.delete('/auth/usuarios/$id');
      
      if (response['success']) {
        Get.snackbar('Sucesso', 'Usuário removido com sucesso!',
          backgroundColor: Colors.green, colorText: Colors.white);
        await carregarUsuarios();
      } else {
        throw Exception(response['error']);
      }
    } catch (e) {
      print('❌ Erro ao remover usuário: $e');
      Get.snackbar('Erro', 'Erro ao remover usuário',
        backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}