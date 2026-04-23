import 'package:flutter/material.dart';
// import seus models e controllers existentes

class WebOsPage extends StatelessWidget {
  const WebOsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Row(
            children: [
              const Text(
                'Ordens de Serviço',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // filtros, search, etc — adicionar depois
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Tabela de OS
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                // Cabeçalho da tabela
                _TableHeader(),
                const Divider(color: Colors.white12),
                // Linhas — substitua pelo seu controller/Obx
                Expanded(
                  child: ListView.separated(
                    itemCount: 20, // trocar por controller.osList.length
                    separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (_, i) => _OsRow(index: i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: const [
          Expanded(flex: 1, child: _HeaderCell('Nº OS')),
          Expanded(flex: 3, child: _HeaderCell('Cliente')),
          Expanded(flex: 2, child: _HeaderCell('Técnico')),
          Expanded(flex: 2, child: _HeaderCell('Tipo')),
          Expanded(flex: 1, child: _HeaderCell('Status')),
          Expanded(flex: 2, child: _HeaderCell('Data')),
          SizedBox(width: 60), // coluna ações
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _OsRow extends StatelessWidget {
  final int index;
  const _OsRow({required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 1, child: _RowCell('#${1000 + index}')),
          Expanded(flex: 3, child: _RowCell('Cliente Exemplo $index')),
          Expanded(flex: 2, child: _RowCell('Técnico $index')),
          Expanded(flex: 2, child: _RowCell('Instalação')),
          Expanded(
            flex: 1,
            child: _StatusBadge('Aberta'),
          ),
          Expanded(flex: 2, child: _RowCell('20/04/2026')),
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white38),
              onPressed: () {
                // abrir detalhe da OS
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RowCell extends StatelessWidget {
  final String text;
  const _RowCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _color => switch (status.toLowerCase()) {
    'aberta'     => Colors.blueAccent,
    'em andamento' => Colors.orange,
    'concluída'  => Colors.green,
    _            => Colors.white38,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}