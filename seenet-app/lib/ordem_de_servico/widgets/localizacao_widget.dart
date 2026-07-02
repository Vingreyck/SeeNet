import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocalizacaoWidget extends StatefulWidget {
  final Function(double lat, double lng) onLocalizacaoCapturada;
  final double? latitudeInicial;
  final double? longitudeInicial;

  const LocalizacaoWidget({
    super.key,
    required this.onLocalizacaoCapturada,
    this.latitudeInicial,
    this.longitudeInicial,
  });

  @override
  State<LocalizacaoWidget> createState() => _LocalizacaoWidgetState();
}

class _LocalizacaoWidgetState extends State<LocalizacaoWidget> {
  double? latitude;
  double? longitude;
  bool carregando = false;
  String? erro;
  Timer? _timerAtualizacao; // ✅ atualização automática enquanto a tela está aberta

  @override
  void initState() {
    super.initState();
    if (widget.latitudeInicial != null && widget.longitudeInicial != null) {
      latitude = widget.latitudeInicial;
      longitude = widget.longitudeInicial;
    }
    // ✅ Se a permissão JÁ está liberada, captura sozinho e segue atualizando
    // (não precisa clicar em "Capturar" toda vez que abre a tela).
    _autoIniciarSeLiberado();
  }

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    super.dispose();
  }

  // Liga a captura + atualização automática SE a permissão já foi concedida antes
  // (usa checkPermission, que NÃO abre o prompt — só verifica).
  Future<void> _autoIniciarSeLiberado() async {
    try {
      final permission = await Geolocator.checkPermission();
      final liberada = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (liberada && await Geolocator.isLocationServiceEnabled()) {
        await _atualizarPosicaoSilenciosa(); // primeira captura na hora
        _iniciarAtualizacaoAutomatica();     // e segue atualizando
      }
    } catch (_) {}
  }

  void _iniciarAtualizacaoAutomatica() {
    _timerAtualizacao?.cancel();
    _timerAtualizacao = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _atualizarPosicaoSilenciosa(),
    );
  }

  // Atualiza a posição SEM mostrar "carregando" (fluido; erro de fundo é ignorado).
  Future<void> _atualizarPosicaoSilenciosa() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          latitude = position.latitude;
          longitude = position.longitude;
          erro = null;
        });
        widget.onLocalizacaoCapturada(position.latitude, position.longitude);
      }
    } catch (_) {}
  }

  Future<void> _capturarLocalizacao() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      // 1. Verificar permissão (via geolocator — usa a chave do Info.plist e
      //    mostra o prompt NATIVO do iOS; não depende de macro do Podfile, que
      //    é o que faltava e por isso o iPhone não mostrava a opção de localização).
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          erro = 'Permissão negada. Habilite nas configurações.';
          carregando = false;
        });
        await Geolocator.openAppSettings();
        return;
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        setState(() {
          erro = 'Permissão de localização necessária.';
          carregando = false;
        });
        return;
      }

      // 2. Verificar se GPS está ativado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          erro = 'GPS desativado. Por favor, ative o GPS.';
          carregando = false;
        });
        return;
      }

      // 3. Capturar posição
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        carregando = false;
      });

      widget.onLocalizacaoCapturada(position.latitude, position.longitude);
      _iniciarAtualizacaoAutomatica(); // ✅ liberou → segue atualizando sozinha

      print('📍 Localização capturada: $latitude, $longitude');
      print('📍 Precisão: ${position.accuracy}m');
    } catch (e) {
      setState(() {
        erro = 'Erro ao capturar localização: $e';
        carregando = false;
      });
      print('❌ Erro ao capturar localização: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ✅ BOTÃO DE CAPTURAR
        ElevatedButton.icon(
          onPressed: carregando ? null : _capturarLocalizacao,
          icon: carregando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : Icon(
                  latitude != null ? Icons.refresh : Icons.my_location,
                  color: Colors.black,
                ),
          label: Text(
            latitude != null ? 'Atualizar Localização' : 'Capturar Localização',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF88),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ✅ MOSTRAR COORDENADAS SE CAPTURADAS
        if (latitude != null && longitude != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00FF88).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00FF88),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Localização Capturada',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCoordRow('Latitude', latitude!.toStringAsFixed(6)),
                const SizedBox(height: 8),
                _buildCoordRow('Longitude', longitude!.toStringAsFixed(6)),
                const SizedBox(height: 12),
                // ✅ LINK GOOGLE MAPS
                GestureDetector(
                  onTap: () {
                    // Abrir no Google Maps (você pode implementar isso)
                    print('Abrir Google Maps: $latitude, $longitude');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.map,
                        color: Color(0xFF00FF88),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ver no Google Maps',
                        style: TextStyle(
                          color: const Color(0xFF00FF88),
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ✅ MOSTRAR ERRO SE HOUVER
        if (erro != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    erro!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCoordRow(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}