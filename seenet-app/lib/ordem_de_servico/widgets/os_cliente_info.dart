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
  final bool permitirEditarEndereco; // técnico corrige o endereço em campo (só no wizard)

  const OSClienteInfo({
    super.key,
    required this.os,
    this.mostrarNome = false,
    this.permitirLimparMac = true,
    this.permitirEditarEndereco = false,
  });

  @override
  State<OSClienteInfo> createState() => _OSClienteInfoState();
}

class _OSClienteInfoState extends State<OSClienteInfo> {
  static const _verde = Color(0xFF00FF88);
  bool _limpandoMac = false;
  bool _salvandoEndereco = false;

  // Correções feitas aqui na tela. O objeto OrdemServico é imutável, então em
  // vez de recarregar a OS inteira só pra mostrar o novo texto, guardamos o
  // valor corrigido e ele tem prioridade na exibição.
  final Map<String, String> _corrigidos = {};

  OrdemServico get os => widget.os;

  String? _campo(String chave, String? original) =>
      _corrigidos.containsKey(chave) ? _corrigidos[chave] : original;

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

  // 🏠 Corrigir o endereço em campo. Salva no SeeNet E no cadastro do login no
  // IXC — então a próxima OS deste cliente já vem certa.
  Future<void> _editarEndereco() async {
    // Trava anti-duplo-clique: no teste de 31/jul a correção chegou DUAS vezes
    // no backend (2 mensagens de auditoria com 1s de diferença).
    if (_salvandoEndereco) return;

    final ctrls = <String, TextEditingController>{
      'endereco':    TextEditingController(text: _campo('endereco', os.clienteEndereco) ?? ''),
      'numero':      TextEditingController(text: _campo('numero', os.clienteNumero) ?? ''),
      'bairro':      TextEditingController(text: _campo('bairro', os.clienteBairro) ?? ''),
      'cep':         TextEditingController(text: _campo('cep', os.clienteCep) ?? ''),
      'complemento': TextEditingController(text: _campo('complemento', os.clienteComplemento) ?? ''),
      'referencia':  TextEditingController(text: _campo('referencia', os.clienteReferencia) ?? ''),
    };
    const rotulos = {
      'endereco': 'Endereço (rua)', 'numero': 'Número', 'bairro': 'Bairro',
      'cep': 'CEP', 'complemento': 'Complemento', 'referencia': 'Ponto de referência',
    };

    Widget campo(String chave) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: ctrls[chave],
            style: const TextStyle(color: Colors.white, fontSize: 14),
            keyboardType: (chave == 'numero' || chave == 'cep')
                ? TextInputType.number : TextInputType.text,
            maxLines: chave == 'referencia' ? 2 : 1,
            decoration: InputDecoration(
              labelText: rotulos[chave],
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF111111),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        );

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Corrigir endereço',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Corrija o que estiver errado. Isso também atualiza o cadastro do '
                'cliente no IXC, então as próximas OS já vêm certas.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ...ctrls.keys.map(campo),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              // canPop evita que o 2º toque feche a TELA que está atrás.
              if (Navigator.canPop(ctx)) Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _verde, foregroundColor: Colors.black),
            child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (salvar != true) {
      for (final c in ctrls.values) { c.dispose(); }
      return;
    }

    // Manda só o que realmente mudou.
    final atuais = {
      'endereco':    _campo('endereco', os.clienteEndereco) ?? '',
      'numero':      _campo('numero', os.clienteNumero) ?? '',
      'bairro':      _campo('bairro', os.clienteBairro) ?? '',
      'cep':         _campo('cep', os.clienteCep) ?? '',
      'complemento': _campo('complemento', os.clienteComplemento) ?? '',
      'referencia':  _campo('referencia', os.clienteReferencia) ?? '',
    };
    final mudou = <String, String>{};
    ctrls.forEach((chave, ctrl) {
      final novo = ctrl.text.trim();
      if (novo != atuais[chave]) mudou[chave] = novo;
    });
    for (final c in ctrls.values) { c.dispose(); }

    if (mudou.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nada foi alterado'), backgroundColor: Colors.white24));
      return;
    }

    setState(() => _salvandoEndereco = true);
    final res = await OrdemServicoService().atualizarEndereco(os.id, mudou);
    if (!mounted) return;
    setState(() => _salvandoEndereco = false);
    if (res['ok'] == true) setState(() => _corrigidos.addAll(mudou));
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

  // Status de conexão (Online/Offline) — FOTO de quando a OS foi sincronizada
  // com o IXC, não é ao vivo (pode estar desatualizado se a OS estiver aberta
  // há um tempo). Por isso o texto avisa "na sincronização".
  Widget _linhaStatusConexao() {
    final online = os.statusConexaoOnline!;
    final cor = online ? _verde : Colors.red.shade300;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_rounded, color: Colors.white38, size: 14),
          const SizedBox(width: 6),
          const SizedBox(
            width: 78,
            child: Text('Conexão:',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Container(width: 7, height: 7,
              margin: const EdgeInsets.only(top: 3, right: 5),
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          Expanded(
            child: Text(
              online ? 'Online (na sincronização)' : 'Offline (na sincronização)',
              style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600),
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
        if (os.statusConexaoOnline != null) _linhaStatusConexao(),
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
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  const Text('Endereço do cliente',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Corrigir em campo: o cliente às vezes informa uma referência
                  // ou número que não bate com o que está no cadastro.
                  if (widget.permitirEditarEndereco)
                    GestureDetector(
                      onTap: _editarEndereco,
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined, color: _verde, size: 14),
                          SizedBox(width: 4),
                          Text('Corrigir',
                              style: TextStyle(color: _verde, fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _linha('Endereço', _campo('endereco', os.clienteEndereco)),
              _linha('Número', _campo('numero', os.clienteNumero)),
              _linha('Bairro', _campo('bairro', os.clienteBairro)),
              _linha('Cidade', os.clienteCidade),
              _linha('CEP', _campo('cep', os.clienteCep)),
              _linha('Condomínio', os.clienteCondominio),
              _linha('Apartamento', os.clienteApartamento),
              _linha('Complemento', _campo('complemento', os.clienteComplemento)),
              _linha('Referência', _campo('referencia', os.clienteReferencia)),
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
