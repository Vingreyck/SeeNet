const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });
const { Client } = require('pg');

async function check() {
  console.log('\n🔍 Verificando banco de dados...\n');
  
  // Debug: verificar se variáveis foram carregadas
  console.log('🔧 Configuração:');
  console.log(`  Host: ${process.env.DB_HOST || 'NÃO DEFINIDO'}`);
  console.log(`  Database: ${process.env.DB_NAME || 'NÃO DEFINIDO'}`);
  console.log(`  User: ${process.env.DB_USER || 'NÃO DEFINIDO'}`);
  console.log('');
  
  if (!process.env.DB_HOST || !process.env.DB_USER) {
    console.error('❌ Variáveis de ambiente não carregadas!');
    console.error('Verifique se o arquivo .env existe na raiz do projeto.');
    return;
  }
  
  const client = new Client({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 5432,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: {
      rejectUnauthorized: false
    }
  });

  try {
    await client.connect();
    console.log('✅ Conectado ao Neon\n');

    // Contar registros
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

    // Últimos checkmarks criados
    console.log('\n📝 Últimos 5 checkmarks:');
    const lastCheckmarks = await client.query(
      'SELECT id, titulo, data_criacao FROM checkmarks ORDER BY id DESC LIMIT 5'
    );
    lastCheckmarks.rows.forEach(c => {
      const data = c.data_criacao ? new Date(c.data_criacao).toLocaleDateString() : 'N/A';
      console.log(`  - ID ${c.id}: ${c.titulo} (${data})`);
    });

    console.log('\n✅ Verificação completa\n');

  } catch (error) {
    console.error('❌ Erro:', error.message);
  } finally {
    await client.end();
  }
}

check();