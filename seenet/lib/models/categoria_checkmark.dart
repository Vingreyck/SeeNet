class CategoriaCheckmark {
  final int? id;
  final String nome;
  final String? descricao;
  final bool ativo;
  final int ordem;
  final DateTime? dataCriacao;

  CategoriaCheckmark({
    this.id,
    required this.nome,
    this.descricao,
    this.ativo = true,
    this.ordem = 0,
    this.dataCriacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'ativo': ativo ? 1 : 0,
      'ordem': ordem,
      'data_criacao': dataCriacao?.toIso8601String(),
    };
  }

  factory CategoriaCheckmark.fromMap(Map<String, dynamic> map) {
    return CategoriaCheckmark(
      id: map['id'],
      nome: map['nome'] ?? '',
      descricao: map['descricao'],
      ativo: map['ativo'] == 1,
      ordem: map['ordem'] ?? 0,
      dataCriacao: map['data_criacao'] != null 
          ? DateTime.parse(map['data_criacao']) 
          : null,
    );
  }
}