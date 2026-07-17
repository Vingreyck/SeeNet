import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/ordem_servico_service.dart';

/// Foto da FACHADA (frente da casa) do cliente.
/// - Na 1ª OS do cliente, o técnico pode tirar (opcional).
/// - Nas próximas OSs do mesmo cliente, a foto aparece aqui pra ajudar a achar a casa.
/// Chave = cliente (backend resolve por cliente_id_externo). Só no SeeNet.
class FachadaFotoWidget extends StatefulWidget {
  final String osId;
  const FachadaFotoWidget({super.key, required this.osId});

  @override
  State<FachadaFotoWidget> createState() => _FachadaFotoWidgetState();
}

class _FachadaFotoWidgetState extends State<FachadaFotoWidget> {
  final OrdemServicoService _service = OrdemServicoService();
  final ImagePicker _picker = ImagePicker();

  bool _carregando = true;
  bool _enviando = false;
  Uint8List? _fotoBytes; // foto atual (do servidor ou recém-capturada)
  double? _latitude; // onde a foto foi tirada (se disponível)
  double? _longitude;

  static const _verde = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final data = await _service.buscarFachada(widget.osId);
    if (!mounted) return;
    setState(() {
      final b64 = data?['foto_base64'];
      if (b64 is String && b64.isNotEmpty) {
        try {
          _fotoBytes = base64Decode(b64);
        } catch (_) {}
      }
      final lat = data?['latitude'];
      final lng = data?['longitude'];
      _latitude = lat is num ? lat.toDouble() : null;
      _longitude = lng is num ? lng.toDouble() : null;
      _carregando = false;
    });
  }

  // Best-effort: se não tiver permissão/GPS, só não salva a coordenada
  // (não trava a foto por causa disso).
  Future<Position?> _capturarLocalizacao() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          (permission != LocationPermission.whileInUse &&
              permission != LocationPermission.always)) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  Future<void> _abrirLocalizacao() async {
    if (_latitude == null || _longitude == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível abrir o mapa'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível abrir o mapa'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _escolherOrigem() async {
    final origem = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Foto da fachada',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Tire uma foto da frente da casa para ajudar a localizar nas próximas visitas.',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            icon: const Icon(Icons.photo_library, color: Colors.white54, size: 18),
            label: const Text('Galeria', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Câmera'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _verde, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
    if (origem != null) await _capturar(origem);
  }

  Future<void> _capturar(ImageSource source) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (foto == null) return;

      final bytes = await foto.readAsBytes();
      setState(() => _enviando = true);

      final pos = await _capturarLocalizacao();

      final ok = await _service.salvarFachada(
        widget.osId,
        base64Encode(bytes),
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        if (ok) {
          _fotoBytes = bytes;
          if (pos != null) {
            _latitude = pos.latitude;
            _longitude = pos.longitude;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '📷 Foto da fachada salva!' : '❌ Falha ao salvar a foto'),
        backgroundColor: ok ? _verde : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Erro ao capturar foto: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _verFullscreen() {
    if (_fotoBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.memory(_fotoBytes!)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_outlined, color: _verde, size: 18),
              const SizedBox(width: 8),
              const Text('Foto da fachada (casa)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_enviando)
                const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _verde)),
            ],
          ),
          const SizedBox(height: 10),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                SizedBox(width: 8),
                Text('Carregando...', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            )
          else if (_fotoBytes != null) ...[
            GestureDetector(
              onTap: _verFullscreen,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _fotoBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_latitude != null && _longitude != null)
                  TextButton.icon(
                    onPressed: _abrirLocalizacao,
                    icon: const Icon(Icons.location_on, size: 16, color: _verde),
                    label: const Text('Ver localização',
                        style: TextStyle(color: _verde, fontSize: 12)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  )
                else
                  const SizedBox.shrink(),
                TextButton.icon(
                  onPressed: _enviando ? null : _escolherOrigem,
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                  label: const Text('Refazer', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
          ] else ...[
            const Text('Ainda não há foto da frente desta casa (opcional).',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _enviando ? null : _escolherOrigem,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('Tirar foto da fachada'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _verde,
                  side: const BorderSide(color: _verde),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
