const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

async function backupNeon() {
  console.log('🔄 Iniciando backup do banco Neon...\n');
  
  require('dotenv').config({ path: '.env.development' });
  
  // Construir connection string das variáveis do Railway
  const connectionString = `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`;
  
  console.log(`📡 Conectando em: ${process.env.DB_HOST}/${process.env.DB_NAME}\n`);
  
  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });
  
  try {
    await client.connect();
    console.log('✅ Conectado com sucesso!\n');
    
    // Listar todas as tabelas
    const tabelas = await client.query(`
      SELECT tablename 
      FROM pg_tables 
      WHERE schemaname = 'public'
      ORDER BY tablename
    `);
    
    console.log(`📊 Encontradas ${tabelas.rows.length} tabelas:\n`);
    tabelas.rows.forEach(t => console.log(`   - ${t.tablename}`));
    console.log();
    
    let backup = `-- ============================================\n`;
    backup += `-- Backup SeeNet Database\n`;
    backup += `-- Data: ${new Date().toISOString()}\n`;
    backup += `-- Tabelas: ${tabelas.rows.length}\n`;
    backup += `-- ============================================\n\n`;
    
    // Fazer backup de cada tabela
    for (const { tablename } of tabelas.rows) {
      console.log(`📦 Exportando: ${tablename}...`);
      
      const dados = await client.query(`SELECT * FROM ${tablename}`);
      const qtd = dados.rows.length;
      console.log(`   ✅ ${qtd} registro(s)\n`);
      
      backup += `\n-- ============================================\n`;
      backup += `-- Tabela: ${tablename} (${qtd} registros)\n`;
      backup += `-- ============================================\n\n`;
      
      if (qtd > 0) {
        backup += `TRUNCATE TABLE ${tablename} CASCADE;\n\n`;
        
        for (const row of dados.rows) {
          const cols = Object.keys(row);
          const vals = cols.map(c => {
            const val = row[c];
            if (val === null) return 'NULL';
            if (typeof val === 'string') return `'${val.replace(/'/g, "''")}'`;
            if (val instanceof Date) return `'${val.toISOString()}'`;
            if (typeof val === 'boolean') return val ? 'true' : 'false';
            if (typeof val === 'object') return `'${JSON.stringify(val).replace(/'/g, "''")}'`;
            return val;
          });
          
          backup += `INSERT INTO ${tablename} (${cols.join(', ')}) VALUES (${vals.join(', ')});\n`;
        }
        
        backup += '\n';
      }
    }
    
    // Salvar arquivo
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 19);
    const filename = `backup_seenet_${timestamp}.sql`;
    const filepath = path.join(__dirname, '..', filename);
    
    fs.writeFileSync(filepath, backup, 'utf8');
    
    const size = (fs.statSync(filepath).size / 1024 / 1024).toFixed(2);
    
    console.log('\n' + '='.repeat(50));
    console.log('🎉 BACKUP CONCLUÍDO COM SUCESSO!');
    console.log('='.repeat(50));
    console.log(`📁 Arquivo: ${filename}`);
    console.log(`📊 Tamanho: ${size} MB`);
    console.log(`📍 Local: ${filepath}`);
    console.log('='.repeat(50) + '\n');
    
  } catch (error) {
    console.error('\n❌ ERRO ao fazer backup:', error.message);
    console.error('\nDetalhes:', error);
  } finally {
    await client.end();
  }
}

backupNeon();