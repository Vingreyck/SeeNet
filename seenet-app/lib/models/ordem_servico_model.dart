import 'package:flutter/material.dart';
import 'dart:convert';

class OrdemServico {
  final String id;
  final String numeroOs;
  final String origem;
  final String? idExterno;
  final String empresaId;
  final String tecnicoId;
  final String tipoOs;
  final String? idEstrutura;
  final String? nomeEstrutura;

  final String clienteNome;
  final String? clienteEndereco;
  final String? clienteNumero;
  final String? clienteBairro;
  final String? clienteCidade;      // "Nome - UF" (vem do dados_ixc)
  final String? clienteCep;
  final String? clienteReferencia;
  final String? clienteComplemento;
  final String? clienteApartamento;
  final String? clienteCondominio;
  final String? clienteTelefone;
  final String? clienteLogin;
  final String? idLogin;            // id numérico do login no IXC (p/ limpar MAC)
  final String? senhaPppoe;         // senha PPPoE do login (dados_ixc)
  final String? plano;              // nome do plano/contrato (dados_ixc)
  final String? caixaFtth; // CTO
  final String? portaFtth;
  final String? idAssunto; // assunto IXC (60 = instalação de internet FTTH)

  final String tipoServico;
  final String prioridade;
  final String status;

  final DateTime? dataAbertura;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final double? latitude;
  final double? longitude;

  final String? onuModelo;
  final String? onuSerial;
  final String? onuStatus;
  final double? onuSinalOptico;

  final String? relatoProblema;
  final String? relatoSolucao;
  final String? materiaisUtilizados;
  final String? observacoes;

  final DateTime createdAt;
  final DateTime updatedAt;

  final List<AnexoOS>? anexos;

