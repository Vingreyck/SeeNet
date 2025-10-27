const knex = require('knex');
const winston = require('winston');
const path = require('path');
require('dotenv').config();

// Logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'seenet-api' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// CONFIGURAÇÃO POSTGRESQL COM CAMINHOS DE MIGRAÇÃO
const dbConfig = {
  client: 'pg',
  connection: {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 5432,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: { rejectUnauthorized: false }
  },
  migrations: {
    directory: path.join(__dirname, '../migrations') // Ajuste o caminho relativo
  },
  seeds: {
    directory: path.join(__dirname, '../seeds')
  },
  pool: { min: 0, max: 7 },
  acquireConnectionTimeout: 60000,
};

let db = null;

async function initDatabase() {
  logger.info('🔌 Conectando ao PostgreSQL...');
  
  
  try {
    db = knex(dbConfig);
    
    // Testar conexão
    await db.raw('SELECT NOW()');
    logger.info('✅ Conexão com PostgreSQL estabelecida');
    
    // Executar migrações
    try {
      logger.info('🔄 Executando migrações...');
      const [batchNo, migrationsList] = await db.migrate.latest();
      if (migrationsList.length === 0) {
        logger.info('ℹ️ Nenhuma migração pendente');
      } else {
        logger.info(`✅ Migrações executadas - Batch ${batchNo}:`, migrationsList);
      }
    } catch (migrationError) {
      logger.error('❌ Erro nas migrações:', migrationError.message);
      throw migrationError;
    }
    
    // Executar seeds
    try {
      logger.info('🌱 Executando seeds...');
      await db.seed.run();
      logger.info('✅ Seeds executados');
    } catch (seedError) {
      logger.warn('⚠️ Erro nos seeds:', seedError.message);
    }
    
    return db;
  } catch (error) {
    logger.error('❌ Falha ao conectar com PostgreSQL:');
    logger.error('Mensagem:', error.message);
    logger.error('Código:', error.code);
    throw error;
  }
}

async function closeDatabase() {
  if (db) {
    await db.destroy();
    logger.info('🔒 Conexão PostgreSQL fechada');
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  await closeDatabase();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await closeDatabase();
  process.exit(0);
});

module.exports = {
  initDatabase,
  closeDatabase,
  get db() {
    if (!db) {
      throw new Error('Database not initialized. Call initDatabase() first.');
    }
    return db;
  }
};