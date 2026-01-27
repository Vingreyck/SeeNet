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
            _buildBotaoFoto('📡 Roteador', Icons.router, 'roteador'),
            _buildBotaoFoto('🏠 Local', Icons.location_on, 'local'),
            _buildBotaoFoto('📦 ONU', Icons.device_hub, 'onu'),
            _buildBotaoFoto('📷 Antes', Icons.photo_camera, 'antes'),
            _buildBotaoFoto('✅ Depois', Icons.check_circle, 'depois'),
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
              fontWeight: FontWeight.bold,
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
      onPressed: () => _mostrarOpcoesCaptura(tipo),
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
        border: Border.all(color: const Color(0xFF00FF88)),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconeTipo(anexo.tipo),
                      color: const Color(0xFF00FF88),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getLabelTipo(anexo.tipo),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
              height: 200,
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
            controller: TextEditingController(text: anexo.descricao),
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Descrição da foto (opcional)',
              hintText: _getPlaceholderDescricao(anexo.tipo),
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
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
                borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NOVA FUNÇÃO: Mostrar opções de captura
  Future<void> _mostrarOpcoesCaptura(String tipo) async {
    final opcao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Como adicionar ${_getLabelTipo(tipo)}?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF00FF88)),
              ),
              title: const Text(
                'Tirar Foto',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Usar câmera do celular',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFF00FF88)),
              ),
              title: const Text(
                'Escolher da Galeria',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Selecionar foto existente',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, 'galeria'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );

    if (opcao == null) return;

    if (opcao == 'camera') {
      await _capturarFoto(ImageSource.camera, tipo);
    } else if (opcao == 'galeria') {
      await _capturarFoto(ImageSource.gallery, tipo);
    }
  }

  // ✅ FUNÇÃO UNIFICADA: Capturar foto (câmera ou galeria)
  Future<void> _capturarFoto(ImageSource source, String tipo) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (foto != null) {
        // Gerar descrição sugerida automaticamente
        final descricaoSugerida = _getDescricaoSugerida(tipo);

        setState(() {
          _anexos.add(AnexoComDescricao(
            foto: foto,
            tipo: tipo,
            descricao: descricaoSugerida,
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
            content: Text('Erro ao capturar foto: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto removida'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
    }
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
      case 'roteador': return '📡 Roteador';
      case 'local': return '🏠 Local';
      case 'onu': return '📦 ONU';
      case 'antes': return '📷 Antes';
      case 'depois': return '✅ Depois';
      default: return 'Foto';
    }
  }

  // ✅ NOVA FUNÇÃO: Descrição sugerida automaticamente
  String _getDescricaoSugerida(String tipo) {
    switch (tipo) {
      case 'roteador':
        return 'Roteador instalado e funcionando';
      case 'local':
        return 'Local do atendimento';
      case 'onu':
        return 'ONU conectada e operacional';
      case 'antes':
        return 'Situação antes do atendimento';
      case 'depois':
        return 'Situação após o atendimento';
      default:
        return '';
    }
  }

  // ✅ NOVA FUNÇÃO: Placeholder para o campo de descrição
  String _getPlaceholderDescricao(String tipo) {
    switch (tipo) {
      case 'roteador':
        return 'Ex: Roteador na parede da sala, cabo organizado';
      case 'local':
        return 'Ex: Cômodo onde foi feito o atendimento';
      case 'onu':
        return 'Ex: ONU com LED verde aceso, sinal OK';
      case 'antes':
        return 'Ex: Cabo solto, equipamento desligado';
      case 'depois':
        return 'Ex: Tudo organizado e funcionando';
      default:
        return 'Descreva o que aparece na foto...';
    }
  }
}