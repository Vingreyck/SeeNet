import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/dds_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;

class DdsPopupAssinatura {
  static bool _aberto = false; // trava anti-duplicata (splash + binding chamam)
  static void mostrar() {
    if (_aberto) return; // já aberto → não empilha outro
    final ctrl = Get.find<DdsController>();
    if (ctrl.sessaoAtiva.value == null) return;
    _aberto = true;
    Get.dialog(
      const _DdsPopupDialog(),
      barrierDismissible: false,
      barrierColor: Colors.black87,
      useSafeArea: false,
    ).then((_) => _aberto = false);
  }
}

class _DdsPopupDialog extends StatefulWidget {
  const _DdsPopupDialog();
  @override
  State<_DdsPopupDialog> createState() => _DdsPopupDialogState();
}

class _DdsPopupDialogState extends State<_DdsPopupDialog>
    with TickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late Timer _timer;
  int _segundosRestantes = 0;
  final DdsController _ctrl = Get.find<DdsController>();

  bool _assinado = false;
  bool _enviando = false;
  String? _erro;
  String? _linkMeet; // capturado ao assinar, usado na tela de sucesso

  // Foto
  Uint8List? _fotoBytes;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -14), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14, end: 14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    final sessao = _ctrl.sessaoAtiva.value;
    _segundosRestantes = (sessao?['segundos_restantes'] as int?) ?? 900;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer t) {
    if (_segundosRestantes <= 0) {
      t.cancel();
      if (mounted && Get.isDialogOpen == true) Get.back();
      return;
    }
    setState(() => _segundosRestantes--);
  }

  void _shake() => _shakeCtrl.forward(from: 0);

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _timer.cancel();
    super.dispose();
  }

  String get _timerStr {
    final m = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_segundosRestantes > 120) return const Color(0xFF00FF88);
    if (_segundosRestantes > 30) return Colors.orange;
    return Colors.red;
  }

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 60,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() { _fotoBytes = bytes; _erro = null; });
  }

  // Botão ÚNICO: "Entrar no DDS". Entrar na reunião já É a confirmação de
  // presença — então registra a presença (assina com a foto) e, em seguida,
  // abre o Meet. Só é liberado depois que o técnico tira a selfie.
  Future<void> _entrarNoDds() async {
    if (_fotoBytes == null) {
      setState(() => _erro = 'Tire uma selfie antes de entrar');
      return;
    }
    setState(() { _enviando = true; _erro = null; });

    final fotoBase64 = 'data:image/jpeg;base64,${base64Encode(_fotoBytes!)}';
    final sessao = _ctrl.sessaoAtiva.value;
    final sessaoId = sessao?['id'] as int?;
    if (sessaoId == null) {
      setState(() => _enviando = false);
      return;
    }

    final result = await _ctrl.assinar(
      sessaoId: sessaoId,
      assinaturaBase64: fotoBase64,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      final link = (sessao?['link_meet'] as String?)?.trim();
      _linkMeet = (link != null && link.isNotEmpty) ? link : null;

      // Tenta abrir sozinho (presença já está registrada, isso é só
      // conveniência). Best-effort: se falhar por qualquer motivo, o botão
      // "Entrar no Meet" da tela de sucesso é a garantia — não trava nem
      // esconde nada.
      if (_linkMeet != null) await _abrirMeet(mostrarErro: false);

      if (!mounted) return;
      setState(() { _assinado = true; _enviando = false; });

      if (_linkMeet == null) {
        // Sem link pra abrir: fecha sozinho como sempre fez.
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted && Get.isDialogOpen == true) Get.back();
      }
      // Com link: a tela de sucesso fica aberta com o botão manual — sem
      // fechar sozinho, senão o técnico não tem tempo de tocar.
    } else {
      setState(() {
        _enviando = false;
        _erro = result['error'] ?? result['message'] ?? 'Erro ao enviar';
      });
    }
  }

  /// Abre o link do Meet. SEM o gate do `canLaunchUrl` de propósito — ele já
  /// deu falso-negativo com link válido neste app várias vezes (mesmo motivo
  /// já corrigido pro botão de ligar, o mapa e o rastreamento), e foi
  /// exatamente esse silêncio que fez o técnico "confirmar presença" sem ser
  /// levado pro Meet, sem erro nenhum aparecer.
  ///
  /// Também cobre sessão de DDS já criada ANTES da normalização do backend
  /// (pode ter sido salva sem "https://" na frente) — tenta de novo com o
  /// prefixo antes de desistir.
  Future<void> _abrirMeet({bool mostrarErro = true}) async {
    final bruto = _linkMeet;
    if (bruto == null) return;

    var uri = Uri.tryParse(bruto);
    if (uri == null || uri.scheme.isEmpty) {
      uri = Uri.tryParse('https://$bruto');
    }
    if (uri == null || uri.scheme.isEmpty) {
      if (mostrarErro) {
        Get.snackbar('Link inválido', 'O link do Meet não parece válido.',
            backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white);
      }
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mostrarErro) {
        Get.snackbar('Não abriu o Meet',
            'Tente copiar o link manualmente: $bruto',
            backgroundColor: const Color(0xFF2A2A2A), colorText: Colors.white,
            duration: const Duration(seconds: 6));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _shake,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0), child: child),
            child: GestureDetector(
              onTap: () {},
              child: _buildCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    if (_assinado) return _buildSucesso();

    final sessao = _ctrl.sessaoAtiva.value;
    final tema = sessao?['tema'] as String? ?? '';
    final temFoto = _fotoBytes != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF00FF88).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.health_and_safety,
                    color: Color(0xFF00FF88), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DDS em andamento',
                        style: TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text('Diálogo Diário de Segurança',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _timerColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _timerColor.withOpacity(0.4)),
                ),
                child: Text(_timerStr,
                    style: TextStyle(
                        color: _timerColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [ui.FontFeature.tabularFigures()])),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Tema
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tema de hoje:',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                Text(tema,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Seção de foto
          const Text('Tire uma selfie para entrar no DDS:',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),

          if (_fotoBytes == null)
            GestureDetector(
              onTap: _tirarFoto,
              child: Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white38, size: 40),
                    SizedBox(height: 8),
                    Text('Toque para tirar selfie',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_fotoBytes!,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _fotoBytes = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.refresh,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),

          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 18),

          // Botão ÚNICO: "Entrar no DDS" (entrar = confirmar presença).
          // Só é liberado depois que o técnico tira a selfie (temFoto).
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (!temFoto || _enviando) ? null : _entrarNoDds,
              icon: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2.5))
                  : const Icon(Icons.video_call,
                      color: Colors.black, size: 20),
              label: Text(
                _enviando
                    ? 'Entrando...'
                    : (temFoto
                        ? 'Entrar no DDS'
                        : 'Tire a selfie para entrar'),
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor:
                    const Color(0xFF00FF88).withOpacity(0.4),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Ao entrar no DDS sua presença é registrada automaticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSucesso() {
    final temLink = _linkMeet != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 60),
          const SizedBox(height: 16),
          const Text('Presença registrada!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            temLink
                ? 'Sua foto foi salva. Toque abaixo para entrar na reunião.'
                : 'Sua foto foi salva com sucesso.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (temLink) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _abrirMeet(mostrarErro: true),
                icon: const Icon(Icons.video_call,
                    color: Colors.black, size: 20),
                label: const Text('Entrar no Meet',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                if (mounted && Get.isDialogOpen == true) Get.back();
              },
              child: const Text('Fechar',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ],
      ),
    );
  }
}