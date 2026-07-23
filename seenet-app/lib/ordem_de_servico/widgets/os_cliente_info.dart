// lib/ordem_de_servico/widgets/os_cliente_info.dart
// Bloco de dados do cliente reutilizado no OS card E na etapa de Localização do
// wizard — garante que os dois mostrem EXATAMENTE os mesmos dados. Inclui copiar
// (nome/login/senha) e o botão "Limpar MAC".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ordem_servico_model.dart';
import '../../services/ordem_servico_service.dart';

class OSClienteInfo extends StatefulWidget {
  final OrdemServico os;
  final bool mostrarNome;         // mostra a linha "Cliente" (wizard sim; card não, já tem no topo)
  final bool permitirLimparMac;   // mostra o botão "Limpar MAC" (precisa de idLogin)

  const OSClienteInfo({
    super.key,
    required this.os,
    this.mostrarNome = false,
    this.permitirLimparMac = true,
  });

  @override
  State<OSClienteInfo> createState() => _OSClienteInfoState();
}

class _OSClienteInfoState extends State<OSClienteInfo> {
  static const _verde = Color(0xFF00FF88);
  bool _limpandoMac = false;

  OrdemServico get os => widget.os;

  void _copiar(String rotulo, String valor) {
    Clipboard.setData(ClipboardData(text: valor));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$rotulo copiado'),
      backgroundColor: _verde,
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _limparMac() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limpar MAC?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Isso libera o MAC gravado no login do cliente. Ele vai precisar reconectar o equipamento. Deseja continuar?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.black),
            child: const Text('Limpar MAC'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _limpandoMac = true);
    final res = await OrdemServicoService().limparMac(os.id);
    if (!mounted) return;
    setState(() => _limpandoMac = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message']?.toString() ?? ''),
      backgroundColor: res['ok'] == true ? _verde : Colors.red,
    ));
  }

  // Linha "Rótulo: valor" com botão de copiar opcional.
  Widget _linha(String rotulo, String? valor, {bool copiavel = false, IconData? icone}) {
    final v = (valor != null && valor.trim().isNotEmpty) ? valor.trim() : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null) ...[
            Icon(icone, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: icone != null ? 78 : 92,
            child: Text('$rotulo:',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          if (copiavel && v.isNotEmpty)
            GestureDetector(
              onTap: () => _copiar(rotulo, v),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy_rounded, color: Colors.white38, size: 15),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.mostrarNome)
          _linha('Cliente', os.clienteNome, copiavel: true, icone: Icons.person_outline),

        // Login + Senha (copiáveis)
        if (os.clienteLogin != null)
          _linha('Login', os.clienteLogin, copiavel: true, icone: Icons.wifi_rounded),
        if (os.senhaPppoe != null)
          _linha('Senha', os.senhaPppoe, copiavel: true, icone: Icons.key_rounded),
        if (os.plano != null)
          _linha('Plano', os.plano, icone: Icons.speed_rounded),
        if (os.caixaFtth != null)
          _linha('CTO', os.caixaFtth, icone: Icons.hub_outlined),
        if (os.portaFtth != null)
          _linha('Porta', os.portaFtth, icone: Icons.settings_input_hdmi_rounded),

        const SizedBox(height: 8),

        // Painel de endereço (todos os campos; vazio mostra vazio)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Endereço do cliente',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              _linha('Endereço', os.clienteEndereco),
              _linha('Número', os.clienteNumero),
              _linha('Bairro', os.clienteBairro),
              _linha('Cidade', os.clienteCidade),
              _linha('CEP', os.clienteCep),
              _linha('Condomínio', os.clienteCondominio),
              _linha('Apartamento', os.clienteApartamento),
              _linha('Complemento', os.clienteComplemento),
              _linha('Referência', os.clienteReferencia),
            ],
          ),
        ),

        // Botão Limpar MAC
        if (widget.permitirLimparMac && os.idLogin != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _limpandoMac ? null : _limparMac,
              icon: _limpandoMac
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                  : const Icon(Icons.wifi_off_rounded, size: 18),
              label: Text(_limpandoMac ? 'Limpando...' : 'Limpar MAC',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
