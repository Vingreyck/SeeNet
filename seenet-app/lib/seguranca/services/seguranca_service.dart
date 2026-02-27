import 'package:get/get.dart';
import 'package:seenet/services/auth_service.dart';
import 'dart:convert';

class SegurancaService extends GetxService {
  final AuthService _authService = Get.find<AuthService>();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${_authService.token}',
    'X-Tenant-Code': _authService.tenantCode ?? '',
  };

  String get _base => 'https://seenet-production.up.railway.app/api/seguranca';

  // ========== EPIs disponíveis ==========
  Future<List<String>> buscarEpis() async {
    try {
      final response = await GetConnect().get('$_base/epis', headers: _headers);
      if (response.statusCode == 200) {
        final List epis = response.body['epis'] ?? [];
        return epis.cast<String>();
      }
      return _episPadrao();
    } catch (_) {
      return _episPadrao();
    }
  }

  List<String> _episPadrao() => [
    'Capacete de Segurança (Classe B)',
    'Carneira e Jugular',
    'Balaclava',
    'Óculos de Segurança',
    'Luva de Segurança (Isolante)',
    'Luva de Vaqueta',
    'Cinto de Segurança',
    'Talabarte de Posicionamento',
    'Trava-Quedas',
    'Detector de Tensão',
    'Cones de Sinalização',
    'Fita e/ou Corrente Zebrada',
  ];

  // ========== Criar requisição ==========
  Future<Map<String, dynamic>> criarRequisicao({
    required List<String> episSolicitados,
    required String assinaturaBase64,
    required String fotoBase64,
  }) async {
    final response = await GetConnect().post(
      '$_base/requisicoes',
      {
        'epis_solicitados': episSolicitados,
        'assinatura_base64': assinaturaBase64,
        'foto_base64': fotoBase64,
      },
      headers: _headers,
    );

    if (response.statusCode == 201) {
      return {'success': true, 'message': response.body['message']};
    }
    return {
      'success': false,
      'message': response.body['error'] ?? 'Erro ao enviar requisição'
    };
  }

  // ========== Minhas requisições ==========
  Future<List<Map<String, dynamic>>> buscarMinhasRequisicoes() async {
    try {
      final response =
      await GetConnect().get('$_base/requisicoes/minhas', headers: _headers);
      if (response.statusCode == 200) {
        final List lista = response.body['requisicoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ========== Listar técnicos (para gestor) ==========
  Future<List<Map<String, dynamic>>> buscarTecnicos() async {
    try {
      final response =
      await GetConnect().get('$_base/tecnicos', headers: _headers);
      if (response.statusCode == 200) {
        final List lista = response.body['tecnicos'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ========== Criar registro manual (gestor) ==========
  Future<Map<String, dynamic>> criarRegistroManual({
    required int tecnicoId,
    required List<String> episSolicitados,
    String? assinaturaBase64,
    String? fotoBase64,
    String? observacao,
    DateTime? dataEntrega,
  }) async {
    final response = await GetConnect().post(
      '$_base/requisicoes/manual',
      {
        'tecnico_id': tecnicoId,
        'epis_solicitados': episSolicitados,
        if (assinaturaBase64 != null) 'assinatura_base64': assinaturaBase64,
        if (fotoBase64 != null) 'foto_base64': fotoBase64,
        if (observacao != null) 'observacao_gestor': observacao,
        'data_entrega': (dataEntrega ?? DateTime.now()).toIso8601String(),
      },
      headers: _headers,
    );

    if (response.statusCode == 201) {
      return {'success': true, 'message': response.body['message']};
    }
    return {
      'success': false,
      'message': response.body['error'] ?? 'Erro ao criar registro'
    };
  }

  // ========== Buscar PDF ==========
  Future<String?> buscarPdf(int id) async {
    try {
      final response = await GetConnect()
          .get('$_base/requisicoes/$id/pdf', headers: _headers);
      if (response.statusCode == 200) {
        return response.body['pdf_base64'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ========== Requisições pendentes (gestor/admin) ==========
  Future<List<Map<String, dynamic>>> buscarPendentes() async {
    try {
      final response = await GetConnect()
          .get('$_base/requisicoes/pendentes', headers: _headers);
      if (response.statusCode == 200) {
        final List lista = response.body['requisicoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ========== Todas as requisições (gestor/admin) ==========
  Future<List<Map<String, dynamic>>> buscarTodas({String? status}) async {
    try {
      final url =
      status != null ? '$_base/requisicoes?status=$status' : '$_base/requisicoes';
      final response = await GetConnect().get(url, headers: _headers);
      if (response.statusCode == 200) {
        final List lista = response.body['requisicoes'] ?? [];
        return lista.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ========== Detalhe ==========
  Future<Map<String, dynamic>?> buscarDetalhe(int id) async {
    try {
      final response =
      await GetConnect().get('$_base/requisicoes/$id', headers: _headers);
      if (response.statusCode == 200) {
        return response.body['requisicao'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ========== Aprovar ==========
  Future<Map<String, dynamic>> aprovar(int id, {String? observacao}) async {
    final response = await GetConnect().post(
      '$_base/requisicoes/$id/aprovar',
      {'observacao': observacao ?? ''},
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return {'success': true, 'message': response.body['message']};
    }
    return {
      'success': false,
      'message': response.body['error'] ?? 'Erro ao aprovar'
    };
  }

  // ========== Recusar ==========
  Future<Map<String, dynamic>> recusar(int id, {required String observacao}) async {
    final response = await GetConnect().post(
      '$_base/requisicoes/$id/recusar',
      {'observacao': observacao},
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return {'success': true, 'message': response.body['message']};
    }
    return {
      'success': false,
      'message': response.body['error'] ?? 'Erro ao recusar'
    };
  }

  // ========== Perfil ==========
  Future<Map<String, dynamic>?> buscarPerfil() async {
    try {
      final response =
      await GetConnect().get('$_base/perfil', headers: _headers);
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ========== Atualizar foto de perfil ==========
  Future<bool> atualizarFotoPerfil(String fotoBase64) async {
    final response = await GetConnect().put(
      '$_base/perfil/foto',
      {'foto_base64': fotoBase64},
      headers: _headers,
    );
    return response.statusCode == 200;
  }
}