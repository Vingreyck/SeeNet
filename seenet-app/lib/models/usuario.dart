import '../utils/date_parser.dart';
import '../utils/model_validator.dart';

class Usuario {
  final int? id;
  final String nome;
  final String email;
  final String senha;
  final String tipoUsuario; // 'tecnico' ou 'administrador'
  final bool ativo;
  final DateTime? dataCriacao;
  final DateTime? dataAtualizacao;

  Usuario({
    this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.tipoUsuario,
    this.ativo = true,
    this.dataCriacao,
    this.dataAtualizacao,
  });

  // Verificar se é administrador
  bool get isAdmin => tipoUsuario.toLowerCase() == 'admin' || tipoUsuario.toLowerCase() == 'administrador';

  // Converter para Map (para salvar no banco)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'senha': senha,
      'tipo_usuario': tipoUsuario,
      'ativo': ativo ? 1 : 0,
      'data_criacao': dataCriacao?.toIso8601String(),
      'data_atualizacao': dataAtualizacao?.toIso8601String(),
    };
  }

  // Converter do Map (para ler do banco)
  factory Usuario.fromMap(Map<String, dynamic> map) {
    // Validações
    ModelValidator.requireNotEmpty(map['nome'], 'nome');
    ModelValidator.requireValidEmail(map['email']);
    ModelValidator.requireNotEmpty(map['tipo_usuario'], 'tipo_usuario');
    ModelValidator.requireValidStatus(
      map['tipo_usuario']?.toString().toLowerCase(), 
      ['tecnico', 'administrador', 'admin'], 
      'tipo_usuario'
    );

    return Usuario(
      id: map['id'],
      nome: map['nome'].toString().trim(),
      email: map['email'].toString().trim().toLowerCase(),
      senha: map['senha']?.toString() ?? '',
      tipoUsuario: map['tipo_usuario'].toString().trim().toLowerCase(),
      ativo: map['ativo'] == 1 || map['ativo'] == true,
      dataCriacao: DateParser.parseDateTime(map['data_criacao']),
      dataAtualizacao: DateParser.parseDateTime(map['data_atualizacao']),
    );
  }
}