// lib/admin/checkmarks_admin.view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../services/api_service.dart';

class CheckmarksAdminView extends StatefulWidget {
  const CheckmarksAdminView({super.key});

  @override
  State<CheckmarksAdminView> createState() => _CheckmarksAdminViewState();
}

class _CheckmarksAdminViewState extends State<CheckmarksAdminView> 
    with TickerProviderStateMixin {  // ✅ MUDOU: Removeu "Single"
  
  final ApiService _api = ApiService.instance;
  
  List<CategoriaCheckmark> categorias = [];
  Map<int, List<Checkmark>> checkmarksPorCategoria = {};
  bool isLoading = true;
  
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

Future<void> recarregarCheckmarks() async {
  try {
    checkmarksPorCategoria.clear();
    
    for (var categoria in categorias) {
      // ✅ REMOVER ?incluir_inativos=true
      final responseCheckmarks = await _api.get(
        '/checkmark/categoria/${categoria.id}'  // Sem query param
      );
      
      if (responseCheckmarks['success']) {
        final List<dynamic> checkmarksData = responseCheckmarks['data']['checkmarks'];
        checkmarksPorCategoria[categoria.id!] = 
            checkmarksData.map((json) => Checkmark.fromMap(json)).toList();
      }
    }

    if (mounted) {
      setState(() {});
    }
    
    print('♻️ Checkmarks recarregados');
  } catch (e) {
    print('❌ Erro ao recarregar checkmarks: $e');
  }
}

Future<void> carregarDados() async {
  try {
    setState(() => isLoading = true);

    final responseCategorias = await _api.get('/checkmark/categorias');
    
    if (responseCategorias['success']) {
      final List<dynamic> data = responseCategorias['data']['categorias'];
      final novasCategorias = data.map((json) => CategoriaCheckmark.fromMap(json)).toList();
      
      final indiceAtual = _tabController?.index ?? 0;
      
      final precisaRecriarTabs = _tabController == null || 
                                   _tabController!.length != novasCategorias.length;
      
      if (precisaRecriarTabs) {
        _tabController?.dispose();
        _tabController = TabController(
          length: novasCategorias.length, 
          vsync: this,
          initialIndex: indiceAtual.clamp(0, novasCategorias.length - 1),
        );
        print('🔄 TabController recriado (${novasCategorias.length} tabs)');
      }
      
      categorias = novasCategorias;

      checkmarksPorCategoria.clear();
      for (var categoria in categorias) {
        // ✅ REMOVER ?incluir_inativos=true
        final responseCheckmarks = await _api.get(
          '/checkmark/categoria/${categoria.id}'  // Sem query param
        );
        
        if (responseCheckmarks['success']) {
          final List<dynamic> checkmarksData = responseCheckmarks['data']['checkmarks'];
          checkmarksPorCategoria[categoria.id!] = 
              checkmarksData.map((json) => Checkmark.fromMap(json)).toList();
        }
      }

      print('📊 ${categorias.length} categorias carregadas');
    }
  } catch (e) {
    print('❌ Erro ao carregar dados: $e');
    if (mounted) {
      Get.snackbar('Erro', 'Erro ao carregar dados',
        backgroundColor: Colors.red, colorText: Colors.white);
    }
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: carregarDados),
          IconButton(icon: const Icon(Icons.add), onPressed: _adicionarCheckmark),
        ],
        bottom: isLoading || categorias.isEmpty || _tabController == null 
            ? null 
            : TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.black,
                isScrollable: true,
                tabs: categorias.map((c) => Tab(text: c.nome)).toList(),
              ),
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : categorias.isEmpty
              ? const Center(child: Text('Nenhuma categoria encontrada', 
                  style: TextStyle(color: Colors.white, fontSize: 18)))
              : _tabController == null
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                  : TabBarView(
                      controller: _tabController,
                      children: categorias.map((cat) {
                        final checks = checkmarksPorCategoria[cat.id!] ?? [];
                        return _buildCategoriaTab(cat, checks);
                      }).toList(),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarCheckmark,
        backgroundColor: const Color(0xFF00FF88),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // ... resto do código continua igual ...
  
  Widget _buildCategoriaTab(CategoriaCheckmark categoria, List<Checkmark> checkmarks) {
    return Column(
      children: [
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
                    Text(categoria.nome, style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    if (categoria.descricao != null)
                      Text(categoria.descricao!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('${checkmarks.length} checkmarks', style: const TextStyle(
                      color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold)),
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
        Expanded(
          child: checkmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.checklist, size: 64, color: Colors.white54),
                      const SizedBox(height: 16),
                      const Text('Nenhum checkmark nesta categoria',
                        style: TextStyle(color: Colors.white54, fontSize: 16)),
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: checkmarks.length,
                  itemBuilder: (context, index) => _buildCheckmarkCard(checkmarks[index], index),
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
      leading: Container(
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
          // ✅ REMOVER opção 'ativar_desativar'
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
            // ✅ REMOVER linha de Status
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
          SizedBox(width: 80, child: Text('$label:', 
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

void _editarCheckmark(Checkmark checkmark) {
  final tituloCtrl = TextEditingController(text: checkmark.titulo);
  final descCtrl = TextEditingController(text: checkmark.descricao ?? '');
  final promptCtrl = TextEditingController(text: checkmark.promptChatgpt);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text('Editar Checkmark', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloCtrl, 
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Título *',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl, 
              style: const TextStyle(color: Colors.white), 
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptCtrl, 
              style: const TextStyle(color: Colors.white), 
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Prompt ChatGPT *',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
                helperText: 'Este prompt será usado para gerar o diagnóstico com IA',
                helperStyle: TextStyle(color: Colors.white38, fontSize: 11),
              ),
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
            await _salvarEdicaoCheckmark(
              checkmark.id!, 
              tituloCtrl.text.trim(),
              descCtrl.text.trim(), 
              promptCtrl.text.trim(),
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

Future<void> _salvarEdicaoCheckmark(int id, String titulo, String desc, String prompt) async {
  if (titulo.isEmpty || prompt.isEmpty) {
    Get.snackbar('Erro', 'Título e Prompt obrigatórios', 
      backgroundColor: Colors.red, colorText: Colors.white);
    return;
  }
  
  try {
    final res = await _api.put('/checkmark/checkmarks/$id', {
      'titulo': titulo, 
      'descricao': desc.isEmpty ? null : desc,
      'prompt_chatgpt': prompt,
      // ✅ Não enviar mais 'ativo'
    });
    
    if (res['success']) {
      Get.snackbar('Sucesso', 'Atualizado!', 
        backgroundColor: Colors.green, colorText: Colors.white);
      await recarregarCheckmarks();
    } else {
      Get.snackbar('Erro', res['error'] ?? 'Falha ao atualizar',
        backgroundColor: Colors.red, colorText: Colors.white);
    }
  } catch (e) {
    Get.snackbar('Erro', 'Falha ao atualizar', 
      backgroundColor: Colors.red, colorText: Colors.white);
  }
}

  void _removerCheckmark(Checkmark checkmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Remover Checkmark', style: TextStyle(color: Colors.white)),
        content: Text('Remover "${checkmark.titulo}"?\n⚠️ Ação irreversível!',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await _confirmarRemocao(checkmark.id!);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

Future<void> _confirmarRemocao(int id) async {
  try {
    final res = await _api.delete('/checkmark/checkmarks/$id');  // ✅ CORRIGIDO: plural
    if (res['success']) {
      Get.snackbar('Sucesso', 'Removido!', backgroundColor: Colors.green, colorText: Colors.white);
        await recarregarCheckmarks();  // ✅ MUDOU: usa recarregarCheckmarks
    }
  } catch (e) {
    Get.snackbar('Erro', 'Falha ao remover', backgroundColor: Colors.red, colorText: Colors.white);
  }
}

  void _adicionarCheckmark() {
    if (categorias.isEmpty) {
      Get.snackbar('Erro', 'Nenhuma categoria', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    _adicionarCheckmarkCategoria(categorias.first.id!);
  }

  void _adicionarCheckmarkCategoria(int catId) {
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    int catSel = catId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Novo Checkmark', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: catSel, style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF3A3A3A),
                  decoration: const InputDecoration(labelText: 'Categoria',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88)))),
                  items: categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome))).toList(),
                  onChanged: (v) => setState(() => catSel = v!),
                ),
                const SizedBox(height: 16),
                TextField(controller: tituloCtrl, style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Título *',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))))),
                const SizedBox(height: 16),
                TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descrição',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))))),
                const SizedBox(height: 16),
                TextField(controller: promptCtrl, style: const TextStyle(color: Colors.white), maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Prompt ChatGPT *',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () async {
                await _salvarNovo(catSel, tituloCtrl.text.trim(), descCtrl.text.trim(), promptCtrl.text.trim());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

Future<void> _salvarNovo(int catId, String titulo, String desc, String prompt) async {
  if (titulo.isEmpty || prompt.isEmpty) {
    Get.snackbar('Erro', 'Título e Prompt obrigatórios', 
      backgroundColor: Colors.red, colorText: Colors.white);
    return;
  }
  
  try {
    // ✅ ADICIONAR LOGS PARA DEBUG
    final payload = {
      'categoria_id': catId, 
      'titulo': titulo,
      'descricao': desc.isEmpty ? null : desc,
      'prompt_chatgpt': prompt, 
      'ativo': true,
    };
    
    print('📤 Enviando para criar checkmark:');
    print('   URL: /checkmark/checkmarks');
    print('   Payload: $payload');
    
    final res = await _api.post('/checkmark/checkmarks', payload);
    
    print('📥 Resposta recebida:');
    print('   Success: ${res['success']}');
    print('   Response completa: $res');
    
    if (res['success']) {
      Get.snackbar('Sucesso', 'Criado!', 
        backgroundColor: Colors.green, colorText: Colors.white);
        await recarregarCheckmarks();  // ✅ MUDOU: usa recarregarCheckmarks
    } else {
      print('❌ Erro do servidor: ${res['error']}');
      Get.snackbar('Erro', res['error'] ?? 'Falha ao criar',
        backgroundColor: Colors.red, colorText: Colors.white);
    }
  } catch (e) {
    print('❌ Exceção ao criar: $e');
    Get.snackbar('Erro', 'Falha ao criar', 
      backgroundColor: Colors.red, colorText: Colors.white);
  }
}

  void _editarCategoria(CategoriaCheckmark categoria) {
    final nomeCtrl = TextEditingController(text: categoria.nome);
    final descCtrl = TextEditingController(text: categoria.descricao ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Editar Categoria', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nome *',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))))),
            const SizedBox(height: 16),
            TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descrição',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              await _salvarEdicaoCategoria(categoria.id!, nomeCtrl.text.trim(), descCtrl.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }


  Future<void> _salvarEdicaoCategoria(int id, String nome, String desc) async {
    if (nome.isEmpty) {
      Get.snackbar('Erro', 'Nome obrigatório', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    try {
      final res = await _api.put('/checkmark/categorias/$id', {
        'nome': nome, 'descricao': desc.isEmpty ? null : desc,
      });
      if (res['success']) {
        Get.snackbar('Sucesso', 'Categoria atualizada!', backgroundColor: Colors.green, colorText: Colors.white);
        await recarregarCheckmarks();  // ✅ MUDOU: usa recarregarCheckmarks
      }
    } catch (e) {
      Get.snackbar('Erro', 'Falha', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
