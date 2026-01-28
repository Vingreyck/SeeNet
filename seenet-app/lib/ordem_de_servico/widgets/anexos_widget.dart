import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AnexoComDescricao {
  final XFile foto;
  String descricao;
  final String tipo; // sempre 'foto'

  AnexoComDescricao({
    required this.foto,
    this.descricao = '',
    this.tipo = 'foto',
  });
}

class AnexosWidget extends StatefulWidget {
  final Function(List<AnexoComDescricao>) onAnexosAlterados;

  const AnexosWidget({
    Key? key,
    required this.onAnexosAlterados,
  }) : super(key: key);

  @override
  State<AnexosWidget> createState() => _AnexosWidgetState();
}

class _AnexosWidgetState extends State<AnexosWidget> {
  final List<AnexoComDescricao> _anexos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botão principal para adicionar foto
        ElevatedButton.icon(
          onPressed: _mostrarOpcoesCaptura,
          icon: const Icon(Icons.add_a_photo, size: 24),
          label: Text(
            _anexos.isEmpty ? 'Adicionar Primeira Foto' : 'Adicionar Mais Fotos',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF88),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size(double.infinity, 56),
          ),
        ),

        const SizedBox(height: 16),

        // Contador de fotos
        if (_anexos.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00FF88)),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_library, color: Color(0xFF00FF88), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_anexos.length} foto(s) anexada(s)',
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        if (_anexos.isNotEmpty) const SizedBox(height: 16),

        // Lista de fotos
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _anexos.length,
          itemBuilder: (context, index) {
            return _buildFotoCard(_anexos[index], index);
          },
        ),
      ],
    );
  }

  Widget _buildFotoCard(AnexoComDescricao anexo, int index) {
    final descricaoController = TextEditingController(text: anexo.descricao);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF88)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF232323),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo_camera,
                        color: Color(0xFF00FF88),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Foto ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmarRemocao(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Preview da foto
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(anexo.foto.path),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Campo de descrição OBRIGATÓRIO
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Descrição',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Text(
                        'OBRIGATÓRIO',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descricaoController,
                  onChanged: (value) {
                    anexo.descricao = value;
                    widget.onAnexosAlterados(_anexos);
                  },
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex: Roteador instalado na parede da sala\nCabo organizado e equipamento funcionando',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF232323),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: anexo.descricao.trim().isEmpty
                            ? Colors.red
                            : Colors.white12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: anexo.descricao.trim().isEmpty
                            ? Colors.red
                            : Colors.white12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF00FF88),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                if (anexo.descricao.trim().isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '⚠️ A descrição é obrigatória',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarOpcoesCaptura() async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Adicionar Foto',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Como você deseja adicionar a foto?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildOpcaoCaptura(
              Icons.camera_alt,
              'Tirar Foto',
              'Usar câmera do celular',
              'camera',
            ),
            const SizedBox(height: 12),
            _buildOpcaoCaptura(
              Icons.photo_library,
              'Escolher da Galeria',
              'Selecionar foto existente',
              'galeria',
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
        ],
      ),
    );

    if (opcao == 'camera') {
      await _capturarFoto(ImageSource.camera);
    } else if (opcao == 'galeria') {
      await _capturarFoto(ImageSource.gallery);
    }
  }

  Widget _buildOpcaoCaptura(IconData icon, String titulo, String subtitulo, String valor) {
    return InkWell(
      onTap: () => Navigator.pop(context, valor),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00FF88)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00FF88), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturarFoto(ImageSource source) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (foto != null) {
        setState(() {
          _anexos.add(AnexoComDescricao(foto: foto));
        });
        widget.onAnexosAlterados(_anexos);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📸 Foto adicionada! Não esqueça de adicionar a descrição.'),
              backgroundColor: Color(0xFF00FF88),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao capturar foto: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _confirmarRemocao(int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remover Foto?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Tem certeza que deseja remover esta foto?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() {
        _anexos.removeAt(index);
      });
      widget.onAnexosAlterados(_anexos);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Foto removida'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }
}