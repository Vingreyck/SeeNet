const express = require('express');
const { db } = require('../config/database');

const router = express.Router();

console.log('🔍 Carregando rotas de tenant...');

// ========== VERIFICAR CÓDIGO DA EMPRESA ==========
router.get('/verify/:codigo', async (req, res) => {
  try {
    const { codigo } = req.params;
    const codigoUpper = codigo.toUpperCase();
    
    console.log(`🔍 Verificando código da empresa: "${codigo}" -> "${codigoUpper}"`);

    // CORRIGIDO: Usar ativo = 1 (SQLite usa integer para boolean)
    const tenant = await db('tenants')
      .where('codigo', codigoUpper)
      .where('ativo', 1) // ← MUDOU: true para 1
      .select('id', 'nome', 'codigo', 'plano', 'descricao') // ← ADICIONADO: id
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

    // Contar usuários ativos (opcional - pode remover por enquanto)
    let usuariosAtivos = 0;
    try {
      const userCount = await db('usuarios')
        .where('tenant_id', tenant.id)
        .where('ativo', 1) // ← MUDOU: true para 1
        .count('id as total')
        .first();
      usuariosAtivos = userCount?.total || 0;
    } catch (userError) {
      console.log('⚠️ Tabela usuarios ainda não existe:', userError.message);
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
    console.error('❌ Erro ao verificar tenant:', error); // ← MUDOU: logger para console
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

    const tenants = await db('tenants')
      .where('ativo', 1) // ← MUDOU: true para 1
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

console.log('✅ Rotas de tenant carregadas');

module.exports = router;
