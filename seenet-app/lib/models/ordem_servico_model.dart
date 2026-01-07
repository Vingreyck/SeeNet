import 'package:flutter/material.dart';

class OrdemServico {
  final String id;
  final String numeroOs;
  final String origem; // 'IXC' ou 'SEENET'
  final String? idExterno; // ID no IXC
  final String empresaId;
  final String tecnicoId;
  
  // Dados do cliente
  final String clienteNome;
  final String? clienteEndereco;
  final String? clienteTelefone;
  
  // Dados da OS
  final String tipoServico;
  final String prioridade; // 'baixa', 'media', 'alta', 'urgente'
  final String status; // 'pendente', 'em_execucao', 'concluida'
  
  // Dados da execução
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final double? latitude;
  final double? longitude;
  
  // ONU (se aplicável)
  final String? onuModelo;
  final String? onuSerial;
  final String? onuStatus;
  final double? onuSinalOptico;
  
  // Relato/APR
  final String? relatoProblema;
  final String? relatoSolucao;
  final String? materiaisUtilizados;
  final String? observacoes;
  
  // Metadados
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Anexos (lista de URLs)
  final List<AnexoOS>? anexos;

  OrdemServico({
    required this.id,
    required this.numeroOs,
    required this.origem,
    this.idExterno,
    required this.empresaId,
    required this.tecnicoId,
    required this.clienteNome,
    this.clienteEndereco,
    this.clienteTelefone,
    required this.tipoServico,
    this.prioridade = 'media',
    this.status = 'pendente',
    this.dataInicio,
    this.dataFim,
    this.latitude,
    this.longitude,
    this.onuModelo,
    this.onuSerial,
    this.onuStatus,
    this.onuSinalOptico,
    this.relatoProblema,
    this.relatoSolucao,
    this.materiaisUtilizados,
    this.observacoes,
    required this.createdAt,
    required this.updatedAt,
    this.anexos,
  });

factory OrdemServico.fromJson(Map<String, dynamic> json) {
  return OrdemServico(
    id: (json['id'] ?? '').toString(), // ✅ CONVERTER
    numeroOs: json['numero_os'] ?? '',
    origem: json['origem'] ?? 'SEENET',
    idExterno: json['id_externo']?.toString(),
    empresaId: (json['tenant_id'] ?? json['empresa_id'] ?? '').toString(), // ✅ ACEITAR AMBOS
    tecnicoId: (json['tecnico_id'] ?? '').toString(), // ✅ CONVERTER
    clienteNome: json['cliente_nome'] ?? 'Cliente não identificado',
    clienteEndereco: json['cliente_endereco'],
    clienteTelefone: json['cliente_telefone'],
    tipoServico: json['tipo_servico'] ?? 'Manutenção',
    prioridade: json['prioridade'] ?? 'media',
    status: json['status'] ?? 'pendente',
    dataInicio: json['data_inicio'] != null 
        ? DateTime.parse(json['data_inicio']) 
        : null,
    dataFim: json['data_conclusao'] != null 
        ? DateTime.parse(json['data_conclusao']) 
        : null,
    latitude: json['latitude'] != null 
        ? double.tryParse(json['latitude'].toString()) 
        : null,
    longitude: json['longitude'] != null 
        ? double.tryParse(json['longitude'].toString()) 
        : null,
    onuModelo: json['onu_modelo'],
    onuSerial: json['onu_serial'],
    onuStatus: json['onu_status'],
    onuSinalOptico: json['onu_sinal_optico'] != null
        ? double.tryParse(json['onu_sinal_optico'].toString())
        : null,
    relatoProblema: json['relato_problema'],
    relatoSolucao: json['relato_solucao'],
    materiaisUtilizados: json['materiais_utilizados'],
    observacoes: json['observacoes'],
    createdAt: DateTime.parse(json['data_criacao']),
    updatedAt: DateTime.parse(json['data_atualizacao']),
    anexos: json['anexos'] != null
        ? (json['anexos'] as List)
            .map((a) => AnexoOS.fromJson(a))
            .toList()
        : null,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero_os': numeroOs,
      'origem': origem,
      'id_externo': idExterno,
      'empresa_id': empresaId,
      'tecnico_id': tecnicoId,
      'cliente_nome': clienteNome,
      'cliente_endereco': clienteEndereco,
      'cliente_telefone': clienteTelefone,
      'tipo_servico': tipoServico,
      'prioridade': prioridade,
      'status': status,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_conclusao': dataFim?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'onu_modelo': onuModelo,
      'onu_serial': onuSerial,
      'onu_status': onuStatus,
      'onu_sinal_optico': onuSinalOptico,
      'relato_problema': relatoProblema,
      'relato_solucao': relatoSolucao,
      'materiais_utilizados': materiaisUtilizados,
      'observacoes': observacoes,
      'data_criacao': createdAt.toIso8601String(),
      'data_atualizacao': updatedAt.toIso8601String(),
      'anexos': anexos?.map((a) => a.toJson()).toList(),
    };
  }

  // Getter para cor da prioridade
  Color get corPrioridade {
    switch (prioridade) {
      case 'urgente':
        return const Color(0xFFFF0000);
      case 'alta':
        return const Color(0xFFFF6B00);
      case 'media':
        return const Color(0xFFFFB800);
      case 'baixa':
        return const Color(0xFF00FF88);
      default:
        return const Color(0xFF888888);
    }
  }

  // Getter para ícone do status
  IconData get iconeStatus {
    switch (status) {
      case 'pendente':
        return Icons.schedule;
      case 'em_execucao':
        return Icons.build;
      case 'concluida':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }
}

class AnexoOS {
  final String id;
  final String osId;
  final String tipo; // 'roteador', 'local', 'onu', 'antes', 'depois'
  final String urlArquivo;
  final DateTime createdAt;

  AnexoOS({
    required this.id,
    required this.osId,
    required this.tipo,
    required this.urlArquivo,
    required this.createdAt,  
  });

factory AnexoOS.fromJson(Map<String, dynamic> json) {
  return AnexoOS(
    id: (json['id'] ?? '').toString(), // ✅ CONVERTER
    osId: (json['ordem_servico_id'] ?? '').toString(), // ✅ CONVERTER
    tipo: json['tipo'] ?? 'local',
    urlArquivo: json['url_arquivo'] ?? '',
    createdAt: DateTime.parse(json['data_upload']),
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ordem_servico_id': osId,
      'tipo': tipo,
      'url_arquivo': urlArquivo,
      'data_upload': createdAt.toIso8601String(),
    };
  }
}