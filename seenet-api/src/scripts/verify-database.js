require('dotenv').config();
const knex = require('knex');
const config = require('../../knexfile.js');

async function verify() {
  const env = process.env.NODE_ENV || 'production';
  const db = knex(config[env]);

  try {
    console.log(`\n🔍 Verificando banco (${env})...\n`);

    await db.raw('SELECT 1');
    console.log('✅ Conectado ao Neon\n');

    const migrations = await db('knex_migrations')
      .select('*')
      .orderBy('batch', 'asc');
    
    console.log(`📋 Migrations (${migrations.length}):`);
    migrations.forEach((m, i) => {
      console.log(`  ${i + 1}. ${m.name}`);
    });

    console.log('\n📊 Contagem de Registros:');
    const tenants = await db('tenants').count('* as count').first();
    const usuarios = await db('usuarios').count('* as count').first();
    const categorias = await db('categorias_checkmark').count('* as count').first();
    const checkmarks = await db('checkmarks').count('* as count').first();
    const diagnosticos = await db('diagnosticos').count('* as count').first();
    const logs = await db('logs_sistema').count('* as count').first();

    console.log(`  Tenants: ${tenants.count}`);
    console.log(`  Usuários: ${usuarios.count}`);
    console.log(`  Categorias: ${categorias.count}`);
    console.log(`  Checkmarks: ${checkmarks.count}`);
    console.log(`  Diagnósticos: ${diagnosticos.count}`);
    console.log(`  Logs: ${logs.count}`);

    console.log('\n✅ Verificação completa\n');

  } catch (error) {
    console.error('❌ Erro:', error.message);
  } finally {
    await db.destroy();
  }
}

verify();