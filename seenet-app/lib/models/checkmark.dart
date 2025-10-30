import '../utils/date_parser.dart';

class Checkmark {
  final int? id;
  final int categoriaId;
  final String titulo;
  final String? descricao;
  final String promptChatgpt;
  final bool ativo;
  final int ordem;
  final DateTime? dataCriacao;

  Checkmark({
    this.id,
    required this.categoriaId,
    required this.titulo,
    this.descricao,
    required this.promptChatgpt,
    this.ativo = true,
    this.ordem = 0,
    this.dataCriacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoria_id': categoriaId,
      'titulo': titulo,
      'descricao': descricao,
      'prompt_chatgpt': promptChatgpt,
      'ativo': ativo ? 1 : 0,
      'ordem': ordem,
      'data_criacao': dataCriacao?.toIso8601String(),
    };
  }

  factory Checkmark.fromMap(Map<String, dynamic> map) {
    return Checkmark(
      id: map['id'],
      categoriaId: map['categoria_id'] ?? 0,
      titulo: map['titulo'] ?? '',
      descricao: map['descricao'],
      promptChatgpt: map['prompt_chatgpt'] ?? '',
      ativo: map['ativo'] == 1,
      ordem: map['ordem'] ?? 0,
      dataCriacao: DateParser.parseDateTime(map['data_criacao']),

    );
  }
}