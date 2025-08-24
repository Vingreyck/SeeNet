class Diagnostico {
  final int? id;
  final int avaliacaoId;
  final int categoriaId;
  final String promptEnviado;
  final String respostaChatgpt;
  final String? resumoDiagnostico;
  final String statusApi; // 'pendente', 'sucesso', 'erro'
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
    return Diagnostico(
      id: map['id'],
      avaliacaoId: map['avaliacao_id'] ?? 0,
      categoriaId: map['categoria_id'] ?? 0,
      promptEnviado: map['prompt_enviado'] ?? '',
      respostaChatgpt: map['resposta_chatgpt'] ?? '',
      resumoDiagnostico: map['resumo_diagnostico'],
      statusApi: map['status_api'] ?? 'pendente',
      erroApi: map['erro_api'],
      tokensUtilizados: map['tokens_utilizados'],
      dataCriacao: map['data_criacao'] != null 
          ? DateTime.parse(map['data_criacao']) 
          : null,
    );
  }

  // Verificar se foi bem-sucedido
  bool get isSucesso => statusApi == 'sucesso';
  
  // Verificar se houve erro
  bool get isErro => statusApi == 'erro';
  
  // Verificar se está pendente
  bool get isPendente => statusApi == 'pendente';
}