const knex = require('knex');
const winston = require('winston');
const dns = require('dns');
require('dotenv').config();

// 🔧 FORÇAR IPv4 GLOBALMENTE
dns.setDefaultResultOrder('ipv4first');

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

// CONFIGURAÇÃO POSTGRESQL COM FORÇAMENTO IPv4
const dbConfig = {
  client: 'pg',
  connection: {
    host: process.env.DB_HOST || 'db.tcqhyzbkkigukrqniefx.supabase.co',
    port: parseInt(process.env.DB_PORT) || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '1524Br101',
    database: process.env.DB_NAME || 'postgres',
    ssl: { rejectUnauthorized: false }
  },
  pool: { 
    min: 0, 
    max: 7,
    // Configuração customizada de criação de conexão
    afterCreate: (conn, done) => {
      // Força keep-alive para conexões mais estáveis
      conn.connection.setKeepAlive(true);
      done(null, conn);
    }
  },
  acquireConnectionTimeout: 60000,
  // Driver customizado para forçar IPv4
  connection: {
    host: process.env.DB_HOST || 'db.tcqhyzbkkigukrqniefx.supabase.co',
    port: parseInt(process.env.DB_PORT) || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || '1524Br101',
    database: process.env.DB_NAME || 'postgres',
    ssl: { rejectUnauthorized: false },
    // Opções do driver pg para forçar IPv4
    options: {
      lookup: (hostname, options, callback) => {
        dns.lookup(hostname, { family: 4 }, callback);
      }
    }
  }
};

let db = null;

async function initDatabase() {
  logger.info('🔌 Conectando ao PostgreSQL...');
  
  try {
    db = knex(dbConfig);
    
    // Testar conexão
    await db.raw('SELECT NOW()');
    
    logger.info('✅ Conexão com PostgreSQL estabelecida via IPv4');
    
    // Executar migrações
    try {
      logger.info('🔄 Executando migrações...');
      await db.migrate.latest();
      logger.info('✅ Migrações executadas');
    } catch (migrationError) {
      logger.warn('⚠️ Erro nas migrações (pode ser normal):', migrationError.message);
    }
    
    // Executar seeds
    try {
      logger.info('🌱 Executando seeds...');
      await db.seed.run();
      logger.info('✅ Seeds executados');
    } catch (seedError) {
      logger.warn('⚠️ Erro nos seeds (pode ser normal):', seedError.message);
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