const knex = require('knex');
const path = require('path');

const db = knex({
  client: 'sqlite3',
  connection: {
    filename: path.join(__dirname, 'database/seenet.sqlite')
  },
  useNullAsDefault: true
});

async function testTenant() {
  try {
    console.log('🧪 Testando busca de tenants...');
    
    // Teste 1: Listar todos
    const all = await db('tenants').select('*');
    console.log('📊 Todos os tenants:', all);
    
    // Teste 2: Buscar DEMO2024 com diferentes condições
    const demo1 = await db('tenants').where('codigo', 'DEMO2024').first();
    const demo2 = await db('tenants').where('codigo', 'DEMO2024').where('ativo', 1).first();
    const demo3 = await db('tenants').where('codigo', 'DEMO2024').where('ativo', true).first();
    
    console.log('🎯 DEMO2024 (qualquer):', demo1 ? 'ENCONTRADO' : 'NÃO ENCONTRADO');
    console.log('🎯 DEMO2024 (ativo=1):', demo2 ? 'ENCONTRADO' : 'NÃO ENCONTRADO');
    console.log('🎯 DEMO2024 (ativo=true):', demo3 ? 'ENCONTRADO' : 'NÃO ENCONTRADO');
    
    if (demo1) {
      console.log('📋 Dados do DEMO2024:', demo1);
    }
    
    await db.destroy();
    console.log('✅ Teste concluído');
    
  } catch (error) {
    console.error('❌ Erro no teste:', error);
    await db.destroy();
  }
}

testTenant();