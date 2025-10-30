import '../utils/model_validator.dart';
import '../utils/date_parser.dart';

class Checkmark {
  final int? id;
  final int categoriaId;
  final String titulo;
  final String? descricao;
  final String promptGemini;
  final bool ativo;
  final int ordem;
  final DateTime? dataCriacao;

  Checkmark({
    this.id,
    required this.categoriaId,
    required this.titulo,
    this.descricao,
    required this.promptGemini,
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
      'prompt_gemini': promptGemini,
      'ativo': ativo ? 1 : 0,
      'ordem': ordem,
      'data_criacao': dataCriacao?.toIso8601String(),
    };
  }

  factory Checkmark.fromMap(Map<String, dynamic> map) {
    // Validações mais flexíveis
    ModelValidator.requireNotEmpty(map['titulo'], 'titulo');
    
    // Categoria ID pode vir como 0 em alguns casos do backend
    // Vamos permitir 0 mas logar warning
    final categoriaId = map['categoria_id'] ?? 
                          map['categoriaId'] ?? 
                          0;
      
      if (categoriaId == 0) {
        print('⚠️ Warning: Checkmark "${map['titulo']}" tem categoria_id = 0');
      }
    
  return Checkmark(
    id: map['id'],
    categoriaId: categoriaId,
    titulo: map['titulo']?.toString().trim() ?? '',
    descricao: map['descricao']?.toString(),
    promptGemini: map['prompt_gemini']?.toString() ?? 
                   map['promptgemini']?.toString() ?? 
                   map['prompt']?.toString() ?? '',
    ativo: map['ativo'] == 1 || map['ativo'] == true || map['ativo'] == 'true',
    ordem: map['ordem'] ?? 0,
    dataCriacao: DateParser.parseDateTime(map['data_criacao'] ?? map['dataCriacao']),
  );
  }
}