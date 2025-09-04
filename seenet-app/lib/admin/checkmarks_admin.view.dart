// lib/admin/checkmarks_admin.view.dart - CÓDIGO COMPLETO
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../services/database_helper.dart';

class CheckmarksAdminView extends StatefulWidget {
  const CheckmarksAdminView({super.key});

  @override
  State<CheckmarksAdminView> createState() => _CheckmarksAdminViewState();
}

class _CheckmarksAdminViewState extends State<CheckmarksAdminView> with SingleTickerProviderStateMixin {
  List<CategoriaCheckmark> categorias = [];
  Map<int, List<Checkmark>> checkmarksPorCategoria = {};
  bool isLoading = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> carregarDados() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Carregar categorias
      categorias = await DatabaseHelper.instance.getCategorias();
      
      // Inicializar TabController após carregar categorias
      _tabController = TabController(length: categorias.length, vsync: this);

      // Carregar checkmarks para cada categoria
      checkmarksPorCategoria.clear();
      for (var categoria in categorias) {
        checkmarksPorCategoria[categoria.id!] = 
            await DatabaseHelper.instance.getCheckmarksPorCategoria(categoria.id!);
      }

      print('📊 Carregados: ${categorias.length} categorias');
    } catch (e) {
      print('❌ Erro ao carregar dados: $e');
      Get.snackbar(
        'Erro',
        'Erro ao carregar dados',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Checkmarks'),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregarDados,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _adicionarCheckmark,
          ),
        ],
        bottom: isLoading || categorias.isEmpty 
            ? null 
            : TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.black,
                isScrollable: true,
                tabs: categorias.map((categoria) => Tab(
                  text: categoria.nome,
                )).toList(),
              ),
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00FF88),
              ),
            )
          : categorias.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma categoria encontrada',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: categorias.map((categoria) {
                    final checkmarks = checkmarksPorCategoria[categoria.id!] ?? [];
                    return _buildCategoriaTab(categoria, checkmarks);
                  }).toList(),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarCheckmark,
        backgroundColor: const Color(0xFF00FF88),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildCategoriaTab(CategoriaCheckmark categoria, List<Checkmark> checkmarks) {
    return Column(
      children: [
        // Header da categoria
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2A2A2A),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoria.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (categoria.descricao != null)
                      Text(
                        categoria.descricao!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${checkmarks.length} checkmarks',
                      style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF00FF88)),
                onPressed: () => _editarCategoria(categoria),
              ),
            ],
          ),
        ),
        
        // Lista de checkmarks
        Expanded(
          child: checkmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.checklist,
                        size: 64,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhum checkmark nesta categoria',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _adicionarCheckmarkCategoria(categoria.id!),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Checkmark'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: checkmarks.length,
                  onReorder: (oldIndex, newIndex) {
                    _reordenarCheckmarks(categoria.id!, oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final checkmark = checkmarks[index];
                    return _buildCheckmarkCard(checkmark, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCheckmarkCard(Checkmark checkmark, int index) {
    return Card(
      key: ValueKey(checkmark.id),
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFF2A2A2A),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Número da ordem
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Ícone de arrastar
            const Icon(
              Icons.drag_handle,
              color: Colors.white54,
            ),
          ],
        ),
        title: Text(
          checkmark.titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: checkmark.descricao != null
            ? Text(
                checkmark.descricao!,
                style: const TextStyle(color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF3A3A3A),
          onSelected: (value) {
            switch (value) {
              case 'detalhes':
                _mostrarDetalhesCheckmark(checkmark);
                break;
              case 'editar':
                _editarCheckmark(checkmark);
                break;
              case 'ativar_desativar':
                _alternarStatusCheckmark(checkmark);
                break;
              case 'remover':
                _removerCheckmark(checkmark);
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
            PopupMenuItem(
              value: 'ativar_desativar',
              child: Row(
                children: [
                  Icon(
                    checkmark.ativo ? Icons.visibility_off : Icons.visibility,
                    color: checkmark.ativo ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    checkmark.ativo ? 'Desativar' : 'Ativar',
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
        onTap: () => _mostrarDetalhesCheckmark(checkmark),
      ),
    );
  }

  // ========== MÉTODOS DE GERENCIAMENTO ==========

  // Mostrar detalhes do checkmark
  void _mostrarDetalhesCheckmark(Checkmark checkmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Detalhes do Checkmark',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ID', checkmark.id.toString()),
              _buildDetailRow('Título', checkmark.titulo),
              if (checkmark.descricao != null)
                _buildDetailRow('Descrição', checkmark.descricao!),
              _buildDetailRow('Status', checkmark.ativo ? 'Ativo' : 'Inativo'),
              _buildDetailRow('Ordem', checkmark.ordem.toString()),
              if (checkmark.dataCriacao != null)
                _buildDetailRow('Criado em', _formatarDataCompleta(checkmark.dataCriacao!)),
              const SizedBox(height: 16),
              const Text(
                'Prompt ChatGPT:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  checkmark.promptChatgpt,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Color(0xFF00FF88)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editarCheckmark(checkmark);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Editar'),
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

  // Editar checkmark
  void _editarCheckmark(Checkmark checkmark) {
    final TextEditingController tituloController = TextEditingController(text: checkmark.titulo);
    final TextEditingController descricaoController = TextEditingController(text: checkmark.descricao ?? '');
    final TextEditingController promptController = TextEditingController(text: checkmark.promptChatgpt);
    bool ativoSelecionado = checkmark.ativo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Editar Checkmark',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo Título
                TextField(
                  controller: tituloController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Título *',
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
                
                // Campo Descrição
                TextField(
                  controller: descricaoController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
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
                
                // Campo Prompt
                TextField(
                  controller: promptController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Prompt ChatGPT *',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                    helperText: 'Instrução para o ChatGPT sobre este problema',
                    helperStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Switch Ativo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Checkmark Ativo',
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
                await _salvarEdicaoCheckmark(
                  checkmark.id!,
                  tituloController.text.trim(),
                  descricaoController.text.trim(),
                  promptController.text.trim(),
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

  // Salvar edição do checkmark
  Future<void> _salvarEdicaoCheckmark(int id, String titulo, String descricao, String prompt, bool ativo) async {
    if (titulo.isEmpty || prompt.isEmpty) {
      Get.snackbar(
        'Erro',
        'Título e Prompt são obrigatórios',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.update(
        'checkmarks',
        {
          'titulo': titulo,
          'descricao': descricao.isEmpty ? null : descricao,
          'prompt_chatgpt': prompt,
          'ativo': ativo ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      Get.snackbar(
        'Sucesso',
        'Checkmark atualizado com sucesso!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await carregarDados();
    } catch (e) {
      print('❌ Erro ao editar checkmark: $e');
      Get.snackbar(
        'Erro',
        'Erro ao atualizar checkmark',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Alternar status do checkmark
  Future<void> _alternarStatusCheckmark(Checkmark checkmark) async {
    bool novoStatus = !checkmark.ativo;
    
    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.update(
        'checkmarks',
        {'ativo': novoStatus ? 1 : 0},
        where: 'id = ?',
        whereArgs: [checkmark.id],
      );

      Get.snackbar(
        'Sucesso',
        'Checkmark ${novoStatus ? 'ativado' : 'desativado'} com sucesso!',
        backgroundColor: novoStatus ? Colors.green : Colors.orange,
        colorText: Colors.white,
      );

      await carregarDados();
    } catch (e) {
      print('❌ Erro ao alterar status: $e');
      Get.snackbar(
        'Erro',
        'Erro ao alterar status do checkmark',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Remover checkmark
  void _removerCheckmark(Checkmark checkmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Remover Checkmark',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tem certeza que deseja remover este checkmark?',
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
                    checkmark.titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (checkmark.descricao != null)
                    Text(
                      checkmark.descricao!,
                      style: const TextStyle(color: Colors.white70),
                    ),
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
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _confirmarRemocaoCheckmark(checkmark.id!);
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

  // Confirmar remoção do checkmark
  Future<void> _confirmarRemocaoCheckmark(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.delete(
        'checkmarks',
        where: 'id = ?',
        whereArgs: [id],
      );

      Get.snackbar(
        'Sucesso',
        'Checkmark removido com sucesso!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await carregarDados();
    } catch (e) {
      print('❌ Erro ao remover checkmark: $e');
      Get.snackbar(
        'Erro',
        'Erro ao remover checkmark',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Adicionar novo checkmark
  void _adicionarCheckmark() {
    int? categoriaSelecionada = categorias.isNotEmpty ? categorias.first.id : null;
    
    if (categoriaSelecionada == null) {
      Get.snackbar(
        'Erro',
        'Nenhuma categoria disponível',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    _adicionarCheckmarkCategoria(categoriaSelecionada);
  }

  void _adicionarCheckmarkCategoria(int categoriaId) {
    final TextEditingController tituloController = TextEditingController();
    final TextEditingController descricaoController = TextEditingController();
    final TextEditingController promptController = TextEditingController();
    int categoriaSelecionada = categoriaId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Novo Checkmark',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown Categoria
                DropdownButtonFormField<int>(
                  value: categoriaSelecionada,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF3A3A3A),
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                  ),
                  items: categorias.map((categoria) => DropdownMenuItem(
                    value: categoria.id,
                    child: Text(categoria.nome),
                  )).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      categoriaSelecionada = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo Título
                TextField(
                  controller: tituloController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Título *',
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
                
                // Campo Descrição
                TextField(
                  controller: descricaoController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
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
                
                // Campo Prompt
                TextField(
                  controller: promptController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Prompt ChatGPT *',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF88)),
                    ),
                    helperText: 'Instrução para o ChatGPT sobre este problema',
                    helperStyle: TextStyle(color: Colors.white54),
                  ),
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
                await _salvarNovoCheckmark(
                  categoriaSelecionada,
                  tituloController.text.trim(),
                  descricaoController.text.trim(),
                  promptController.text.trim(),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  // Salvar novo checkmark
  Future<void> _salvarNovoCheckmark(int categoriaId, String titulo, String descricao, String prompt) async {
    if (titulo.isEmpty || prompt.isEmpty) {
      Get.snackbar(
        'Erro',
        'Título e Prompt são obrigatórios',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      
      // Obter próxima ordem
      var result = await db.rawQuery(
        'SELECT MAX(ordem) as max_ordem FROM checkmarks WHERE categoria_id = ?',
        [categoriaId],
      );
      int proximaOrdem = (result.first['max_ordem'] as int? ?? 0) + 1;
      
      await db.insert('checkmarks', {
        'categoria_id': categoriaId,
        'titulo': titulo,
        'descricao': descricao.isEmpty ? null : descricao,
        'prompt_chatgpt': prompt,
        'ativo': 1,
        'ordem': proximaOrdem,
      });

      Get.snackbar(
        'Sucesso',
        'Checkmark criado com sucesso!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await carregarDados();
    } catch (e) {
      print('❌ Erro ao criar checkmark: $e');
      Get.snackbar(
        'Erro',
        'Erro ao criar checkmark',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Editar categoria
  void _editarCategoria(CategoriaCheckmark categoria) {
    final TextEditingController nomeController = TextEditingController(text: categoria.nome);
    final TextEditingController descricaoController = TextEditingController(text: categoria.descricao ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Editar Categoria',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nome da Categoria *',
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
            TextField(
              controller: descricaoController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FF88)),
                ),
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
              await _salvarEdicaoCategoria(
                categoria.id!,
                nomeController.text.trim(),
                descricaoController.text.trim(),
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
    );
  }

  // Salvar edição da categoria
  Future<void> _salvarEdicaoCategoria(int id, String nome, String descricao) async {
    if (nome.isEmpty) {
      Get.snackbar(
        'Erro',
        'Nome da categoria é obrigatório',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      
      await db.update(
        'categorias_checkmark',
        {
          'nome': nome,
          'descricao': descricao.isEmpty ? null : descricao,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      Get.snackbar(
        'Sucesso',
        'Categoria atualizada com sucesso!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      await carregarDados();
    } catch (e) {
      print('❌ Erro ao editar categoria: $e');
      Get.snackbar(
        'Erro',
        'Erro ao atualizar categoria',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Reordenar checkmarks
  void _reordenarCheckmarks(int categoriaId, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final checkmarks = checkmarksPorCategoria[categoriaId]!;
    final checkmark = checkmarks.removeAt(oldIndex);
    checkmarks.insert(newIndex, checkmark);

    // Atualizar no banco
    try {
      final db = await DatabaseHelper.instance.database;
      
      for (int i = 0; i < checkmarks.length; i++) {
        await db.update(
          'checkmarks',
          {'ordem': i + 1},
          where: 'id = ?',
          whereArgs: [checkmarks[i].id],
        );
      }

      setState(() {
        checkmarksPorCategoria[categoriaId] = checkmarks;
      });

      Get.snackbar(
        'Sucesso',
        'Ordem dos checkmarks atualizada!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
      );

    } catch (e) {
      print('❌ Erro ao reordenar: $e');
      Get.snackbar(
        'Erro',
        'Erro ao reordenar checkmarks',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      // Reverter mudança
      await carregarDados();
    }
  }

  String _formatarDataCompleta(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }
}
