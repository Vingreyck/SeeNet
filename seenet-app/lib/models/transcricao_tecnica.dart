import '../utils/date_parser.dart';
import '../utils/model_validator.dart';

class TranscricaoTecnica {
  final int? id;
  final int tecnicoId;
  final String titulo;
  final String? descricao;
  final String transcricaoOriginal;
  final String pontosDaAcao;
  final String status;
  final int? duracaoSegundos;
  final String? categoriaProblema;
  final String? clienteInfo;
  final DateTime? dataInicio;
  final DateTime? dataConclusao;
  final DateTime? dataCriacao;

  TranscricaoTecnica({
    this.id,
    required this.tecnicoId,
    required this.titulo,
    this.descricao,
    required this.transcricaoOriginal,
    required this.pontosDaAcao,
    this.status = 'gravando',
    this.duracaoSegundos,
    this.categoriaProblema,
    this.clienteInfo,
    this.dataInicio,
    this.dataConclusao,
    this.dataCriacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tecnico_id': tecnicoId,
      'titulo': titulo,
      'descricao': descricao,
      'transcricao_original': transcricaoOriginal,
      'pontos_da_acao': pontosDaAcao,
      'status': status,
      'duracao_segundos': duracaoSegundos,
      'categoria_problema': categoriaProblema,
      'cliente_info': clienteInfo,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_conclusao': dataConclusao?.toIso8601String(),
      'data_upload': dataCriacao?.toIso8601String(),
    };
  }

  factory TranscricaoTecnica.fromMap(Map<String, dynamic> map) {
    // Validações
    ModelValidator.requirePositive(map['tecnico_id'], 'tecnico_id');
    ModelValidator.requireNotEmpty(map['titulo'], 'titulo');
    ModelValidator.requireNotEmpty(map['transcricao_original'], 'transcricao_original');
    ModelValidator.requireNotEmpty(map['pontos_da_acao'], 'pontos_da_acao');
    ModelValidator.requireValidStatus(
      map['status'], 
      ['gravando', 'processando', 'concluida', 'erro'], 
      'status'
    );

    return TranscricaoTecnica(
      id: map['id'],
      tecnicoId: map['tecnico_id'],
      titulo: map['titulo'].toString().trim(),
      descricao: map['descricao']?.toString().trim(),
      transcricaoOriginal: map['transcricao_original'].toString().trim(),
      pontosDaAcao: map['pontos_da_acao'].toString().trim(),
      status: map['status'] ?? 'gravando',
      duracaoSegundos: map['duracao_segundos'],
      categoriaProblema: map['categoria_problema']?.toString().trim(),
      clienteInfo: map['cliente_info']?.toString().trim(),
      dataInicio: DateParser.parseDateTime(map['data_inicio']),
      dataConclusao: DateParser.parseDateTime(map['data_conclusao']),
      dataCriacao: DateParser.parseDateTime(map['data_upload']),
    );
  }

  bool get isGravando => status == 'gravando';
  bool get isProcessando => status == 'processando';
  bool get isConcluida => status == 'concluida';
  bool get isErro => status == 'erro';

  String get duracaoFormatada {
    if (duracaoSegundos == null) return 'N/A';
    int minutos = duracaoSegundos! ~/ 60;
    int segundos = duracaoSegundos! % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  TranscricaoTecnica copyWith({
    int? id,
    int? tecnicoId,
    String? titulo,
    String? descricao,
    String? transcricaoOriginal,
    String? pontosDaAcao,
    String? status,
    int? duracaoSegundos,
    String? categoriaProblema,
    String? clienteInfo,
    DateTime? dataInicio,
    DateTime? dataConclusao,
    DateTime? dataCriacao,
  }) {
    return TranscricaoTecnica(
      id: id ?? this.id,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      transcricaoOriginal: transcricaoOriginal ?? this.transcricaoOriginal,
      pontosDaAcao: pontosDaAcao ?? this.pontosDaAcao,
      status: status ?? this.status,
      duracaoSegundos: duracaoSegundos ?? this.duracaoSegundos,
      categoriaProblema: categoriaProblema ?? this.categoriaProblema,
      clienteInfo: clienteInfo ?? this.clienteInfo,
      dataInicio: dataInicio ?? this.dataInicio,
      dataConclusao: dataConclusao ?? this.dataConclusao,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }
}