import '../utils/date_parser.dart';
import '../utils/model_validator.dart';

class Avaliacao {
  final int? id;
  final int tecnicoId;
  final String? titulo;
  final String? descricao;
  final String status;
  final DateTime? dataInicio;
  final DateTime? dataConclusao;
  final DateTime? dataCriacao;
  final DateTime? dataAtualizacao;

  Avaliacao({
    this.id,
    required this.tecnicoId,
    this.titulo,
    this.descricao,
    this.status = 'em_andamento',
    this.dataInicio,
    this.dataConclusao,
    this.dataCriacao,
    this.dataAtualizacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tecnico_id': tecnicoId,
      'titulo': titulo,
      'descricao': descricao,
      'status': status,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_conclusao': dataConclusao?.toIso8601String(),
      'data_upload': dataCriacao?.toIso8601String(),
      'data_atualizacao': dataAtualizacao?.toIso8601String(),
    };
  }

  factory Avaliacao.fromMap(Map<String, dynamic> map) {
    // Validações
    ModelValidator.requirePositive(map['tecnico_id'], 'tecnico_id');
    ModelValidator.requireValidStatus(
      map['status'], 
      ['em_andamento', 'concluida', 'cancelada'], 
      'status'
    );

    return Avaliacao(
      id: map['id'],
      tecnicoId: map['tecnico_id'],
      titulo: map['titulo']?.toString().trim(),
      descricao: map['descricao']?.toString().trim(),
      status: map['status'] ?? 'em_andamento',
      dataInicio: DateParser.parseDateTime(map['data_inicio']),
      dataConclusao: DateParser.parseDateTime(map['data_conclusao']),
      dataCriacao: DateParser.parseDateTime(map['data_upload']),
      dataAtualizacao: DateParser.parseDateTime(map['data_atualizacao']),
    );
  }

  bool get isConcluida => status == 'concluida';
  bool get isEmAndamento => status == 'em_andamento';
}