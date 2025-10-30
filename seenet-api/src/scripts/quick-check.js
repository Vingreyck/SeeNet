const { Client } = require('pg');

async function check() {
  console.log('\n🔍 Verificando banco de dados Neon...\n');
  
  const client = new Client({
    host: 'ep-fragrant-hall-ac21xf1e-pooler.sa-east-1.aws.neon.tech',
    port: 5432,
    user: 'neondb_owner',
    password: 'npg_YJW0ycmUdj4h',
    database: 'neondb',
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    await client.connect();
    console.log('✅ Conectado ao Neon\n');

    console.log('📊 Contagem de Registros:');
    
    const tenants = await client.query('SELECT COUNT(*) FROM tenants');
    console.log(`  Tenants: ${tenants.rows[0].count}`);
    
    const usuarios = await client.query('SELECT COUNT(*) FROM usuarios');
    console.log(`  Usuários: ${usuarios.rows[0].count}`);
    
    const categorias = await client.query('SELECT COUNT(*) FROM categorias_checkmark');
    console.log(`  Categorias: ${categorias.rows[0].count}`);
    
    const checkmarks = await client.query('SELECT COUNT(*) FROM checkmarks');
    console.log(`  Checkmarks: ${checkmarks.rows[0].count}`);
    
    const diagnosticos = await client.query('SELECT COUNT(*) FROM diagnosticos');
    console.log(`  Diagnósticos: ${diagnosticos.rows[0].count}`);
    
    const logs = await client.query('SELECT COUNT(*) FROM logs_sistema');
    console.log(`  Logs: ${logs.rows[0].count}`);

    // Últimos checkmarks
    console.log('\n📝 Últimos 10 checkmarks criados:');
    const last = await client.query(
      `SELECT id, titulo, tenant_id, 
              TO_CHAR(data_criacao, 'DD/MM/YYYY HH24:MI') as data 
       FROM checkmarks 
       ORDER BY data_criacao DESC 
       LIMIT 10`
    );
    
    last.rows.forEach(c => {
      console.log(`  - ID ${c.id} (tenant ${c.tenant_id}): ${c.titulo} - ${c.data}`);
    });

    // Diagnósticos recentes
    console.log('\n🔬 Últimos 5 diagnósticos:');
    const diags = await client.query(
      `SELECT id, tenant_id, 
              TO_CHAR(created_at, 'DD/MM/YYYY HH24:MI') as data 
       FROM diagnosticos 
       ORDER BY created_at DESC 
       LIMIT 5`
    );
    
    if (diags.rows.length > 0) {
      diags.rows.forEach(d => {
        console.log(`  - ID ${d.id} (tenant ${d.tenant_id}) - ${d.data}`);
      });
    } else {
      console.log('  (Nenhum diagnóstico gerado ainda)');
    }

    console.log('\n✅ Verificação completa!\n');

  } catch (error) {
    console.error('❌ Erro:', error.message);
  } finally {
    await client.end();
  }
}

check();