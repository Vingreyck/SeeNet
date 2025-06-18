class Avaliacao {
  final int? id;
  final int tecnicoId;
  final String? titulo;
  final String? descricao;
  final String status; // 'em_andamento', 'concluida', 'cancelada'
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
      'data_criacao': dataCriacao?.toIso8601String(),
      'data_atualizacao': dataAtualizacao?.toIso8601String(),
    };
  }

  factory Avaliacao.fromMap(Map<String, dynamic> map) {
    return Avaliacao(
      id: map['id'],
      tecnicoId: map['tecnico_id'] ?? 0,
      titulo: map['titulo'],
      descricao: map['descricao'],
      status: map['status'] ?? 'em_andamento',
      dataInicio: map['data_inicio'] != null 
          ? DateTime.parse(map['data_inicio']) 
          : null,
      dataConclusao: map['data_conclusao'] != null 
          ? DateTime.parse(map['data_conclusao']) 
          : null,
      dataCriacao: map['data_criacao'] != null 
          ? DateTime.parse(map['data_criacao']) 
          : null,
      dataAtualizacao: map['data_atualizacao'] != null 
          ? DateTime.parse(map['data_atualizacao']) 
          : null,
    );
  }

  // Verificar se está concluída
  bool get isConcluida => status == 'concluida';
  
  // Verificar se está em andamento
  bool get isEmAndamento => status == 'em_andamento';
}