  OrdemServico({
    required this.id,
    required this.numeroOs,
    required this.origem,
    this.idExterno,
    required this.empresaId,
    required this.tecnicoId,
    this.tipoOs = 'C',
    this.idEstrutura,
    this.nomeEstrutura,
    required this.clienteNome,
    this.clienteEndereco,
    this.clienteNumero,
    this.clienteBairro,
    this.clienteCidade,
    this.clienteCep,
    this.clienteReferencia,
    this.clienteComplemento,
    this.clienteApartamento,
    this.clienteCondominio,
    this.clienteTelefone,
    this.clienteLogin,
    this.idLogin,
    this.senhaPppoe,
    this.plano,
    this.caixaFtth,
    this.portaFtth,
    this.idAssunto,
    required this.tipoServico,
    this.prioridade = 'media',
    this.status = 'pendente',
    this.dataAbertura,
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
    // Login/Caixa FTTH/Porta FTTH/Assunto vêm dentro do dados_ixc (JSON do IXC).
    String? clienteLogin;
    String? caixaFtth;
    String? portaFtth;
    String? idAssunto;
    String? clienteCidade;
    String? clienteCep;
    String? clienteReferencia;
    String? clienteComplemento;
    String? clienteApartamento;
    String? clienteCondominio;
    String? senhaPppoe;
    String? plano;
    String? idLogin;
    final dadosIxc = json['dados_ixc'];
    if (dadosIxc != null) {
      try {
        final d = dadosIxc is String ? jsonDecode(dadosIxc) : dadosIxc;
        if (d is Map) {
          String? limpo(dynamic v) {
            final s = v?.toString().trim();
            return (s == null || s.isEmpty || s == '0') ? null : s;
          }
          clienteLogin = limpo(d['login']);
          caixaFtth = limpo(d['caixa_ftth']);
          portaFtth = limpo(d['porta_ftth']);
          idAssunto = limpo(d['id_assunto']);
          clienteCidade = limpo(d['sn_cidade']);
          clienteCep = limpo(d['sn_cep']);
          clienteReferencia = limpo(d['sn_referencia']);
          clienteComplemento = limpo(d['sn_complemento']);
          clienteApartamento = limpo(d['sn_apartamento']);
          clienteCondominio = limpo(d['sn_condominio']);
          senhaPppoe = limpo(d['sn_senha']);
          plano = limpo(d['sn_plano']);
          idLogin = limpo(d['id_login']);
        }
      } catch (_) {}
    }
    return OrdemServico(
      clienteLogin: clienteLogin,
      idLogin: idLogin,
      caixaFtth: caixaFtth,
      portaFtth: portaFtth,
      idAssunto: idAssunto,
      clienteCidade: clienteCidade,
      clienteCep: clienteCep,
      clienteReferencia: clienteReferencia,
      clienteComplemento: clienteComplemento,
      clienteApartamento: clienteApartamento,
      clienteCondominio: clienteCondominio,
      senhaPppoe: senhaPppoe,
      plano: plano,
      id: (json['id'] ?? 0).toString(),
      numeroOs: json['numero_os']?.toString() ??
          json['numero_os_ixc']?.toString() ??
          'S/N',
      origem: json['origem']?.toString() ?? 'SEENET',
      idExterno: json['id_externo']?.toString(),
      empresaId: (json['tenant_id'] ?? 0).toString(),
      tecnicoId: (json['tecnico_id'] ?? 0).toString(),
      tipoOs: json['tipo_os']?.toString() ?? 'C',
      idEstrutura: json['id_estrutura']?.toString(),
      nomeEstrutura: json['nome_estrutura']?.toString(),
      clienteNome: json['cliente_nome']?.toString() ?? 'Cliente não identificado',
      clienteEndereco: json['cliente_endereco']?.toString(),
      clienteNumero: json['cliente_numero']?.toString(),
      clienteBairro: json['cliente_bairro']?.toString(),
      clienteTelefone: json['cliente_telefone']?.toString(),
      tipoServico: json['tipo_servico']?.toString() ?? 'Manutenção',
      prioridade: json['prioridade']?.toString() ?? 'media',
      status: json['status']?.toString() ?? 'pendente',
      dataAbertura: json['data_abertura'] != null
          ? DateTime.parse(json['data_abertura'])
          : null,
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
      onuModelo: json['onu_modelo']?.toString(),
      onuSerial: json['onu_serial']?.toString(),
      onuStatus: json['onu_status']?.toString(),
      onuSinalOptico: json['onu_sinal_optico'] != null
          ? double.tryParse(json['onu_sinal_optico'].toString())
          : null,
      relatoProblema: json['relato_problema']?.toString(),
      relatoSolucao: json['relato_solucao']?.toString(),
      materiaisUtilizados: json['materiais_utilizados']?.toString(),
      observacoes: json['observacoes']?.toString(),
      createdAt: json['data_criacao'] != null
          ? DateTime.parse(json['data_criacao'])
          : DateTime.now(),
      updatedAt: json['data_atualizacao'] != null
          ? DateTime.parse(json['data_atualizacao'])
          : DateTime.now(),
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
      'tipo_os': tipoOs,
      'id_estrutura': idEstrutura,
      'nome_estrutura': nomeEstrutura,
      'cliente_nome': clienteNome,
      'cliente_endereco': clienteEndereco,
      'cliente_numero': clienteNumero,
      'cliente_bairro': clienteBairro,
      'cliente_telefone': clienteTelefone,
      'tipo_servico': tipoServico,
      'prioridade': prioridade,
      'status': status,
      'data_abertura': dataAbertura?.toIso8601String(),
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

  Color get corPrioridade {
    switch (prioridade) {
      case 'urgente': return const Color(0xFFFF0000);
      case 'alta':    return const Color(0xFFFF6B00);
      case 'media':   return const Color(0xFFFFB800);
      case 'baixa':   return const Color(0xFF00FF88);
      default:        return const Color(0xFF888888);
    }
  }

  IconData get iconeStatus {
    switch (status) {
      case 'pendente':    return Icons.schedule;
      case 'em_execucao': return Icons.build;
      case 'concluida':   return Icons.check_circle;
      default:            return Icons.info;
    }
  }
}

class AnexoOS {
  final String id;
  final String osId;
  final String tipo;
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
      id: (json['id'] ?? '').toString(),
      osId: (json['ordem_servico_id'] ?? '').toString(),
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