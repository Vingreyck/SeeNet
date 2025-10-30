import '../utils/date_parser.dart';
import '../utils/model_validator.dart';

class Diagnostico {
  final int? id;
  final int avaliacaoId;
  final int categoriaId;
  final String promptEnviado;
  final String respostaChatgpt;
  final String? resumoDiagnostico;
  final String statusApi;
  final String? erroApi;
  final int? tokensUtilizados;
  final DateTime? dataCriacao;

  Diagnostico({
    this.id,
    required this.avaliacaoId,
    required this.categoriaId,
    required this.promptEnviado,
    required this.respostaChatgpt,
    this.resumoDiagnostico,
    this.statusApi = 'pendente',
    this.erroApi,
    this.tokensUtilizados,
    this.dataCriacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'avaliacao_id': avaliacaoId,
      'categoria_id': categoriaId,
      'prompt_enviado': promptEnviado,
      'resposta_chatgpt': respostaChatgpt,
      'resumo_diagnostico': resumoDiagnostico,
      'status_api': statusApi,
      'erro_api': erroApi,
      'tokens_utilizados': tokensUtilizados,
      'data_criacao': dataCriacao?.toIso8601String(),
    };
  }

  factory Diagnostico.fromMap(Map<String, dynamic> map) {
    // Validações
    ModelValidator.requirePositive(map['avaliacao_id'], 'avaliacao_id');
    ModelValidator.requirePositive(map['categoria_id'], 'categoria_id');
    ModelValidator.requireNotEmpty(map['prompt_enviado'], 'prompt_enviado');
    ModelValidator.requireNotEmpty(map['resposta_chatgpt'], 'resposta_chatgpt');
    ModelValidator.requireValidStatus(
      map['status_api'], 
      ['pendente', 'sucesso', 'erro'], 
      'status_api'
    );

    return Diagnostico(
      id: map['id'],
      avaliacaoId: map['avaliacao_id'],
      categoriaId: map['categoria_id'],
      promptEnviado: map['prompt_enviado'].toString().trim(),
      respostaChatgpt: map['resposta_chatgpt'].toString().trim(),
      resumoDiagnostico: map['resumo_diagnostico']?.toString().trim(),
      statusApi: map['status_api'] ?? 'pendente',
      erroApi: map['erro_api']?.toString(),
      tokensUtilizados: map['tokens_utilizados'],
      dataCriacao: DateParser.parseDateTime(map['data_criacao']),
    );
  }

  bool get isSucesso => statusApi == 'sucesso';
  bool get isErro => statusApi == 'erro';
  bool get isPendente => statusApi == 'pendente';
}