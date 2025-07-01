// lib/models/usuario.dart
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
  bool get isAdmin => tipoUsuario.toLowerCase() == 'admin';

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

  // ↓ ESTE MÉTODO ESTAVA FALTANDO NO SEU CÓDIGO ↓
  // Converter do Map (para ler do banco)
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      tipoUsuario: map['tipo_usuario'] ?? 'tecnico',
      ativo: map['ativo'] == 1,
      dataCriacao: map['data_criacao'] != null 
          ? DateTime.parse(map['data_criacao']) 
          : null,
      dataAtualizacao: map['data_atualizacao'] != null 
          ? DateTime.parse(map['data_atualizacao']) 
          : null,
    );
  }

    // Verificar se é administrador
  }