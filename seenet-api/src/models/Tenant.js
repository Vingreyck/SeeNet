const { db } = require('../config/database');

class Tenant {
  static async findByCode(codigo) {
    return await db('tenants')
      .where('codigo', codigo.toUpperCase())
      .where('ativo', true)
      .first();
  }

  static async findById(id) {
    return await db('tenants')
      .where('id', id)
      .first();
  }

  static async getUsers(tenantId, filters = {}) {
    let query = db('usuarios')
      .where('tenant_id', tenantId);

    if (filters.ativo !== undefined) {
      query = query.where('ativo', filters.ativo);
    }

    if (filters.tipo_usuario) {
      query = query.where('tipo_usuario', filters.tipo_usuario);
    }

    return await query.select('*');
  }

  static async getUserCount(tenantId) {
    const result = await db('usuarios')
      .where('tenant_id', tenantId)
      .where('ativo', true)
      .count('id as total')
      .first();
    
    return result.total;
  }

  static async getUsageStats(tenantId, dias = 30) {
    const dataInicio = new Date(Date.now() - (dias * 24 * 60 * 60 * 1000)).toISOString();

    const stats = await db.raw(`
      SELECT 
        COUNT(DISTINCT a.id) as avaliacoes_total,
        COUNT(DISTINCT d.id) as diagnosticos_total,
        COUNT(DISTINCT t.id) as transcricoes_total,
        AVG(d.tokens_utilizados) as tokens_medio,
        SUM(d.tokens_utilizados) as tokens_total
      FROM tenants tn
      LEFT JOIN avaliacoes a ON tn.id = a.tenant_id AND a.data_criacao >= ?
      LEFT JOIN diagnosticos d ON tn.id = d.tenant_id AND d.data_criacao >= ?
      LEFT JOIN transcricoes_tecnicas t ON tn.id = t.tenant_id AND t.data_criacao >= ?
      WHERE tn.id = ?
    `, [dataInicio, dataInicio, dataInicio, tenantId]);

    return stats[0];
  }

  static async checkLimits(tenantId, tipo) {
    const tenant = await this.findById(tenantId);
    if (!tenant) return false;

    const limites = JSON.parse(tenant.limites || '{}');
    
    switch (tipo) {
      case 'usuarios':
        const userCount = await this.getUserCount(tenantId);
        return userCount < (limites.usuarios_max || 5);
      
      case 'api_calls':
        // Implementar verificação de calls por dia
        return true; // Por enquanto sempre permite
      
      default:
        return true;
    }
  }
}

module.exports = Tenant;