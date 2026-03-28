// lib/services/estoque_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:seenet/services/auth_service.dart';

/// Modelo de produto do estoque IXC
class ProdutoEstoque {
  final String id;
  final String descricao;
  final double valor;
  final double precoBase;
  final String unidade;
  final String tipo; // O = consumo, P = patrimônio
  final double saldoAlmoxarifado;
  final double saldoGeral;

  ProdutoEstoque({
    required this.id,
    required this.descricao,
    this.valor = 0,
    this.precoBase = 0,
    this.unidade = '1',
    this.tipo = 'O',
    this.saldoAlmoxarifado = 0,
    this.saldoGeral = 0,
  });

  factory ProdutoEstoque.fromJson(Map<String, dynamic> json) {
    return ProdutoEstoque(
      id: json['id_produto']?.toString() ?? json['id']?.toString() ?? '',
      descricao: json['descricao'] ?? json['produto_descricao'] ?? '',
      valor: _parseDouble(json['valor']),
      precoBase: _parseDouble(json['preco_base'] ?? json['produto_preco_base']),
      unidade: json['unidade']?.toString() ?? json['produto_unidade']?.toString() ?? '1',
      tipo: json['tipo'] ?? json['produto_tipo'] ?? 'O',
      saldoAlmoxarifado: _parseDouble(json['saldo_almoxarifado'] ?? json['saldo']),
      saldoGeral: _parseDouble(json['saldo_geral'] ?? json['saldo']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  /// Retorna o valor a usar (precoBase > valor > 0)
  double get valorUnitario => precoBase > 0 ? precoBase : valor;

  /// Label legível do tipo
  String get tipoLabel => tipo == 'P' ? 'Patrimônio' : 'Consumo';
}

/// Modelo de patrimônio (equipamento com serial)
class PatrimonioEstoque {
  final String id;
  final String descricao;
  final String serial;
  final String mac;
  final String idProduto;
  final String idAlmoxarifado;
  final double valorBem;
  final String situacao;
  final String numeroPatrimonial; // ✅ NOVO

  PatrimonioEstoque({
    required this.id,
    required this.descricao,
    this.serial = '',
    this.mac = '',
    this.idProduto = '',
    this.idAlmoxarifado = '',
    this.valorBem = 0,
    this.situacao = '1',
    this.numeroPatrimonial = '', // ✅ NOVO
  });

  factory PatrimonioEstoque.fromJson(Map<String, dynamic> json) {
    return PatrimonioEstoque(
      id:                json['id']?.toString() ?? '',
      descricao:         json['descricao'] ?? '',
      serial:            json['numero_serie'] ?? json['serial'] ?? '',  // ✅ IXC usa numero_serie
      mac:               json['id_mac'] ?? '',
      idProduto:         json['id_produto']?.toString() ?? '',
      idAlmoxarifado:    json['id_almoxarifado']?.toString() ?? '',
      valorBem:          ProdutoEstoque._parseDouble(json['valor_bem']),
      situacao:          json['situacao']?.toString() ?? '1',
      numeroPatrimonial: json['numero_patrimonial']?.toString() ?? '', // ✅ NOVO
    );
  }
}

/// Modelo de item adicionado à OS (produto ou patrimônio)
class ItemOS {
  final ProdutoEstoque produto;
  final PatrimonioEstoque? patrimonio;
  double quantidade;
  double valorUnitario;

  ItemOS({
    required this.produto,
    this.patrimonio,
    this.quantidade = 1,
    double? valorUnitario,
  }) : valorUnitario = valorUnitario ?? produto.valorUnitario;

  double get valorTotal => quantidade * valorUnitario;

  bool get isPatrimonio => patrimonio != null;

  String get descricaoCompleta {
    if (patrimonio != null) {
      return '${produto.descricao} (S/N: ${patrimonio!.serial})';
    }
    return produto.descricao;
  }
}

/// Modelo de produto já vinculado à OS no IXC
class ProdutoOS {
  final String id;
  final String idProduto;
  final String descricao;
  final double quantidade;
  final double valorUnitario;
  final double valorTotal;
  final String idPatrimonio;
  final String numeroSerie;
  final String tipoProtudo;
  final String data;

  ProdutoOS({
    required this.id,
    required this.idProduto,
    required this.descricao,
    this.quantidade = 0,
    this.valorUnitario = 0,
    this.valorTotal = 0,
    this.idPatrimonio = '0',
    this.numeroSerie = '',
    this.tipoProtudo = 'O',
    this.data = '',
  });

  factory ProdutoOS.fromJson(Map<String, dynamic> json) {
    return ProdutoOS(
      id: json['id']?.toString() ?? '',
      idProduto: json['id_produto']?.toString() ?? '',
      descricao: json['descricao'] ?? '',
      quantidade: ProdutoEstoque._parseDouble(json['quantidade']),
      valorUnitario: ProdutoEstoque._parseDouble(json['valor_unitario']),
      valorTotal: ProdutoEstoque._parseDouble(json['valor_total']),
      idPatrimonio: json['id_patrimonio']?.toString() ?? '0',
      numeroSerie: json['numero_serie'] ?? '',
      tipoProtudo: json['tipo_produto'] ?? 'O',
      data: json['data'] ?? '',
    );
  }

  bool get isPatrimonio => idPatrimonio != '0' && idPatrimonio.isNotEmpty;
}

/// Service para comunicação com as rotas de estoque
class EstoqueService {
  final String baseUrl = 'https://seenet-production.up.railway.app/api';
  final AuthService _authService = Get.find<AuthService>();

  Map<String, String> get _headers {
    final token = _authService.token;
    final tenantCode = _authService.tenantCode;
    return {
      'Authorization': 'Bearer $token',
      'X-Tenant-Code': tenantCode ?? '',
      'Content-Type': 'application/json',
    };
  }

  // ═══════════════════════════════════════
  // BUSCAR SALDO DO ALMOXARIFADO (produtos com saldo)
  // ═══════════════════════════════════════
  Future<List<ProdutoEstoque>> buscarSaldoEstoque() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/estoque/saldo'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> itens = data['data'] ?? [];
        return itens.map((j) => ProdutoEstoque.fromJson(j)).toList();
      }
      throw Exception('Erro ao buscar saldo: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro em buscarSaldoEstoque: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // BUSCAR TODOS OS PRODUTOS
  // ═══════════════════════════════════════
  Future<List<ProdutoEstoque>> buscarProdutos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/estoque/produtos'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> itens = data['data'] ?? [];
        return itens.map((j) => ProdutoEstoque.fromJson(j)).toList();
      }
      throw Exception('Erro ao buscar produtos: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro em buscarProdutos: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // BUSCAR PATRIMÔNIOS DO ALMOXARIFADO
  // ═══════════════════════════════════════
  Future<List<PatrimonioEstoque>> buscarPatrimonios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/estoque/patrimonios?rp=500'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> itens = data['data'] ?? [];
        return itens.map((j) => PatrimonioEstoque.fromJson(j)).toList();
      }
      throw Exception('Erro ao buscar patrimônios: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro em buscarPatrimonios: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // LISTAR PRODUTOS JÁ VINCULADOS À OS
  // ═══════════════════════════════════════
  Future<List<ProdutoOS>> listarProdutosOS(String osIdExterno) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/estoque/os/$osIdExterno/produtos'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> itens = data['data'] ?? [];
        return itens.map((j) => ProdutoOS.fromJson(j)).toList();
      }
      throw Exception('Erro ao listar produtos da OS: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro em listarProdutosOS: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════
  // ADICIONAR PRODUTO À OS
  // ═══════════════════════════════════════
  Future<bool> adicionarProdutoOS({
    required String osIdExterno,
    required String idProduto,
    required double quantidade,
    required double valorUnitario,
    required String descricao,
    String idPatrimonio = '0',
    String numeroSerie = '',
    String idUnidade = '1',
    String unidadeSigla = 'UND',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/estoque/os/$osIdExterno/produtos'),
        headers: _headers,
        body: json.encode({
          'id_produto': idProduto,
          'quantidade': quantidade,
          'valor_unitario': valorUnitario,
          'descricao': descricao,
          'id_patrimonio': idPatrimonio,
          'numero_serie': numeroSerie,
          'id_unidade': idUnidade,
          'unidade_sigla': unidadeSigla,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Erro em adicionarProdutoOS: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════
  // REMOVER PRODUTO DA OS
  // ═══════════════════════════════════════
  Future<bool> removerProdutoOS(String osIdExterno, String movimentoId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/estoque/os/$osIdExterno/produtos/$movimentoId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Erro em removerProdutoOS: $e');
      return false;
    }
  }
}