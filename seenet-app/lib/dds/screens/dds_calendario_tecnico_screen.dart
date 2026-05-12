// lib/dds/screens/dds_calendario_tecnico_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/dds_service.dart';

class DdsCalendarioTecnicoScreen extends StatefulWidget {
  final int tecnicoId;
  final String tecnicoNome;

  const DdsCalendarioTecnicoScreen({
    super.key,
    required this.tecnicoId,
    required this.tecnicoNome,
  });

  @override
  State<DdsCalendarioTecnicoScreen> createState() =>
      _DdsCalendarioTecnicoScreenState();
}

class _DdsCalendarioTecnicoScreenState
    extends State<DdsCalendarioTecnicoScreen> {
  final _service = Get.find<DdsService>();

  Map<String, dynamic> _calendario = {};
  bool _isLoading = true;
  int _anoSelecionado = DateTime.now().year;
  int _mesSelecionado = DateTime.now().month;

  // Dia selecionado
  String? _diaSelecionado;
  List<Map<String, dynamic>> _ddsNoDia = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _isLoading = true);
    final data = await _service.buscarCalendarioTecnico(
        widget.tecnicoId, ano: _anoSelecionado);
    setState(() { _calendario = data; _isLoading = false; });
  }

  // Dias assinados no mês selecionado
  Set<int> get _diasAssinadosNoMes {
    final dias = <int>{};
    for (final entry in _calendario.entries) {
      try {
        final parts = entry.key.split('-');
        final ano = int.parse(parts[0]);
        final mes = int.parse(parts[1]);
        final dia = int.parse(parts[2]);
        if (ano == _anoSelecionado && mes == _mesSelecionado) {
          dias.add(dia);
        }
      } catch (_) {}
    }
    return dias;
  }

  void _selecionarDia(int dia) {
    final key = '$_anoSelecionado-'
        '${_mesSelecionado.toString().padLeft(2,'0')}-'
        '${dia.toString().padLeft(2,'0')}';
    final lista = (_calendario[key] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    setState(() { _diaSelecionado = key; _ddsNoDia = lista; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text('DDS — ${widget.tecnicoNome}',
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeletorAno(),
            const SizedBox(height: 16),
            _buildSeletorMes(),
            const SizedBox(height: 16),
            _buildCalendario(),
            if (_diaSelecionado != null && _ddsNoDia.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildDetalhesDia(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeletorAno() {
    final anoAtual = DateTime.now().year;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(3, (i) {
          final ano = anoAtual - i;
          final sel = _anoSelecionado == ano;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { setState(() { _anoSelecionado = ano; _diaSelecionado = null; }); _carregar(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF00FF88).withOpacity(0.15) : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? const Color(0xFF00FF88) : Colors.white12),
                ),
                child: Text('$ano', style: TextStyle(
                  color: sel ? const Color(0xFF00FF88) : Colors.white54,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                )),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSeletorMes() {
    const meses = ['','Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 12,
        itemBuilder: (_, i) {
          final mes = i + 1;
          final sel = _mesSelecionado == mes;
          // Contar assinaturas neste mês
          final count = _calendario.keys.where((k) {
            try {
              final p = k.split('-');
              return int.parse(p[0]) == _anoSelecionado && int.parse(p[1]) == mes;
            } catch (_) { return false; }
          }).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() { _mesSelecionado = mes; _diaSelecionado = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF00FF88).withOpacity(0.15) : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? const Color(0xFF00FF88) : Colors.white12),
                ),
                child: Row(
                  children: [
                    Text(meses[mes], style: TextStyle(
                      color: sel ? const Color(0xFF00FF88) : Colors.white54,
                      fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    )),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$count',
                            style: const TextStyle(color: Color(0xFF00FF88), fontSize: 9)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendario() {
    const diasSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final primeiroDia = DateTime(_anoSelecionado, _mesSelecionado, 1);
    final ultimoDia = DateTime(_anoSelecionado, _mesSelecionado + 1, 0);
    final diasAssinados = _diasAssinadosNoMes;
    final offsetInicio = primeiroDia.weekday % 7; // domingo = 0

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Cabeçalho dos dias da semana
          Row(
            children: diasSemana.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: const TextStyle(color: Colors.white38, fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),

          // Grid de dias
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: offsetInicio + ultimoDia.day,
            itemBuilder: (_, i) {
              if (i < offsetInicio) return const SizedBox.shrink();

              final dia = i - offsetInicio + 1;
              final assinou = diasAssinados.contains(dia);
              final key = '$_anoSelecionado-'
                  '${_mesSelecionado.toString().padLeft(2,'0')}-'
                  '${dia.toString().padLeft(2,'0')}';
              final isSelecionado = _diaSelecionado == key;
              final hoje = DateTime.now();
              final isHoje = dia == hoje.day &&
                  _mesSelecionado == hoje.month &&
                  _anoSelecionado == hoje.year;

              return GestureDetector(
                onTap: assinou ? () => _selecionarDia(dia) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelecionado
                        ? const Color(0xFF00FF88)
                        : assinou
                        ? const Color(0xFF00FF88).withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isHoje && !assinou
                        ? Border.all(color: Colors.white24)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$dia',
                          style: TextStyle(
                            color: isSelecionado
                                ? Colors.black
                                : assinou
                                ? const Color(0xFF00FF88)
                                : Colors.white38,
                            fontSize: 13,
                            fontWeight: assinou || isHoje
                                ? FontWeight.bold : FontWeight.normal,
                          )),
                      if (assinou)
                        Container(
                          width: 5, height: 5,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: isSelecionado ? Colors.black54 : const Color(0xFF00FF88),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          // Legenda
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  )),
              const SizedBox(width: 4),
              const Text('DDS assinado', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetalhesDia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DDS em ${_diaSelecionado!.split('-').reversed.join('/')}',
          style: const TextStyle(color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._ddsNoDia.map((dds) => _buildCardDdsDia(dds)),
      ],
    );
  }

  Widget _buildCardDdsDia(Map<String, dynamic> dds) {
    final sig = dds['assinatura_base64'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dds['tema'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: Colors.white38),
              const SizedBox(width: 3),
              Text(dds['local_dds'] ?? 'BBNet Up Provedor',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 12),
              const Icon(Icons.access_time, size: 13, color: Colors.white38),
              const SizedBox(width: 3),
              Text('${dds['duracao_minutos']} min',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          if (sig != null) ...[
            const SizedBox(height: 10),
            const Text('Assinatura:', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 6),
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Builder(builder: (_) {
                  try {
                    final clean = sig.replaceFirst(RegExp(r'^data:image/\w+;base64,'), '');
                    return Image.memory(base64Decode(clean), fit: BoxFit.contain);
                  } catch (_) {
                    return const Center(child: Icon(Icons.draw, color: Colors.black38));
                  }
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}