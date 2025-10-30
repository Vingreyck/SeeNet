import '../utils/date_parser.dart';
import '../utils/model_validator.dart';

class LogSistema {
  final int? id;
  final int? usuarioId;
  final String acao;
  final String? tabelaAfetada;
  final int? registroId;
  final String? dadosAnteriores;
  final String? dadosNovos;
  final String? ipAddress;
  final String? userAgent;
  final DateTime? dataAcao;

  LogSistema({
    this.id,
    this.usuarioId,
    required this.acao,
    this.tabelaAfetada,
    this.registroId,
    this.dadosAnteriores,
    this.dadosNovos,
    this.ipAddress,
    this.userAgent,
    this.dataAcao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'acao': acao,
      'tabela_afetada': tabelaAfetada,
      'registro_id': registroId,
      'dados_anteriores': dadosAnteriores,
      'dados_novos': dadosNovos,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'data_acao': dataAcao?.toIso8601String(),
    };
  }

  factory LogSistema.fromMap(Map<String, dynamic> map) {
    // Validações
    ModelValidator.requireNotEmpty(map['acao'], 'acao');

    return LogSistema(
      id: map['id'],
      usuarioId: map['usuario_id'],
      acao: map['acao'].toString().trim(),
      tabelaAfetada: map['tabela_afetada']?.toString().trim(),
      registroId: map['registro_id'],
      dadosAnteriores: map['dados_anteriores']?.toString(),
      dadosNovos: map['dados_novos']?.toString(),
      ipAddress: map['ip_address']?.toString(),
      userAgent: map['user_agent']?.toString(),
      dataAcao: DateParser.parseDateTime(map['data_acao']),
    );
  }
}