import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:seenet/services/auth_service.dart';

class SegurancaService extends GetxService {
  final AuthService _authService = Get.find<AuthService>();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${_authService.token}',
    'X-Tenant-Code': _authService.tenantCode ?? '',
  };

  String get _base => 'https://seenet-production.up.railway.app/api/seguranca';
  String get _baseEstoque => 'https://seenet-production.up.railway.app/api/estoque';

  // ── Helper HTTP (web-safe) ─────────────────────────────────────
  // O GetConnect QUEBRA POST/PUT no WEB (tenta setar 'content-length', o navegador
  // bloqueia e o corpo não vai → backend recebe vazio). O http funciona em TODAS as
  // plataformas (mobile inclusive). Devolve { 'status', 'body' (já parseado) }.
  Future<Map<String, dynamic>> _http(
      String metodo, String url, [Map<String, dynamic>? corpo]) async {
    final uri = Uri.parse(url);
    final String? corpoJson = corpo == null ? null : json.encode(corpo);
    final http.Response r;
    if (metodo == 'PUT') {
      r = await http.put(uri, headers: _headers, body: corpoJson);
    } else if (metodo == 'DELETE') {
      r = await http.delete(uri, headers: _headers);
    } else {
      r = await http.post(uri, headers: _headers, body: corpoJson);
    }
    return {
      'status': r.statusCode,
      'body': r.body.isNotEmpty ? json.decode(r.body) : null,
    };
  }

  // ── EPIs disponíveis ──────────────────────────────────────────
  Future<List<String>> buscarEpis() async {
    try {
      final response = await GetConnect().get('$_base/epis', headers: _headers);
      if (response.statusCode == 200) {
        final List epis = (response.body['data'] ?? response.body)['epis'] ?? [];
        return _ordenarPt(epis.cast<String>());
      }
      return _episPadrao();
    } catch (_) { return _episPadrao(); }
  }

  // Ordena ignorando acentos (Ó, Ã, Ç...), pra qualquer EPI novo entrar
  // sempre na posição certa, mesmo se vier fora de ordem do backend.
  List<String> _ordenarPt(List<String> lista) {
    String semAcento(String s) => s
        .toLowerCase()
        .replaceAll(RegExp('[áàâã]'), 'a')
        .replaceAll(RegExp('[éê]'), 'e')
        .replaceAll('í', 'i')
        .replaceAll(RegExp('[óôõ]'), 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
    final copia = [...lista];
    copia.sort((a, b) => semAcento(a).compareTo(semAcento(b)));
    return copia;
  }

  List<String> _episPadrao() => _ordenarPt(const [
    'Avental', 'Balaclava', 'Bandeirola', 'Bota de Segurança',
    'Calça Operacional', 'Camisa Manga Longa (Jaleco)',
    'Capacete de Segurança (Classe B)', 'Carneira', 'Catraca Trava Escada',
    'Cinto de Segurança', 'Cone de Sinalização', 'Detector de Tensão',
    'Escada de Alumínio', 'Escada Extensível', 'Fita de Sinalização Zebrada',
    'Jugular', 'Luva de Segurança (Isolante)', 'Luva de Vaqueta', 'Luva Latex',
    'Óculos de Segurança', 'Protetor Solar', 'Talabarte de Posicionamento',
  ]);

  // ── Criar requisição ──────────────────────────────────────────
  Future<Map<String, dynamic>> criarRequisicao({required List<String> episSolicitados}) async {
    try {
      final r = await _http('POST', '$_base/requisicoes', {'epis_solicitados': episSolicitados});
      if (r['status'] == 201) {
        return {'success': true, 'message': r['body']?['message'] ?? 'Enviado'};
      }
      return {'success': false, 'message': r['body']?['error'] ?? 'Erro (${r['status']})'};
    } catch (e) { return {'success': false, 'message': 'Erro de conexão: $e'}; }
  }

  // ── Perfil de um técnico (visão gestor) ───────────────────────
  Future<Map<String, dynamic>?> buscarPerfilTecnico(int tecnicoId) async {
    try {
      final response = await GetConnect().get(
        '$_base/tecnicos/$tecnicoId/perfil',
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return response.body['data'] ?? response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Confirmar recebimento (técnico) ───────────────────────────
  Future<Map<String, dynamic>> confirmarRecebimento({
    required int id,
    required String assinaturaBase64,
    required String fotoBase64,
  }) async {
    final r = await _http('POST', '$_base/requisicoes/$id/confirmar-recebimento',
        {'assinatura_base64': assinaturaBase64, 'foto_base64': fotoBase64});
    if (r['status'] == 200) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro ao confirmar'};
  }

  // ── Minhas requisições ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> buscarMinhasRequisicoes() async {
    try {
      final response = await GetConnect().get('$_base/requisicoes/minhas', headers: _headers);
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['requisicoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Técnicos ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> buscarTecnicos() async {
    try {
      final response = await GetConnect().get('$_base/tecnicos', headers: _headers);
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['tecnicos'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Registro manual ───────────────────────────────────────────
  Future<Map<String, dynamic>> criarRegistroManual({
    required int tecnicoId,
    required List<String> episSolicitados,
    String? assinaturaBase64,
    String? fotoBase64,
    String? observacao,
    DateTime? dataEntrega,
    String? fotoDocumentoBase64,
    bool ehFichario = false,
  }) async {
    try {
      final body = {
        'tecnico_id': tecnicoId,
        'epis_solicitados': episSolicitados,
        if (assinaturaBase64 != null) 'assinatura_base64': assinaturaBase64,
        if (fotoBase64 != null) 'foto_base64': fotoBase64,
        if (observacao != null) 'observacao_gestor': observacao,
        'data_entrega': (dataEntrega ?? DateTime.now()).toIso8601String(),
        'eh_fichario': ehFichario,
        if (fotoDocumentoBase64 != null)
          'foto_documento_base64': fotoDocumentoBase64,
      };

      final r = await _http('POST', '$_base/requisicoes/manual', body);

      if (r['status'] == 201) {
        return {
          'success': true,
          'message': r['body']?['message']
        };
      }

      return {
        'success': false,
        'message': r['body']?['error'] ?? 'Erro ao criar registro'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão: $e'
      };
    }
  }

  // ── PDF ───────────────────────────────────────────────────────
  Future<String?> buscarPdf(int id) async {
    try {
      final response = await GetConnect().get('$_base/requisicoes/$id/pdf', headers: _headers);
      if (response.statusCode == 200) {
        return (response.body['data'] ?? response.body)['pdf_base64'] as String?;
      }
      return null;
    } catch (_) { return null; }
  }

  // ── Pendentes (gestor) ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> buscarPendentes() async {
    try {
      final response = await GetConnect().get('$_base/requisicoes/pendentes', headers: _headers);
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['requisicoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Todas (gestor) ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> buscarTodas({String? status}) async {
    try {
      final url = status != null ? '$_base/requisicoes?status=$status' : '$_base/requisicoes';
      final response = await GetConnect().get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['requisicoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Histórico (gestor) — requisições concluídas com foto/assinatura ──
  Future<List<Map<String, dynamic>>> buscarHistorico({int? tecnicoId}) async {
    try {
      final url = tecnicoId != null
          ? '$_base/requisicoes/historico?tecnico_id=$tecnicoId'
          : '$_base/requisicoes/historico';
      final response = await GetConnect().get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['requisicoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Detalhe ───────────────────────────────────────────────────
  Future<Map<String, dynamic>?> buscarDetalhe(int id) async {
    try {
      final response = await GetConnect().get('$_base/requisicoes/$id', headers: _headers);
      if (response.statusCode == 200) {
        return (response.body['data'] ?? response.body)['requisicao'];
      }
      return null;
    } catch (_) { return null; }
  }

  // ── Aprovar — aceita itens do estoque IXC ─────────────────────
  Future<Map<String, dynamic>> aprovar(
      int id, {
        String? observacao,
        String? dataEntrega,
        List<Map<String, dynamic>>? itensIxc,
        // itensIxc: [{'id_produto': '525', 'descricao': 'Luva', 'quantidade': 2}]
        String? idAlmoxarifado,
      }) async {
    final r = await _http('POST', '$_base/requisicoes/$id/aprovar', {
      'observacao': observacao ?? '',
      if (dataEntrega != null) 'data_entrega': dataEntrega,
      if (itensIxc != null && itensIxc.isNotEmpty) 'itens_ixc': itensIxc,
      if (idAlmoxarifado != null) 'id_almoxarifado': idAlmoxarifado,
    });
    if (r['status'] == 200) {
      return {
        'success': true,
        'message': r['body']?['message'],
        'id_requisicao_ixc': r['body']?['id_requisicao_ixc'],
        'itens_descontados': r['body']?['itens_descontados'],
      };
    }
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro ao aprovar'};
  }

  // ── Recusar ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> recusar(int id, {required String observacao}) async {
    try {
      // ✅ http (NÃO GetConnect): no WEB o GetConnect tenta setar 'content-length'
      // (o navegador bloqueia) e o CORPO não vai → o backend recebe vazio →
      // 400 "Motivo obrigatório". Com http o corpo vai certo.
      final response = await http.post(
        Uri.parse('$_base/requisicoes/$id/recusar'),
        headers: _headers,
        body: json.encode({'observacao': observacao}),
      );
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      if (response.statusCode == 200) {
        return {'success': true, 'message': body['message']};
      }
      return {'success': false, 'message': body['error'] ?? 'Erro ao recusar'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao recusar: $e'};
    }
  }

  // ── Validar recebimento (gestor aceita/reprova a assinatura do técnico) ──
  Future<Map<String, dynamic>> validarRecebimento(int id,
      {required bool aprovar, String? observacao}) async {
    final r = await _http('POST', '$_base/requisicoes/$id/validar-recebimento', {
      'aprovar': aprovar,
      if (observacao != null) 'observacao': observacao,
    });
    if (r['status'] == 200) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro ao validar'};
  }

  // ── Estoque IXC (para o gestor selecionar itens ao aprovar) ──
  Future<List<Map<String, dynamic>>> buscarProdutosEstoqueDoTecnico(int tecnicoId) async {
    try {
      // Usa o endpoint de saldo que já filtra pelo almoxarifado do técnico logado
      final response = await GetConnect().get('$_baseEstoque/saldo', headers: _headers);
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['data'] ?? [];
        return lista
            .where((item) => (item['saldo'] ?? 0) > 0)
            .map<Map<String, dynamic>>((item) => {
          'id_produto': item['id_produto']?.toString() ?? '',
          'descricao': item['descricao'] ?? '',
          'saldo': item['saldo'] ?? 0,
          'unidade': item['unidade'] ?? 'UND',
        })
            .toList();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Perfil ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> buscarPerfil() async {
    try {
      final response = await GetConnect().get('$_base/perfil', headers: _headers);
      if (response.statusCode == 200) return response.body['data'] ?? response.body;
      return null;
    } catch (_) { return null; }
  }

  Future<bool> atualizarFotoPerfil(String fotoBase64) async {
    final r = await _http('PUT', '$_base/perfil/foto', {'foto_base64': fotoBase64});
    return r['status'] == 200;
  }

  // ── Almoxarifados de colaboradores (para aprovação) ───────────
  Future<List<Map<String, dynamic>>> buscarAlmoxarifadosColaboradores() async {
    try {
      final response = await GetConnect().get(
        '$_base/almoxarifados-colaboradores',
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['almoxarifados'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Mapeamento EPI → Produto IXC ─────────────────────────────
  Future<List<Map<String, dynamic>>> buscarMapeamentoEpi() async {
    try {
      final response = await GetConnect().get(
        '$_base/produtos-epi',
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['mapeamento'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Ficha de EPI completa (PDF formato BW Telecom) ────────────
  Future<String?> buscarFichaEpi(int tecnicoId) async {
    try {
      final response = await GetConnect().get(
        '$_base/tecnicos/$tecnicoId/ficha-epi',
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return (response.body['data'] ?? response.body)['pdf_base64'] as String?;
      }
      return null;
    } catch (_) { return null; }
  }
  // ── Upload assinatura de admissão ─────────────────────────────
  Future<Map<String, dynamic>> uploadAssinaturaAdmissao(int tecnicoId, String assinaturaBase64) async {
    final r = await _http('PUT', '$_base/tecnicos/$tecnicoId/assinatura-admissao',
        {'assinatura_base64': assinaturaBase64});
    if (r['status'] == 200) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro'};
  }

  // ── Devoluções ────────────────────────────────────────────────
  Future<Map<String, dynamic>> buscarEpisDuplicados() async {
    try {
      final response = await GetConnect().get(
        '$_base/epis-duplicados',
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = response.body['data'] ?? response.body;
        return Map<String, dynamic>.from(data['epis_ativos'] ?? {});
      }
      return {};
    } catch (_) { return {}; }
  }

  Future<Map<String, dynamic>> registrarDevolucao({
    required int requisicaoOriginalId,
    required String epiNome,
    required String assinaturaBase64,
  }) async {
    final r = await _http('POST', '$_base/devolucoes', {
      'requisicao_original_id': requisicaoOriginalId,
      'epi_nome': epiNome,
      'assinatura_base64': assinaturaBase64,
    });
    if (r['status'] == 201) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro'};
  }

  Future<List<Map<String, dynamic>>> buscarDevolucoesPendentes() async {
    try {
      final response = await GetConnect().get('$_base/devolucoes/pendentes', headers: _headers);
      if (response.statusCode == 200) {
        final data = response.body['data'] ?? response.body;
        return List<Map<String, dynamic>>.from(data['devolucoes'] ?? []);
      }
      return [];
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> aprovarDevolucao(int id, String codigoSubst) async {
    final r = await _http('POST', '$_base/devolucoes/$id/aprovar', {'codigo_subst': codigoSubst});
    if (r['status'] == 200) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro'};
  }

  Future<Map<String, dynamic>> recusarDevolucao(int id, {String? observacao}) async {
    final r = await _http('POST', '$_base/devolucoes/$id/recusar', {'observacao': observacao ?? ''});
    if (r['status'] == 200) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro'};
  }

  Future<List<Map<String, dynamic>>> buscarDevedores() async {
    try {
      final response = await GetConnect().get('$_base/devolucoes/devedores', headers: _headers);
      if (response.statusCode == 200) {
        final data = response.body['data'] ?? response.body;
        return List<Map<String, dynamic>>.from(data['devedores'] ?? []);
      }
      return [];
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> buscarMinhasDevolucoes() async {
    try {
      final response = await GetConnect().get('$_base/devolucoes/minhas', headers: _headers);
      if (response.statusCode == 200) {
        final data = response.body['data'] ?? response.body;
        return List<Map<String, dynamic>>.from(data['devolucoes'] ?? []);
      }
      return [];
    } catch (_) { return []; }
  }

  // ── Produtos EPI (cadastro CA/Fornecedor) ─────────────────────
  Future<List<Map<String, dynamic>>> buscarProdutosEpiCadastro() async {
    try {
      final response = await GetConnect().get(
        '$_base/produtos-epi-cadastro',
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List lista = (response.body['data'] ?? response.body)['produtos'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>> atualizarProdutoEpi(int id, {String? ca, String? fornecedor}) async {
    final r = await _http('PUT', '$_base/produtos-epi-cadastro/$id', {
      if (ca != null) 'ca': ca,
      if (fornecedor != null) 'fornecedor': fornecedor,
    });
    if (r['status'] == 200) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro ao atualizar'};
  }

  Future<Map<String, dynamic>> criarProdutoEpi({
    required String nome,
    String? idProdutoIxc,
    String? descricaoIxc,
    String? ca,
    String? fornecedor,
  }) async {
    final r = await _http('POST', '$_base/produtos-epi-cadastro', {
      'nome': nome,
      if (idProdutoIxc != null) 'id_produto_ixc': idProdutoIxc,
      if (descricaoIxc != null) 'descricao_ixc': descricaoIxc,
      'ca': ca ?? 'N/A',
      'fornecedor': fornecedor ?? '',
    });
    if (r['status'] == 201) return {'success': true, 'message': r['body']?['message']};
    return {'success': false, 'message': r['body']?['error'] ?? 'Erro ao cadastrar'};
  }

  Future<Map<String, dynamic>> removerProdutoEpi(int id) async {
    final r = await _http('DELETE', '$_base/produtos-epi-cadastro/$id');
    if (r['status'] == 200) return {'success': true};
    return {'success': false};
  }

}