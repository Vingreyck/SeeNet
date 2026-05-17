// lib/admin/checkmarks_admin.view.dart — REDESIGN
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../services/api_service.dart';
import 'package:seenet/widgets/app_snackbar.dart';

class CheckmarksAdminView extends StatefulWidget {
  const CheckmarksAdminView({super.key});

  @override
  State<CheckmarksAdminView> createState() => _CheckmarksAdminViewState();
}

class _CheckmarksAdminViewState extends State<CheckmarksAdminView>
    with TickerProviderStateMixin {

  final ApiService _api = ApiService.instance;

  List<CategoriaCheckmark> categorias = [];
  Map<int, List<Checkmark>> checkmarksPorCategoria = {};
  bool isLoading = true;

  TabController? _tabController;

  // ── FUNÇÕES INALTERADAS ──────────────────────────────────────

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
        final responseCheckmarks = await _api.get(
            '/checkmark/categoria/${categoria.id}');
        if (responseCheckmarks['success']) {
          final List<dynamic> checkmarksData =
          responseCheckmarks['data']['checkmarks'];
          checkmarksPorCategoria[categoria.id!] =
              checkmarksData.map((json) => Checkmark.fromMap(json)).toList();
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Erro ao recarregar checkmarks: $e');
    }
  }

  Future<void> carregarDados() async {
    try {
      setState(() => isLoading = true);
      final responseCategorias = await _api.get('/checkmark/categorias');
      if (responseCategorias['success']) {
        final List<dynamic> data =
        responseCategorias['data']['categorias'];
        final novasCategorias =
        data.map((json) => CategoriaCheckmark.fromMap(json)).toList();
        final indiceAtual = _tabController?.index ?? 0;
        final precisaRecriar = _tabController == null ||
            _tabController!.length != novasCategorias.length;
        if (precisaRecriar) {
          _tabController?.dispose();
          _tabController = TabController(
            length: novasCategorias.length,
            vsync: this,
            initialIndex:
            indiceAtual.clamp(0, novasCategorias.length - 1),
          );
        }
        categorias = novasCategorias;
        checkmarksPorCategoria.clear();
        for (var categoria in categorias) {
          final responseCheckmarks = await _api.get(
              '/checkmark/categoria/${categoria.id}');
          if (responseCheckmarks['success']) {
            final List<dynamic> checkmarksData =
            responseCheckmarks['data']['checkmarks'];
            checkmarksPorCategoria[categoria.id!] = checkmarksData
                .map((json) => Checkmark.fromMap(json))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
      if (mounted) {
        AppSnackbar.show('Erro', 'Erro ao carregar dados',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _adicionarCheckmark() {
    if (categorias.isEmpty) {
      AppSnackbar.show('Erro', 'Nenhuma categoria',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    _adicionarCheckmarkCategoria(categorias.first.id!);
  }

  void _adicionarCheckmarkCategoria(int catId) {
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    int catSel = catId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setModal) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Novo Checkmark',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  // Categoria
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: catSel,
                        dropdownColor: const Color(0xFF1A1A1A),
                        isExpanded: true,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        onChanged: (v) =>
                            setModal(() => catSel = v!),
                        items: categorias
                            .map((c) => DropdownMenuItem(
                            value: c.id, child: Text(c.nome)))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _campoTexto(tituloCtrl, 'Título *'),
                  const SizedBox(height: 10),
                  _campoTexto(descCtrl, 'Descrição', maxLines: 2),
                  const SizedBox(height: 10),
                  _campoTexto(promptCtrl, 'Prompt Gemini *',
                      maxLines: 3,
                      hint: 'Mínimo 10 caracteres'),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _salvarNovo(
                            catSel,
                            tituloCtrl.text.trim(),
                            descCtrl.text.trim(),
                            promptCtrl.text.trim());
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Criar',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _salvarNovo(
      int catId, String titulo, String desc, String prompt) async {
    if (titulo.isEmpty) {
      AppSnackbar.show('Erro', 'Título é obrigatório',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (prompt.isEmpty || prompt.length < 10) {
      AppSnackbar.show('Erro', 'Prompt deve ter no mínimo 10 caracteres',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    try {
      final res = await _api.post('/checkmark/checkmarks', {
        'categoria_id': catId,
        'titulo': titulo,
        'descricao': desc.isEmpty ? null : desc,
        'prompt_gemini': prompt,
        'ativo': true,
      });
      if (res['success']) {
        AppSnackbar.show('Sucesso', 'Criado!',
            backgroundColor: Colors.green, colorText: Colors.white);
        await recarregarCheckmarks();
      } else {
        AppSnackbar.show('Erro', res['error'] ?? 'Falha ao criar',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao criar',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _editarCheckmark(Checkmark checkmark) {
    final tituloCtrl =
    TextEditingController(text: checkmark.titulo);
    final descCtrl =
    TextEditingController(text: checkmark.descricao ?? '');
    final promptCtrl =
    TextEditingController(text: checkmark.promptGemini);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Text('Editar Checkmark',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _campoTexto(tituloCtrl, 'Título *'),
                const SizedBox(height: 10),
                _campoTexto(descCtrl, 'Descrição', maxLines: 2),
                const SizedBox(height: 10),
                _campoTexto(promptCtrl, 'Prompt Gemini *',
                    maxLines: 4),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _salvarEdicaoCheckmark(
                          checkmark.id!,
                          tituloCtrl.text.trim(),
                          descCtrl.text.trim(),
                          promptCtrl.text.trim());
                      if (mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Salvar',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _salvarEdicaoCheckmark(
      int id, String titulo, String desc, String prompt) async {
    if (titulo.isEmpty || prompt.isEmpty) {
      AppSnackbar.show('Erro', 'Título e Prompt obrigatórios',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    try {
      final res = await _api.put('/checkmark/checkmarks/$id', {
        'titulo': titulo,
        'descricao': desc.isEmpty ? null : desc,
        'prompt_gemini': prompt,
      });
      if (res['success']) {
        AppSnackbar.show('Sucesso', 'Atualizado!',
            backgroundColor: Colors.green, colorText: Colors.white);
        await recarregarCheckmarks();
      } else {
        AppSnackbar.show('Erro', res['error'] ?? 'Falha',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao atualizar',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _removerCheckmark(Checkmark checkmark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover Checkmark',
            style: TextStyle(color: Colors.white)),
        content: Text('Remover "${checkmark.titulo}"?\n⚠️ Ação irreversível!',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmarRemocao(checkmark.id!);
            },
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarRemocao(int id) async {
    try {
      final res = await _api.delete('/checkmark/checkmarks/$id');
      if (res['success']) {
        AppSnackbar.show('Sucesso', 'Removido!',
            backgroundColor: Colors.green, colorText: Colors.white);
        await recarregarCheckmarks();
      }
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha ao remover',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _mostrarDetalhesCheckmark(Checkmark checkmark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(checkmark.titulo,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (checkmark.descricao != null) ...[
              Text(checkmark.descricao!,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            const Text('Prompt Gemini',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(checkmark.promptGemini,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _editarCategoria(CategoriaCheckmark categoria) {
    final nomeCtrl = TextEditingController(text: categoria.nome);
    final descCtrl =
    TextEditingController(text: categoria.descricao ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Editar Categoria',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _campoTexto(nomeCtrl, 'Nome *'),
              const SizedBox(height: 10),
              _campoTexto(descCtrl, 'Descrição', maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _salvarEdicaoCategoria(
                        categoria.id!,
                        nomeCtrl.text.trim(),
                        descCtrl.text.trim());
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Salvar',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _salvarEdicaoCategoria(
      int id, String nome, String desc) async {
    if (nome.isEmpty) {
      AppSnackbar.show('Erro', 'Nome obrigatório',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    try {
      final res = await _api.put('/checkmark/categorias/$id',
          {'nome': nome, 'descricao': desc.isEmpty ? null : desc});
      if (res['success']) {
        AppSnackbar.show('Sucesso', 'Categoria atualizada!',
            backgroundColor: Colors.green, colorText: Colors.white);
        await recarregarCheckmarks();
      }
    } catch (e) {
      AppSnackbar.show('Erro', 'Falha',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 0,
              left: 8,
              right: 16,
            ),
            color: const Color(0xFF111111),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF00FF88)
                                .withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.checklist_rounded,
                          color: Color(0xFF00FF88), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Checkmarks',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700)),
                          Text('Problemas por categoria',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white38, size: 20),
                      onPressed: carregarDados,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded,
                          color: Color(0xFF00FF88), size: 22),
                      onPressed: _adicionarCheckmark,
                    ),
                  ],
                ),

                // ── Tabs por categoria ───────────────────────
                if (!isLoading &&
                    categorias.isNotEmpty &&
                    _tabController != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicator: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.white38,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      unselectedLabelStyle:
                      const TextStyle(fontSize: 12),
                      dividerColor: Colors.transparent,
                      tabs: categorias
                          .map((c) => Tab(text: c.nome))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),

          // ── Conteúdo ─────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00FF88), strokeWidth: 2.5))
                : categorias.isEmpty
                ? _buildVazioCategoria()
                : _tabController == null
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00FF88)))
                : TabBarView(
              controller: _tabController,
              children: categorias.map((cat) {
                final checks =
                    checkmarksPorCategoria[cat.id!] ?? [];
                return _buildCategoriaTab(cat, checks);
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarCheckmark,
        backgroundColor: const Color(0xFF00FF88),
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('Novo Checkmark',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCategoriaTab(
      CategoriaCheckmark categoria, List<Checkmark> checks) {
    return Column(
      children: [
        // Header da aba
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF00FF88).withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${checks.length} checks',
                    style: const TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              if (categoria.descricao != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(categoria.descricao!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ] else
                const Spacer(),
              GestureDetector(
                onTap: () => _editarCategoria(categoria),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.blue, size: 14),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: checks.isEmpty
              ? _buildVazioChecks(categoria.id!)
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: checks.length,
            itemBuilder: (context, index) =>
                _buildCheckmarkCard(checks[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckmarkCard(Checkmark checkmark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Número
          Container(
            width: 36,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12)),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          // Conteúdo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(checkmark.titulo,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (checkmark.descricao != null) ...[
                    const SizedBox(height: 3),
                    Text(checkmark.descricao!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          // Ações
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _mostrarDetalhesCheckmark(checkmark),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_outline_rounded,
                      color: Colors.white38, size: 15),
                ),
              ),
              GestureDetector(
                onTap: () => _editarCheckmark(checkmark),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.blue, size: 15),
                ),
              ),
              GestureDetector(
                onTap: () => _removerCheckmark(checkmark),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVazioChecks(int catId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_outlined,
              size: 52, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 12),
          const Text('Nenhum checkmark nesta categoria',
              style: TextStyle(color: Colors.white38, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _adicionarCheckmarkCategoria(catId),
            icon: const Icon(Icons.add_rounded, color: Colors.black),
            label: const Text('Adicionar Checkmark',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVazioCategoria() {
    return const Center(
      child: Text('Nenhuma categoria encontrada',
          style: TextStyle(color: Colors.white38, fontSize: 15)),
    );
  }

  Widget _campoTexto(TextEditingController ctrl, String label,
      {int maxLines = 1, String? hint}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF00FF88), width: 1.5)),
      ),
    );
  }
}