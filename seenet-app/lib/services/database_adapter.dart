// lib/services/database_adapter.dart - VERSÃO CORRIGIDA
import '../config/environment.dart';
import 'database_helper.dart';
import 'database_helper_postgres.dart';
import '../models/usuario.dart';
import '../models/categoria_checkmark.dart';
import '../models/checkmark.dart';
import '../models/avaliacao.dart';
import '../models/resposta_checkmark.dart';
import '../models/diagnostico.dart';
import '../models/transcricao_tecnica.dart';

/// Adaptador que permite usar SQLite ou PostgreSQL
/// baseado na configuração do ambiente
class DatabaseAdapter {
  static const bool _usePostgreSQL = bool.fromEnvironment('USE_POSTGRESQL', defaultValue: false);
  
  // Singleton pattern
  DatabaseAdapter._privateConstructor();
  static final DatabaseAdapter instance = DatabaseAdapter._privateConstructor();
  
  // Verificar qual banco está sendo usado
  static bool get isUsingPostgreSQL => _usePostgreSQL;
  static bool get isUsingSQLite => !_usePostgreSQL;
  
  // ========== MÉTODOS DE USUÁRIOS ==========
  
  Future<Usuario?> loginUsuario(String email, String senha) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.loginUsuario(email, senha);
    } else {
      return await DatabaseHelper.instance.loginUsuario(email, senha);
    }
  }
  
  Future<bool> criarUsuario(Usuario usuario) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.criarUsuario(usuario);
    } else {
      return await DatabaseHelper.instance.criarUsuario(usuario);
    }
  }
  
  // ✅ ADICIONADO: Métodos que estavam faltando
  Future<void> corrigirUsuarioAdmin() async {
    if (_usePostgreSQL) {
      // Para PostgreSQL, implementar se necessário
      print('⚠️ corrigirUsuarioAdmin não implementado para PostgreSQL ainda');
    } else {
      await DatabaseHelper.instance.corrigirUsuarioAdmin();
    }
  }
  
  Future<void> verificarTodosUsuarios() async {
    if (_usePostgreSQL) {
      // Para PostgreSQL, implementar se necessário
      print('⚠️ verificarTodosUsuarios não implementado para PostgreSQL ainda');
    } else {
      await DatabaseHelper.instance.verificarTodosUsuarios();
    }
  }
  
  Future<void> debugListarUsuarios() async {
    if (_usePostgreSQL) {
      print('⚠️ debugListarUsuarios não implementado para PostgreSQL ainda');
    } else {
      await DatabaseHelper.instance.debugListarUsuarios();
    }
  }
  
  Future<void> debugBuscarUsuario(String email) async {
    if (_usePostgreSQL) {
      print('⚠️ debugBuscarUsuario não implementado para PostgreSQL ainda');
    } else {
      await DatabaseHelper.instance.debugBuscarUsuario(email);
    }
  }
  
  Future<void> debugUltimosUsuarios({int limite = 5}) async {
    if (_usePostgreSQL) {
      print('⚠️ debugUltimosUsuarios não implementado para PostgreSQL ainda');
    } else {
      await DatabaseHelper.instance.debugUltimosUsuarios(limite: limite);
    }
  }
  
  Future<bool> debugEmailExiste(String email) async {
    if (_usePostgreSQL) {
      print('⚠️ debugEmailExiste não implementado para PostgreSQL ainda');
      return false;
    } else {
      return await DatabaseHelper.instance.debugEmailExiste(email);
    }
  }
  
  Future<void> debugEstatisticas() async {
    if (_usePostgreSQL) {
      print('⚠️ debugEstatisticas não implementado para PostgreSQL ainda');
    } else {
      await DatabaseHelper.instance.debugEstatisticas();
    }
  }
  
  // ========== MÉTODOS DE CATEGORIAS ==========
  
  Future<List<CategoriaCheckmark>> getCategorias() async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.getCategorias();
    } else {
      return await DatabaseHelper.instance.getCategorias();
    }
  }
  
  // ========== MÉTODOS DE CHECKMARKS ==========
  
  Future<List<Checkmark>> getCheckmarksPorCategoria(int categoriaId) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.getCheckmarksPorCategoria(categoriaId);
    } else {
      return await DatabaseHelper.instance.getCheckmarksPorCategoria(categoriaId);
    }
  }
  
  Future<bool> criarCheckmark(Checkmark checkmark, int operadorId) async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ criarCheckmark não implementado para PostgreSQL ainda');
      return false;
    } else {
      return await DatabaseHelper.instance.criarCheckmark(checkmark, operadorId);
    }
  }
  
  // ========== MÉTODOS DE AVALIAÇÕES ==========
  
  Future<int?> criarAvaliacao(Avaliacao avaliacao) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.criarAvaliacao(avaliacao);
    } else {
      return await DatabaseHelper.instance.criarAvaliacao(avaliacao);
    }
  }
  
  Future<bool> finalizarAvaliacao(int avaliacaoId) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.finalizarAvaliacao(avaliacaoId);
    } else {
      return await DatabaseHelper.instance.finalizarAvaliacao(avaliacaoId);
    }
  }
  
  // ========== MÉTODOS DE RESPOSTAS ==========
  
  Future<bool> salvarResposta(RespostaCheckmark resposta) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.salvarResposta(resposta);
    } else {
      return await DatabaseHelper.instance.salvarResposta(resposta);
    }
  }
  
  // ========== MÉTODOS DE DIAGNÓSTICOS ==========
  
  Future<bool> salvarDiagnostico(Diagnostico diagnostico) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.salvarDiagnostico(diagnostico);
    } else {
      return await DatabaseHelper.instance.salvarDiagnostico(diagnostico);
    }
  }
  
  Future<bool> salvarDiagnosticoComAuditoria(Diagnostico diagnostico) async {
    if (_usePostgreSQL) {
      // Para PostgreSQL, usar o método normal (já tem auditoria)
      return await DatabaseHelperPostgreSQL.instance.salvarDiagnostico(diagnostico);
    } else {
      return await DatabaseHelper.instance.salvarDiagnosticoComAuditoria(diagnostico);
    }
  }
  
  Future<List<Diagnostico>> getDiagnosticosPorAvaliacao(int avaliacaoId) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.getDiagnosticosPorAvaliacao(avaliacaoId);
    } else {
      return await DatabaseHelper.instance.getDiagnosticosPorAvaliacao(avaliacaoId);
    }
  }
  
  // ========== MÉTODOS DE TRANSCRIÇÕES ==========
  
  Future<bool> salvarTranscricao(TranscricaoTecnica transcricao) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.salvarTranscricao(transcricao);
    } else {
      return await DatabaseHelper.instance.salvarTranscricao(transcricao);
    }
  }
  
  Future<List<TranscricaoTecnica>> getTranscricoesPorTecnico(int tecnicoId) async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.getTranscricoesPorTecnico(tecnicoId);
    } else {
      return await DatabaseHelper.instance.getTranscricoesPorTecnico(tecnicoId);
    }
  }
  
  Future<TranscricaoTecnica?> getTranscricaoPorId(int id) async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ getTranscricaoPorId não implementado para PostgreSQL ainda');
      return null;
    } else {
      return await DatabaseHelper.instance.getTranscricaoPorId(id);
    }
  }
  
  Future<bool> atualizarTranscricao(TranscricaoTecnica transcricao) async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ atualizarTranscricao não implementado para PostgreSQL ainda');
      return false;
    } else {
      return await DatabaseHelper.instance.atualizarTranscricao(transcricao);
    }
  }
  
  Future<bool> removerTranscricao(int id, int operadorId) async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ removerTranscricao não implementado para PostgreSQL ainda');
      return false;
    } else {
      return await DatabaseHelper.instance.removerTranscricao(id, operadorId);
    }
  }
  
  Future<List<TranscricaoTecnica>> buscarTranscricoes({
    int? tecnicoId,
    String? status,
    String? categoria,
    DateTime? dataInicio,
    DateTime? dataFim,
    String? termoBusca,
    int limite = 100,
    int offset = 0,
  }) async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ buscarTranscricoes não implementado para PostgreSQL ainda');
      return [];
    } else {
      return await DatabaseHelper.instance.buscarTranscricoes(
        tecnicoId: tecnicoId,
        status: status,
        categoria: categoria,
        dataInicio: dataInicio,
        dataFim: dataFim,
        termoBusca: termoBusca,
        limite: limite,
        offset: offset,
      );
    }
  }
  
  Future<Map<String, dynamic>> getEstatisticasTranscricoes(int tecnicoId) async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ getEstatisticasTranscricoes não implementado para PostgreSQL ainda');
      return {};
    } else {
      return await DatabaseHelper.instance.getEstatisticasTranscricoes(tecnicoId);
    }
  }
  
  // ========== MÉTODOS DE SEGURANÇA E AUDITORIA ==========
  
  Future<Map<String, dynamic>> verificarIntegridade() async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ verificarIntegridade não implementado para PostgreSQL ainda');
      return {'message': 'Não implementado para PostgreSQL'};
    } else {
      return await DatabaseHelper.instance.verificarIntegridade();
    }
  }
  
  Future<bool> fazerBackup(int operadorId) async {
    if (_usePostgreSQL) {
      // Implementar para PostgreSQL se necessário
      print('⚠️ fazerBackup não implementado para PostgreSQL ainda');
      return false;
    } else {
      return await DatabaseHelper.instance.fazerBackup(operadorId);
    }
  }
  
  // ========== MÉTODOS DE UTILIDADE ==========
  
  Future<bool> testarConexao() async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.testarConexao();
    } else {
      return await DatabaseHelper.instance.testarConexao();
    }
  }
  
  Future<bool> testarConexaoRapida() async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.testarConexao();
    } else {
      return await DatabaseHelper.instance.testarConexaoRapida();
    }
  }
  
  Future<void> verificarEstrutura() async {
    if (_usePostgreSQL) {
      await DatabaseHelperPostgreSQL.instance.verificarEstrutura();
    } else {
      await DatabaseHelper.instance.verificarEstrutura();
    }
  }
  
  Future<void> logoutUsuario(int usuarioId) async {
    if (_usePostgreSQL) {
      await DatabaseHelperPostgreSQL.instance.logoutUsuario(usuarioId);
    } else {
      await DatabaseHelper.instance.logoutUsuario(usuarioId);
    }
  }
  
  Future<void> close() async {
    if (_usePostgreSQL) {
      await DatabaseHelperPostgreSQL.instance.close();
    } else {
      await DatabaseHelper.instance.close();
    }
  }
  
  Future<void> closeDatabase() async {
    if (_usePostgreSQL) {
      await DatabaseHelperPostgreSQL.instance.close();
    } else {
      await DatabaseHelper.instance.closeDatabase();
    }
  }
  
  Future<void> resetDatabase() async {
    if (_usePostgreSQL) {
      print('⚠️ resetDatabase não implementado para PostgreSQL (não é seguro)');
    } else {
      await DatabaseHelper.instance.resetDatabase();
    }
  }
  
  // ========== PROPRIEDADES E GETTERS ==========
  
  // Getter para compatibilidade com código existente
  Future<dynamic> get database async {
    if (_usePostgreSQL) {
      return await DatabaseHelperPostgreSQL.instance.connection;
    } else {
      return await DatabaseHelper.instance.database;
    }
  }
  
  // Debug
  void printInfo() {
    print('🔄 === DATABASE ADAPTER ===');
    print('💾 Banco ativo: ${_usePostgreSQL ? "PostgreSQL" : "SQLite"}');
    print('🌐 Ambiente: ${Environment.isDevelopment ? "DEV" : "PROD"}');
    print('⚠️ Alguns métodos debug só funcionam com SQLite');
    print('=============================');
  }
}