import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seenet/checklist/widgets/checklist_categoria_card.widget.dart';
import 'package:get/get.dart';
import '../controllers/usuario_controller.dart';
import '../controllers/checkmark_controller.dart'; // ✅ ADICIONAR

class Checklistview extends StatefulWidget {
  const Checklistview({super.key});

  @override
  State<Checklistview> createState() => _ChecklistviewState();
}

class _ChecklistviewState extends State<Checklistview> {
  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final CheckmarkController checkmarkController = Get.find<CheckmarkController>(); // ✅ ADICIONAR

  @override
  void initState() {
    super.initState();
    // ✅ Carregar categorias quando a tela abrir
    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    await checkmarkController.carregarCategorias();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          // Header verde
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                      onTap: () {
                        _mostrarMenuUsuario(context, usuarioController);
                      },
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
                            size: 24
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Título
          Positioned(
            top: 180, 
            left: 24,
            right: 24,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFF00FF88),
                    Color(0xFFFFFFFF),
                  ],
                ).createShader(Rect.fromLTWH(0.0, 0.0, bounds.width, bounds.height));
              },
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
          
          // Subtítulo
          const Positioned(
            top: 220, 
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
          
          // ✅ LISTA DE CATEGORIAS DINÂMICA DA API
          Positioned(
            top: 270, 
            left: 0,
            right: 0,
            bottom: 0,
            child: Obx(() {
              // Loading
              if (checkmarkController.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00FF88),
                  ),
                );
              }

              // Erro ou vazio - mostrar categorias fixas como fallback
              if (checkmarkController.categorias.isEmpty) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // ⚠️ Categorias fixas como fallback
                      ChecklistCategoriaCardWidget(
                        title: 'Lentidão',
                        description: 'Problema de velocidade, latência alta, conexão instável',
                        assetIcon: 'assets/images/snail.svg',
                        onTap: () {
                          Get.toNamed('/checklist/lentidao');
                        },
                      ),
                      ChecklistCategoriaCardWidget(
                        title: 'IPTV',
                        description: 'Travamento, buffering, canais fora do ar, qualidade baixa',
                        assetIcon: 'assets/images/iptv.svg',
                        onTap: () {
                          Get.toNamed('/checklist/iptv');
                        },
                      ),
                      ChecklistCategoriaCardWidget(
                        title: 'Aplicativos',
                        description: 'Apps não funcionam, erro de conexão, problemas de login',
                        assetIcon: 'assets/images/app.svg',
                        onTap: () {
                          Get.toNamed('/checklist/apps');
                        },
                      ),
                      const SizedBox(height: 20),
                      // Botão de recarregar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ElevatedButton.icon(
                          onPressed: _carregarCategorias,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Recarregar Categorias'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF88),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              }

              // ✅ Categorias carregadas da API
              return RefreshIndicator(
                onRefresh: _carregarCategorias,
                color: const Color(0xFF00FF88),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Mapear categorias da API
                      ...checkmarkController.categorias.map((categoria) {
                        // Definir ícone baseado no nome (você pode melhorar isso)
                        String icone = _getIconeParaCategoria(categoria.nome);
                        
                        return ChecklistCategoriaCardWidget(
                          title: categoria.nome,
                          description: categoria.descricao ?? 'Categoria de diagnóstico',
                          assetIcon: icone,
                          onTap: () {
                            // ✅ Verificar se id não é nulo antes de usar
                            if (categoria.id != null) {
                              // Navegar para tela de checkmarks desta categoria
                              checkmarkController.carregarCheckmarks(categoria.id!);
                              
                              // TODO: Criar tela genérica de checkmarks
                              // Get.toNamed('/checklist/checkmarks', arguments: categoria.id);
                              
                              // Por enquanto, manter navegação fixa
                              if (categoria.nome.toLowerCase().contains('lentidão')) {
                                Get.toNamed('/checklist/lentidao');
                              } else if (categoria.nome.toLowerCase().contains('iptv')) {
                                Get.toNamed('/checklist/iptv');
                              } else if (categoria.nome.toLowerCase().contains('app')) {
                                Get.toNamed('/checklist/apps');
                              } else {
                                Get.snackbar(
                                  'Em desenvolvimento',
                                  'Tela de checkmarks para ${categoria.nome} em breve!',
                                  backgroundColor: Colors.orange,
                                );
                              }
                            } else {
                              Get.snackbar(
                                'Erro',
                                'Categoria inválida',
                                backgroundColor: Colors.red,
                              );
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

  // ✅ Helper para definir ícone baseado no nome da categoria
  String _getIconeParaCategoria(String nomeCategoria) {
    final nome = nomeCategoria.toLowerCase();
    
    if (nome.contains('lentidão') || nome.contains('lentidao') || nome.contains('velocidade')) {
      return 'assets/images/snail.svg';
    } else if (nome.contains('iptv') || nome.contains('tv')) {
      return 'assets/images/iptv.svg';
    } else if (nome.contains('app') || nome.contains('aplicativo')) {
      return 'assets/images/app.svg';
    } else {
      // Ícone padrão
      return 'assets/images/logo.svg';
    }
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: usuarioController.isAdmin 
                          ? Colors.orange 
                          : const Color(0xFF00FF88),
                      child: Icon(
                        usuarioController.isAdmin 
                            ? Icons.admin_panel_settings 
                            : Icons.person,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            usuarioController.nomeUsuario,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            usuarioController.emailUsuario,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: usuarioController.isAdmin ? Colors.orange : Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              usuarioController.isAdmin ? 'ADMINISTRADOR' : 'TÉCNICO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
                  usuarioController.logout();
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