import '../utils/date_parser.dart';
import '../utils/model_validator.dart';

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
      'data_upload': dataCriacao?.toIso8601String(),
    };
  }

  factory CategoriaCheckmark.fromMap(Map<String, dynamic> map) {
    // Validações
    ModelValidator.requireNotEmpty(map['nome'], 'nome');

    return CategoriaCheckmark(
      id: map['id'],
      nome: map['nome'].toString().trim(),
      descricao: map['descricao']?.toString().trim(),
      ativo: map['ativo'] == 1 || map['ativo'] == true,
      ordem: map['ordem'] ?? 0,
      dataCriacao: DateParser.parseDateTime(map['data_upload']),
    );
  }
}