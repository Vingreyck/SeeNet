const express = require('express');
// MUDANÇA: Não importar db diretamente
// const { db } = require('../config/database'); ← REMOVER

const router = express.Router();

console.log('🔍 Carregando rotas de tenant...');

// Função auxiliar para acessar db
function getDb() {
  const { db } = require('../config/database');
  return db;
}


// ========== VERIFICAR CÓDIGO DA EMPRESA ==========
router.get('/verify/:codigo', async (req, res) => {
  try {
    const { codigo } = req.params;
    const codigoUpper = codigo.toUpperCase();
    
    console.log(`🔍 Verificando código da empresa: "${codigo}" -> "${codigoUpper}"`);

    const db = getDb(); // Acessar db apenas quando necessário

    const tenant = await db('tenants')
      .where('codigo', codigoUpper)
      .where('ativo', true)
      .select('id', 'nome', 'codigo', 'plano', 'descricao')
      .first();

    if (!tenant) {
      console.log(`❌ Empresa não encontrada: ${codigoUpper}`);
      
      // Debug: Mostrar o que existe na tabela
      const allTenants = await db('tenants').select('codigo', 'ativo');
      console.log('📊 Empresas disponíveis:', allTenants);
      
      return res.status(404).json({ 
        error: 'Código da empresa não encontrado ou empresa inativa',
        codigo_procurado: codigoUpper,
        debug: allTenants
      });
    }

    console.log(`✅ Empresa encontrada: ${tenant.nome}`);

    // Contar usuários ativos
    let usuariosAtivos = 0;
    try {
      const userCount = await db('usuarios')
        .where('tenant_id', tenant.id)
        .where('ativo', true)
        .count('id as total')
        .first();
      usuariosAtivos = parseInt(userCount?.total) || 0;
    } catch (userError) {
      console.log('⚠️ Erro ao contar usuários:', userError.message);
      usuariosAtivos = 0;
    }

    res.json({
      empresa: {
        nome: tenant.nome,
        codigo: tenant.codigo,
        plano: tenant.plano,
        descricao: tenant.descricao || null,
        usuarios_ativos: usuariosAtivos
      }
    });

  } catch (error) {
    console.error('❌ Erro ao verificar tenant:', error);
    res.status(500).json({ 
      error: 'Erro interno do servidor',
      details: error.message 
    });
  }
});

// ========== LISTAR TODAS AS EMPRESAS ==========
router.get('/list', async (req, res) => {
  try {
    console.log('📊 Listando todas as empresas...');

    const db = getDb();

    const tenants = await db('tenants')
      .where('ativo', true)
      .select('nome', 'codigo', 'plano', 'descricao');

    console.log(`📊 Encontradas ${tenants.length} empresas ativas`);

    res.json({
      empresas: tenants,
      total: tenants.length
    });

  } catch (error) {
    console.error('❌ Erro ao listar tenants:', error);
    res.status(500).json({ 
      error: 'Erro interno do servidor',
      details: error.message
    });
  }
});

// ========== DEBUG ==========
router.get('/debug', async (req, res) => {
  try {
    const db = getDb();
    const result = await db.raw('SELECT * FROM tenants LIMIT 5');
    res.json({
      success: true,
      tenants: result.rows,
      query_test: 'PostgreSQL OK'
    });
  } catch (error) {
    res.json({
      success: false,
      error: error.message
    });
  }
});

console.log('✅ Rotas de tenant carregadas');

module.exports = router;