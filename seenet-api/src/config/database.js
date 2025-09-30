const knex = require('knex');
const winston = require('winston');
const dns = require('dns').promises;
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

let db = null;

// Função para resolver hostname para IPv4
async function resolveIPv4(hostname) {
  try {
    logger.info(`🔍 Resolvendo ${hostname} para IPv4...`);
    const addresses = await dns.resolve4(hostname);
    const ipv4 = addresses[0];
    logger.info(`✅ IPv4 resolvido: ${ipv4}`);
    return ipv4;
  } catch (error) {
    logger.error(`❌ Erro ao resolver IPv4 para ${hostname}:`, error.message);
    throw error;
  }
}

async function initDatabase() {
  logger.info('🔌 Conectando ao PostgreSQL...');
  
  try {
    const originalHost = process.env.DB_HOST || 'db.tcqhyzbkkigukrqniefx.supabase.co';
    
    // Resolver o hostname para IPv4 antes de conectar
    const ipv4Host = await resolveIPv4(originalHost);
    
    // CONFIGURAÇÃO POSTGRESQL COM IPv4 DIRETO
    const dbConfig = {
      client: 'pg',
      connection: {
        host: ipv4Host, // Usando o IP direto ao invés do hostname
        port: parseInt(process.env.DB_PORT) || 5432,
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || '1524Br101',
        database: process.env.DB_NAME || 'postgres',
        ssl: { rejectUnauthorized: false }
      },
      pool: { 
        min: 0, 
        max: 7
      },
      acquireConnectionTimeout: 60000,
    };
    
    db = knex(dbConfig);
    
    // Testar conexão
    await db.raw('SELECT NOW()');
    
    logger.info(`✅ Conexão com PostgreSQL estabelecida via IPv4 (${ipv4Host})`);
    
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
    logger.error('Stack:', error.stack);
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