import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AnexoComDescricao {
  final XFile foto;
  String descricao;
  final String tipo; // 'roteador', 'local', 'onu', 'antes', 'depois'

  AnexoComDescricao({
    required this.foto,
    this.descricao = '',
    required this.tipo,
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
      children: [
        // Botões para adicionar fotos
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBotaoFoto('Roteador', Icons.router, 'roteador'),
            _buildBotaoFoto('Local', Icons.location_on, 'local'),
            _buildBotaoFoto('ONU', Icons.device_hub, 'onu'),
            _buildBotaoFoto('Antes', Icons.photo_camera, 'antes'),
            _buildBotaoFoto('Depois', Icons.check_circle, 'depois'),
          ],
        ),

        const SizedBox(height: 16),

        // Lista de fotos anexadas
        if (_anexos.isNotEmpty) ...[
          Text(
            '${_anexos.length} foto(s) anexada(s)',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _anexos.length,
            itemBuilder: (context, index) {
              return _buildFotoCard(_anexos[index], index);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBotaoFoto(String label, IconData icon, String tipo) {
    return ElevatedButton.icon(
      onPressed: () => _tirarFoto(tipo),
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildFotoCard(AnexoComDescricao anexo, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com tipo e botão remover
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_getIconeTipo(anexo.tipo),
                      color: const Color(0xFF00FF88),
                      size: 20
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getLabelTipo(anexo.tipo),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removerFoto(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Preview da foto
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(anexo.foto.path),
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 12),

          // Campo de descrição
          TextField(
            onChanged: (value) {
              setState(() {
                anexo.descricao = value;
              });
              widget.onAnexosAlterados(_anexos);
            },
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Descrição da foto',
              hintText: 'Descreva o que aparece na foto...',
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: const Color(0xFF232323),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF00FF88)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _tirarFoto(String tipo) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (foto != null) {
        setState(() {
          _anexos.add(AnexoComDescricao(
            foto: foto,
            tipo: tipo,
          ));
        });
        widget.onAnexosAlterados(_anexos);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Foto "${_getLabelTipo(tipo)}" adicionada'),
              backgroundColor: const Color(0xFF00FF88),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao tirar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removerFoto(int index) {
    setState(() {
      _anexos.removeAt(index);
    });
    widget.onAnexosAlterados(_anexos);
  }

  IconData _getIconeTipo(String tipo) {
    switch (tipo) {
      case 'roteador': return Icons.router;
      case 'local': return Icons.location_on;
      case 'onu': return Icons.device_hub;
      case 'antes': return Icons.photo_camera;
      case 'depois': return Icons.check_circle;
      default: return Icons.photo;
    }
  }

  String _getLabelTipo(String tipo) {
    switch (tipo) {
      case 'roteador': return 'Roteador';
      case 'local': return 'Local';
      case 'onu': return 'ONU';
      case 'antes': return 'Antes';
      case 'depois': return 'Depois';
      default: return 'Foto';
    }
  }
}