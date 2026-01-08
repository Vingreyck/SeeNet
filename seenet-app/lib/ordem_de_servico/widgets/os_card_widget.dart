import 'package:flutter/material.dart';
import '../../models/ordem_servico_model.dart';
import 'package:intl/intl.dart';

class OSCardWidget extends StatelessWidget {
  final OrdemServico os;
  final VoidCallback onTap;

  const OSCardWidget({
    super.key,
    required this.os,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: os.corPrioridade.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER: Número da OS + Prioridade
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      os.iconeStatus,
                      color: os.corPrioridade,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OS #${os.numeroOs}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: os.corPrioridade.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: os.corPrioridade, width: 1),
                  ),
                  child: Text(
                    os.prioridade.toUpperCase(),
                    style: TextStyle(
                      color: os.corPrioridade,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ CLIENTE
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    os.clienteNome,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (os.clienteEndereco != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      os.clienteEndereco!,
                      style: const TextStyle(color: Colors.white60, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // ✅ TIPO DE SERVIÇO E DATA
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    os.tipoServico,
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  os.dataAbertura != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(os.dataAbertura!)
                      : 'Sem data',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),

            // ✅ SE EM EXECUÇÃO, MOSTRAR TEMPO DECORRIDO
            if (os.status == 'em_execucao' && os.dataInicio != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Em execução há ${_calcularTempo(os.dataInicio!)}',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // ✅ SE CONCLUÍDA, MOSTRAR DURAÇÃO
            if (os.status == 'concluida' && os.dataInicio != null && os.dataFim != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Concluída em ${_calcularDuracao(os.dataInicio!, os.dataFim!)}',
                      style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _calcularTempo(DateTime inicio) {
    final duracao = DateTime.now().difference(inicio);
    if (duracao.inHours > 0) {
      return '${duracao.inHours}h ${duracao.inMinutes % 60}min';
    }
    return '${duracao.inMinutes}min';
  }

  String _calcularDuracao(DateTime inicio, DateTime fim) {
    final duracao = fim.difference(inicio);
    if (duracao.inHours > 0) {
      return '${duracao.inHours}h ${duracao.inMinutes % 60}min';
    }
    return '${duracao.inMinutes}min';
  }
}