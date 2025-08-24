class RespostaCheckmark {
  final int? id;
  final int avaliacaoId;
  final int checkmarkId;
  final bool marcado;
  final String? observacoes;
  final DateTime? dataResposta;

  RespostaCheckmark({
    this.id,
    required this.avaliacaoId,
    required this.checkmarkId,
    this.marcado = false,
    this.observacoes,
    this.dataResposta,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'avaliacao_id': avaliacaoId,
      'checkmark_id': checkmarkId,
      'marcado': marcado ? 1 : 0,
      'observacoes': observacoes,
      'data_resposta': dataResposta?.toIso8601String(),
    };
  }

  factory RespostaCheckmark.fromMap(Map<String, dynamic> map) {
    return RespostaCheckmark(
      id: map['id'],
      avaliacaoId: map['avaliacao_id'] ?? 0,
      checkmarkId: map['checkmark_id'] ?? 0,
      marcado: map['marcado'] == 1,
      observacoes: map['observacoes'],
      dataResposta: map['data_resposta'] != null 
          ? DateTime.parse(map['data_resposta']) 
          : null,
    );
  }
}