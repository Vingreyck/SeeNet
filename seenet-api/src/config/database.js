const knex = require('knex');
const path = require('path');
const logger = require('./logger');

// 🐘 PostgreSQL sempre (dev + produção)
const dbConfig = {
  client: 'pg',
   connection: {
    host: 'db.tcqhyzbkkigukrqniefx.supabase.co',
    port: 5432,
    user: 'postgres',
    password: '1524Br101',
    database: 'postgres',
    ssl: {
      rejectUnauthorized: false
    }
  },
  migrations: {
    directory: path.join(__dirname, '../migrations')
  },
  seeds: {
    directory: path.join(__dirname, '../seeds')
  },
  pool: {
    min: 2,
    max: 10
  }
};

const db = knex(dbConfig);

async function initDatabase() {
  try {
    logger.info('🔌 Conectando ao PostgreSQL...');

    // Testar conexão
    await db.raw('SELECT 1');
    logger.info('✅ Conexão com PostgreSQL estabelecida');

    // Executar migrações
    await db.migrate.latest();
    logger.info('✅ Migrações executadas');

    // Executar seeds apenas em desenvolvimento
    if (process.env.NODE_ENV === 'development') {
      await db.seed.run();
      logger.info('✅ Seeds executados');
    }

    return db;
  } catch (error) {
    logger.error('❌ Erro na inicialização do banco:', error);
    throw error;
  }
}

// Função para verificar qual banco está sendo usado
function getDatabaseInfo() {
  return {
    type: 'PostgreSQL',
    environment: process.env.NODE_ENV || 'development',
    connection: process.env.DATABASE_URL ? 'Connected' : 'Not configured',
    ready: true
  };
}

module.exports = { 
  db, 
  initDatabase,
  getDatabaseInfo
};