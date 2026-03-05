// MUDANÇA: Não importar db diretamente
// const { db } = require('../config/database'); ← REMOVER ESTA LINHA

class Tenant {
  // Função auxiliar para acessar o db quando necessário
  static getDb() {
    const { db } = require('../config/database');
    return db;
  }

  static async findByCode(codigo) {
    console.log('🔍 Buscando tenant com código:', codigo?.toUpperCase());
    
    try {
      const db = this.getDb(); // Acessar db apenas quando necessário
      
      const result = await db('tenants')
        .select('id', 'nome', 'codigo', 'plano', 'descricao', 'ativo')
        .where('codigo', codigo.toUpperCase())
        .where('ativo', true)
        .first();
        
      console.log('🔍 Resultado da busca:', result);
      return result;
    } catch (error) {
      console.error('❌ Erro ao buscar tenant:', error.message);
      throw error;
    }
  }

  static async findById(id) {
    try {
      const db = this.getDb();
      
      return await db('tenants')
        .select('*')
        .where('id', id)
        .first();
    } catch (error) {
      console.error('❌ Erro ao buscar tenant por ID:', error.message);
      throw error;
    }
  }

  static async getUsers(tenantId, filters = {}) {
    const db = this.getDb();
    
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
    const db = this.getDb();
    
    const result = await db('usuarios')
      .where('tenant_id', tenantId)
      .where('ativo', true)
      .count('id as total')
      .first();
    
    return parseInt(result.total);
  }

  static async getAllTenants() {
    try {
      const db = this.getDb();
      
      const tenants = await db('tenants').select('*');
      console.log('📊 Todos os tenants:', tenants);
      return tenants;
    } catch (error) {
      console.error('❌ Erro ao buscar todos os tenants:', error.message);
      throw error;
    }
  }

  static async testConnection() {
    try {
      const db = this.getDb();
      
      const result = await db.raw('SELECT NOW() as current_time');
      console.log('✅ Conexão PostgreSQL OK:', result.rows[0]);
      return true;
    } catch (error) {
      console.error('❌ Erro de conexão PostgreSQL:', error.message);
      return false;
    }
  }
  static async checkLimits(tenantId, feature) {
    // TODO: Implementar limites por plano
    return true;
  }

}

module.exports = Tenant;