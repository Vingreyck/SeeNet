import 'package:flutter/material.dart';
import 'dart:convert';

/// 📡 Qualidade do sinal óptico da ONU, classificada por REGRA FIXA (não por IA).
/// Os limites são de potência de recepção (RX) em dBm, padrão GPON.
enum NivelSinal {
  /// Acima de -25 dBm — dentro do esperado.
  bom,

  /// Entre -25 e -27 dBm — funciona, mas está na borda; costuma dar queda
  /// intermitente e piora com chuva.
  atencao,

  /// Abaixo de -27 dBm (ou forte demais, acima de -8) — fora da faixa de
  /// operação. Explica queda/lentidão sozinho.
  critico,

  /// Sem medição no IXC para este login.
  desconhecido,
}

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
  // Status de conexão (Online/Offline) do login — FOTO de quando a OS foi
  // sincronizada (não é ao vivo). null = não sabemos.
  final bool? statusConexaoOnline;
  final String? ultimaConexao;
  final String? caixaFtth; // CTO
  final String? portaFtth;
  final String? idAssunto; // assunto IXC (60 = instalação de internet FTTH)

  // 📡 Sinal da ONU — vem do mesmo registro de fibra que já traz caixa/porta,
  // então não custa chamada extra ao IXC. Como a fibra só é consultada na 1ª
  // sincronização da OS, `sinalMedidoEm` é obrigatório na tela: o técnico precisa
  // saber se está vendo a leitura de agora ou a de 3 dias atrás.
  final double? sinalRx;          // potência de recepção em dBm (o que importa)
  final double? sinalTx;          // potência de transmissão em dBm
  final double? onuTemperatura;   // °C
  final DateTime? sinalMedidoEm;  // quando o IXC mediu
  final String? onuTipo;          // modelo da ONU (ex: ZTEG-F670LV9)

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
    this.statusConexaoOnline,
    this.ultimaConexao,
    this.caixaFtth,
    this.portaFtth,
    this.idAssunto,
    this.sinalRx,
    this.sinalTx,
    this.onuTemperatura,
    this.sinalMedidoEm,
    this.onuTipo,
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
    bool? statusConexaoOnline;
    String? ultimaConexao;
    double? sinalRx;
    double? sinalTx;
    double? onuTemperatura;
    DateTime? sinalMedidoEm;
    String? onuTipo;
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
          statusConexaoOnline = d['sn_online'] is bool ? d['sn_online'] as bool : null;
          ultimaConexao = limpo(d['sn_ultima_conexao']);

          // 📡 Sinal da ONU. O backend já manda número (ou null), mas aceita
          // string por segurança: o dados_ixc pode ter sido gravado por uma
          // versão anterior do sincronizador.
          double? paraDouble(dynamic v) {
            if (v == null) return null;
            if (v is num) return v == 0 ? null : v.toDouble();
            final n = double.tryParse(v.toString().trim());
            return (n == null || n == 0) ? null : n;
          }

          sinalRx = paraDouble(d['sn_sinal_rx']);
          sinalTx = paraDouble(d['sn_sinal_tx']);
          onuTemperatura = paraDouble(d['sn_onu_temp']);
          onuTipo = limpo(d['sn_onu_tipo']);
          final dataSinal = limpo(d['sn_sinal_data']);
          if (dataSinal != null) {
            // IXC manda "2026-08-18 16:40:41" (espaço, não T) — DateTime.tryParse
            // aceita, mas normalizo pra não depender disso.
            final parsed = DateTime.tryParse(dataSinal.replaceFirst(' ', 'T'));
            // ⚠️ `tryParse` NÃO devolve null pra "0000-00-00 00:00:00" (que é como
            // o IXC marca "nunca medido"): devolve ano -1. Sem esta guarda, a tela
            // mostraria "há 740 mil dias". O backend já filtra, mas o dados_ixc
            // pode ter sido gravado por uma versão anterior do sincronizador.
            if (parsed != null && parsed.year >= 2000) {
              sinalMedidoEm = parsed;
            }
          }
        }
      } catch (_) {}
    }
    return OrdemServico(
      clienteLogin: clienteLogin,
      idLogin: idLogin,
      caixaFtth: caixaFtth,
      portaFtth: portaFtth,
      idAssunto: idAssunto,
      sinalRx: sinalRx,
      sinalTx: sinalTx,
      onuTemperatura: onuTemperatura,
      sinalMedidoEm: sinalMedidoEm,
      onuTipo: onuTipo,
      clienteCidade: clienteCidade,
      clienteCep: clienteCep,
      clienteReferencia: clienteReferencia,
      clienteComplemento: clienteComplemento,
      clienteApartamento: clienteApartamento,
      clienteCondominio: clienteCondominio,
      senhaPppoe: senhaPppoe,
      plano: plano,
      statusConexaoOnline: statusConexaoOnline,
      ultimaConexao: ultimaConexao,
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

  /// Assuntos do IXC que são RETIRADA de equipamento (técnico vai buscar a
  /// ONT/roteador no cliente, não instalar). Set pra facilitar incluir outro
  /// assunto depois sem caçar `== '90'` espalhado pelo app.
  static const Set<String> assuntosRetirada = {'90'};

  bool get isRetirada => assuntosRetirada.contains(idAssunto);

  // ─────────────────────────── 📡 SINAL DA ONU ───────────────────────────
  // Classificação por REGRA FIXA. Fica no model (e não numa IA) de propósito:
  // é aritmética simples, precisa dar sempre o mesmo resultado e não pode
  // depender de rede nem de serviço externo pra funcionar.

  /// Abaixo disto o sinal é crítico — a ONU costuma perder o link perto de -28.
  static const double sinalCritico = -27.0;

  /// Entre este valor e [sinalCritico] o link funciona, mas na borda:
  /// dá queda intermitente e piora com chuva.
  static const double sinalAtencao = -25.0;

  /// Acima disto o sinal é forte DEMAIS (falta atenuador / ONU perto do OLT),
  /// o que também é defeito e pode danificar o receptor.
  static const double sinalForteDemais = -8.0;

  /// Depois de quantas horas a medição deixa de valer como "de agora".
  /// A fibra só é consultada na 1ª sincronização da OS, então uma OS que ficou
  /// dias pendente carrega uma leitura velha — e o técnico precisa saber disso.
  static const int horasSinalValido = 24;

  bool get temSinal => sinalRx != null;

  NivelSinal get nivelSinal {
    final rx = sinalRx;
    if (rx == null) return NivelSinal.desconhecido;
    if (rx > sinalForteDemais) return NivelSinal.critico;
    if (rx < sinalCritico) return NivelSinal.critico;
    if (rx < sinalAtencao) return NivelSinal.atencao;
    return NivelSinal.bom;
  }

  /// true quando a medição é mais velha que [horasSinalValido]. A tela usa isso
  /// pra mostrar a leitura como referência e não como diagnóstico do momento.
  bool get sinalDesatualizado {
    final em = sinalMedidoEm;
    if (em == null) return true;
    return DateTime.now().difference(em).inHours >= horasSinalValido;
  }

  /// "-27,96 dBm" (vírgula, como o técnico lê). Vazio se não há medição.
  String get sinalFormatado {
    final rx = sinalRx;
    if (rx == null) return '';
    return '${rx.toStringAsFixed(2).replaceAll('.', ',')} dBm';
  }

  /// Idade da medição em texto curto: "agora", "há 3 h", "há 2 dias".
  String get sinalIdadeTexto {
    final em = sinalMedidoEm;
    if (em == null) return 'sem data';
    final d = DateTime.now().difference(em);
    if (d.isNegative || d.inMinutes < 5) return 'agora';
    if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
    if (d.inHours < 24) return 'há ${d.inHours} h';
    return 'há ${d.inDays} ${d.inDays == 1 ? 'dia' : 'dias'}';
  }

  /// Frase curta explicando o que o número significa — o que o técnico
  /// realmente precisa saber, sem ter que decorar os limites.
  String get sinalExplicacao {
    switch (nivelSinal) {
      case NivelSinal.bom:
        return 'Dentro do esperado';
      case NivelSinal.atencao:
        return 'Na borda — costuma cair de forma intermitente e piora com chuva';
      case NivelSinal.critico:
        return (sinalRx != null && sinalRx! > sinalForteDemais)
            ? 'Forte demais — falta atenuação, pode danificar a ONU'
            : 'Fora da faixa — explica queda e lentidão por si só';
      case NivelSinal.desconhecido:
        return 'Sem medição no IXC para este login';
    }
  }

  /// Cor da categoria "retirada". Roxo de propósito: nenhum dos ESTADOS usa
  /// roxo (pendente=amarelo, em campo=azul, concluída=verde), então bate o
  /// olho e já se lê como "outro tipo de coisa", não como mais um status.
  static const Color corRetirada = Color(0xFFA855F7);

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