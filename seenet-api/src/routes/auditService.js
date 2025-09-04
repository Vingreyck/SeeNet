const { db } = require('../config/database');
const logger = require('../config/logger');

class AuditService {
  async log({ action, usuario_id, tenant_id, tabela_afetada, registro_id, dados_anteriores, dados_novos, details, ip_address }) {
    try {
      await db('logs_sistema').insert({
        tenant_id,
        usuario_id,
        acao: action,
        nivel: this.determinarNivel(action),
        tabela_afetada,
        registro_id,
        dados_anteriores: dados_anteriores ? JSON.stringify(dados_anteriores) : null,
        dados_novos: dados_novos ? JSON.stringify(dados_novos) : null,
        ip_address,
        detalhes: details,
        data_acao: new Date().toISOString()
      });

      logger.info(`📝 AUDIT [${action}] Tenant: ${tenant_id} User: ${usuario_id}`);
    } catch (error) {
      logger.error('Erro ao registrar log de auditoria:', error);
    }
  }

  determinarNivel(action) {
    const errorActions = ['LOGIN_FAILED', 'DIAGNOSTIC_FAILED', 'TRANSCRIPTION_FAILED'];
    const warningActions = ['USER_DELETED', 'CATEGORY_DELETED', 'CHECKMARK_DELETED'];
    
    if (errorActions.includes(action)) return 'error';
    if (warningActions.includes(action)) return 'warning';
    return 'info';
  }

  async getLogsDoTenant(tenantId, filtros = {}) {
    let query = db('logs_sistema')
      .where('tenant_id', tenantId);

    if (filtros.usuario_id) {
      query = query.where('usuario_id', filtros.usuario_id);
    }

    if (filtros.acao) {
      query = query.where('acao', filtros.acao);
    }

    if (filtros.nivel) {
      query = query.where('nivel', filtros.nivel);
    }

    if (filtros.data_inicio) {
      query = query.where('data_acao', '>=', filtros.data_inicio);
    }

    if (filtros.data_fim) {
      query = query.where('data_acao', '<=', filtros.data_fim);
    }

    return await query
      .orderBy('data_acao', 'desc')
      .limit(filtros.limit || 100)
      .offset(filtros.offset || 0);
  }
}

module.exports = new AuditService();