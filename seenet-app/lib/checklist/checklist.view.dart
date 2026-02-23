import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seenet/checklist/widgets/checklist_categoria_card.widget.dart';
import 'package:get/get.dart';
import '../controllers/usuario_controller.dart';
import 'package:seenet/services/auth_service.dart';
import '../controllers/checkmark_controller.dart';
import '../widgets/skeleton_loader.dart';

class Checklistview extends StatefulWidget {
  const Checklistview({super.key});

  @override
  State<Checklistview> createState() => _ChecklistviewState();
}

class _ChecklistviewState extends State<Checklistview> {
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final CheckmarkController checkmarkController = Get.find<CheckmarkController>();
  final AuthService authService = Get.find<AuthService>();

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
    print('🔑 Token disponível: ${authService.token != null}');
    if (authService.token != null) {
      print('🔑 Token: ${authService.token!.substring(0, 20)}...');
    }
  }
  

  Future<void> _carregarCategorias() async {
    await checkmarkController.carregarCategorias();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    // ✅ REMOVER AppBar
    backgroundColor: const Color(0xFF1A1A1A),
    body: Stack(
      children: [
        // ✅ HEADER VERDE - VAI ATÉ O TOPO
// ✅ HEADER VERDE - RESPONSIVO
Positioned(
  top: 0,
  left: 0,
  right: 0,
  height: MediaQuery.of(context).padding.top + 100, // ✅ Altura dinâmica
  child: Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 10, // ✅ Pequeno espaço após status bar
      bottom: 15,
      left: 24,
      right: 24,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.32, 1.0],
        colors: [
          Color.fromARGB(255, 0, 232, 124),
          Color.fromARGB(255, 0, 176, 91),
        ],
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center, // ✅ Centralizado verticalmente
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center, // ✅ Centralizado
          children: [
            SvgPicture.asset(
              'assets/images/logo.svg',
              width: 48,
              height: 48,
            ),
            const SizedBox(width: 3),
            const Text(
              'SeeNet',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _mostrarMenuUsuario(context, usuarioController),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: usuarioController.isAdmin
                  ? Border.all(color: Colors.orange, width: 2)
                  : null,
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: usuarioController.isAdmin
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
              child: Icon(
                usuarioController.isAdmin
                    ? Icons.admin_panel_settings
                    : Icons.person_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),

        // ✅ TÍTULO
        Positioned(
          top: 220,
          left: 24,
          right: 24,
          child: ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              colors: [Color(0xFF00FF88), Color(0xFFFFFFFF)],
            ).createShader(
              Rect.fromLTWH(0.0, 0.0, bounds.width, bounds.height),
            ),
            child: const Text(
              'Checklist Técnico',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ),

        // ✅ SUBTÍTULO
        const Positioned(
          top: 260,
          left: 24,
          right: 24,
          child: Text(
            'Selecione a categoria para diagnóstico',
            style: TextStyle(
              color: Color(0XFF888888),
              fontSize: 16,
            ),
          ),
        ),

        // ✅ LISTA DE CATEGORIAS
        Positioned(
          top: 310,
          left: 0,
          right: 0,
          bottom: 0,
          child: Obx(() {
            if (checkmarkController.isLoading.value) {
              return const CategoriasSkeleton(itemCount: 4);
            }

            if (checkmarkController.categorias.isEmpty) {
              return _buildEmptyStateNoCategorias();
            }

            // ✅ Categorias da API
            return RefreshIndicator(
              onRefresh: _carregarCategorias,
              color: const Color(0xFF00FF88),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    ...checkmarkController.categorias.map((categoria) {
                      String icone = _getIconeParaCategoria(categoria.nome);
                      return ChecklistCategoriaCardWidget(
                        title: categoria.nome,
                        description: categoria.descricao ?? 'Categoria de diagnóstico',
                        assetIcon: icone,
                        onTap: () async {
                          if (categoria.id != null) {
                            print('🎯 Categoria selecionada: ${categoria.nome} (ID: ${categoria.id})');

                            checkmarkController.categoriaAtual.value = categoria.id!;
                            await checkmarkController.carregarCheckmarks(categoria.id!);

                            final nomeLower = categoria.nome.toLowerCase();

                            if (nomeLower.contains('lentidão') || nomeLower.contains('lentidao')) {
                              Get.toNamed('/checklist/lentidao');
                            } else if (nomeLower.contains('iptv') || nomeLower.contains('tv')) {
                              Get.toNamed('/checklist/iptv');
                            } else if (nomeLower.contains('app') || nomeLower.contains('aplicativo')) {
                              Get.toNamed('/checklist/apps');
                            } else {
                              Get.toNamed('/checklist/lentidao');
                            }
                          }
                        },
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
}

  String _getIconeParaCategoria(String nomeCategoria) {
    final nome = nomeCategoria.toLowerCase();
    if (nome.contains('lentidão') || nome.contains('lentidao')) return 'assets/images/snail.svg';
    if (nome.contains('iptv') || nome.contains('tv')) return 'assets/images/iptv.svg';
    if (nome.contains('app') || nome.contains('aplicativo')) return 'assets/images/app.svg';
    return 'assets/images/logo.svg';
  }


  void _mostrarMenuUsuario(BuildContext context, UsuarioController usuarioController) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header do usuário
              // Substituir APENAS o Container do header dentro de _mostrarMenuUsuario
// (o Container que tem padding: EdgeInsets.all(16) com Row > CircleAvatar + Column)

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(                          // ← era Row, agora é Column
                  children: [
                    CircleAvatar(
                      radius: 38,                       // ← era 30, agora maior
                      backgroundColor: usuarioController.isAdmin
                          ? Colors.orange
                          : const Color(0xFF00FF88),
                      child: Icon(
                        usuarioController.isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        color: Colors.black,
                        size: 36,                       // ← era 30, agora maior
                      ),
                    ),
                    const SizedBox(height: 12),        // ← era SizedBox(width: 16)
                    Text(
                      usuarioController.nomeUsuario,
                      textAlign: TextAlign.center,     // ← centralizado
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,                  // ← era 18, agora maior
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Email só exibe se não for o padrão .seenet.local
                    if (!usuarioController.emailUsuario.endsWith('@seenet.local'))
                      Text(
                        usuarioController.emailUsuario,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: usuarioController.isAdmin ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        usuarioController.isAdmin ? 'ADMINISTRADOR' : 'TÉCNICO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Opções do menu - APENAS PARA ADMIN
              if (usuarioController.isAdmin) ...[
                _buildMenuOption(
                  icon: Icons.people,
                  title: 'Gerenciar Usuários',
                  subtitle: 'Ver todos os usuários cadastrados',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed('/admin/usuarios');
                  },
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildMenuOption(
                  icon: Icons.checklist,
                  title: 'Gerenciar Checkmarks',
                  subtitle: 'Editar categorias e checkmarks',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed('/admin/checkmarks');
                  },
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildMenuOption(
                  icon: Icons.category,
                  title: 'Gerenciar Categorias',
                  subtitle: 'Adicionar ou remover categorias de checklist',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed('/admin/categorias');
                  },
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                // ← LOGS APENAS PARA ADMIN
                _buildMenuOption(
                  icon: Icons.security,
                  title: 'Logs de Auditoria',
                  subtitle: 'Ver logs de segurança e atividades',
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed('/admin/logs');
                  },
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
              ],
              _buildMenuOption(
                icon: Icons.assignment,
                title: 'Ordens de Serviço',
                subtitle: 'Ver e executar suas OSs do IXC',
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed('/ordens-servico');
                },
                color: const Color(0xFF00FF88), // Verde do SeeNet
              ),
              const SizedBox(height: 12),
              // Opção de transcrição técnica (para todos os usuários)
              _buildMenuOption(
                icon: Icons.description,
                title: 'Documentar Ações',
                subtitle: 'Grave suas ações técnicas por voz',
                onTap: () {
                  Navigator.pop(context);
                  Get.toNamed('/transcricao');
                },
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              // Opção de sair (para todos os usuários)
              _buildMenuOption(
                icon: Icons.logout,
                title: 'Sair',
                subtitle: 'Fazer logout do sistema',
                onTap: () {
                  Navigator.pop(context);
                  authService.logout();
                },
                color: Colors.red,
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildEmptyStateNoCategorias() {
  return Center(
    child: Container(
      margin: const EdgeInsets.all(40),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma categoria criada',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Esta empresa ainda não possui categorias de diagnóstico.\n\n'
            'Acesse o painel administrativo para criar as primeiras categorias.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          
          // Botão para admin
          if (usuarioController.isAdmin) ...[
            ElevatedButton.icon(
              onPressed: () => Get.toNamed('/admin/categorias'),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                'Criar Primeira Categoria',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ] else ...[
            // Para técnicos não-admin
            const Text(
              'Entre em contato com um administrador.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}