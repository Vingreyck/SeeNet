import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AnexosWidget extends StatefulWidget {
  final Function(List<String>) onFotosAlteradas;

  const AnexosWidget({
    super.key,
    required this.onFotosAlteradas,
  });

  @override
  State<AnexosWidget> createState() => _AnexosWidgetState();
}

class _AnexosWidgetState extends State<AnexosWidget> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> fotos = [];

  Future<void> _tirarFoto() async {
    // Verificar permissão da câmera
    var status = await Permission.camera.status;

    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    if (!status.isGranted) {
      _mostrarErro('Permissão de câmera necessária.');
      return;
    }

    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (foto != null) {
        setState(() {
          fotos.add(foto);
        });
        widget.onFotosAlteradas(fotos.map((f) => f.path).toList());
        print('📸 Foto capturada: ${foto.path}');
      }
    } catch (e) {
      _mostrarErro('Erro ao tirar foto: $e');
      print('❌ Erro ao tirar foto: $e');
    }
  }

  Future<void> _selecionarGaleria() async {
    // Verificar permissão de fotos
    var status = await Permission.photos.status;

    if (status.isDenied) {
      status = await Permission.photos.request();
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    if (!status.isGranted) {
      _mostrarErro('Permissão de galeria necessária.');
      return;
    }

    try {
      final List<XFile> fotosGaleria = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (fotosGaleria.isNotEmpty) {
        setState(() {
          fotos.addAll(fotosGaleria);
        });
        widget.onFotosAlteradas(fotos.map((f) => f.path).toList());
        print('📷 ${fotosGaleria.length} fotos adicionadas da galeria');
      }
    } catch (e) {
      _mostrarErro('Erro ao selecionar fotos: $e');
      print('❌ Erro ao selecionar fotos: $e');
    }
  }

  void _removerFoto(int index) {
    setState(() {
      fotos.removeAt(index);
    });
    widget.onFotosAlteradas(fotos.map((f) => f.path).toList());
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ✅ BOTÕES DE AÇÃO
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _tirarFoto,
                icon: const Icon(Icons.camera_alt, color: Colors.black),
                label: const Text(
                  'Câmera',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selecionarGaleria,
                icon: const Icon(Icons.photo_library, color: Color(0xFF00FF88)),
                label: const Text(
                  'Galeria',
                  style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF00FF88)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ✅ GRID DE FOTOS
        if (fotos.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 50,
                  color: Colors.white24,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nenhuma foto adicionada',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: fotos.length,
            itemBuilder: (context, index) {
              return _buildFotoItem(fotos[index], index);
            },
          ),

        // ✅ CONTADOR DE FOTOS
        if (fotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${fotos.length} ${fotos.length == 1 ? 'foto anexada' : 'fotos anexadas'}',
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFotoItem(XFile foto, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00FF88), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(foto.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removerFoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}