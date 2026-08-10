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
  connection: process.env.DATABASE_URL || {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT) || 5432,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DATABASE_URL?.includes('sslmode=disable') 
      ? false 
      : { rejectUnauthorized: false }
  },
  migrations: {
    directory: path.join(__dirname, '../migrations')
  },
  seeds: {
    directory: path.join(__dirname, '../seeds')
  },
  pool: {
    min: 2,
    // max 25: processo único no Railway = 1 pool só. max_connections do
    // Postgres é 100, então sobra folga grande (~70) para sessões psql,
    // sync do IXC e o reserved do superusuário. Ajuda no pico de 50 usuários
    // (principalmente nas finalizações de OS, que são pesadas).
    max: 25,
    acquireTimeoutMillis: 30000,
    idleTimeoutMillis: 600000,
  },
  acquireConnectionTimeout: 60000,
};

let db = null;

async function initDatabase() {
  logger.info('\n=== 🔌 INICIANDO BANCO DE DADOS ===');
  
  // Log da configuração (omitindo dados sensíveis)
  logger.info('Configuração do banco:', {
    host: dbConfig.connection.host,
    port: dbConfig.connection.port,
    database: dbConfig.connection.database,
    ssl: !!dbConfig.connection.ssl,
    pool: dbConfig.pool,
    migrationsPath: dbConfig.migrations.directory,
    seedsPath: dbConfig.seeds.directory
  });
  
  try {
    db = knex(dbConfig);
    
    // Testar conexão
    await db.raw('SELECT NOW()');
    logger.info('✅ Conexão com PostgreSQL estabelecida');
    
    // Executar migrações
    try {
      // Executar e logar migrações
      logger.info('\n=== 🔄 VERIFICANDO MIGRAÇÕES ===');

      // ⏱️ Watchdog. O boot já ficou PENDURADO aqui (deploys de 10/ago), sem
      // erro nenhum, até o healthcheck do Railway (120s) matar o container —
      // e "silêncio" não diz se travou ou se morreu. O knex pega o lock com
      // `UPDATE knex_migrations_lock SET is_locked=1 WHERE is_locked=0`; se
      // uma conexão ZUMBI de um deploy anterior (morto no meio da migration)
      // ainda segurar essa linha, o UPDATE espera pra sempre.
      // Aqui a espera vira uma mensagem clara, com o comando pra destravar.
      const TIMEOUT_MIGRACAO_MS = 60000;
      let alarme;
      const [batchNo, migrationsList] = await Promise.race([
        db.migrate.latest(),
        new Promise((_, reject) => {
          alarme = setTimeout(() => reject(new Error(
            `Migrações travadas há ${TIMEOUT_MIGRACAO_MS / 1000}s. Causa provável: ` +
            'a linha de knex_migrations_lock está presa por uma conexão de um ' +
            'deploy anterior que foi morto no meio da migração.\n' +
            'Para destravar, no psql:\n' +
            "  SELECT pg_terminate_backend(pid) FROM pg_stat_activity\n" +
            "   WHERE datname='seenet_production' AND state='idle in transaction'\n" +
            "     AND state_change < now() - interval '2 minutes';\n" +
            '  UPDATE knex_migrations_lock SET is_locked = 0;'
          )), TIMEOUT_MIGRACAO_MS);
        }),
      ]).finally(() => clearTimeout(alarme));

      if (migrationsList.length === 0) {
        logger.info('Nenhuma migração pendente', {
          currentBatch: batchNo,
          timestamp: new Date().toISOString()
        });
      } else {
        logger.info('Migrações executadas com sucesso', {
          batch: batchNo,
          count: migrationsList.length,
          migrations: migrationsList,
          timestamp: new Date().toISOString()
        });
      }
    } catch (migrationError) {
      // ⚠️ console.error ANTES do logger: o logger (winston) é assíncrono e o
      // `throw` abaixo derruba o processo — a mensagem pode nunca chegar a ser
      // gravada. Foi o que fez os deploys de 10/ago parecerem "travados sem
      // erro". console.error é síncrono e sempre aparece no log do Railway.
      console.error('❌ FALHA NAS MIGRAÇÕES:', migrationError.message);
      if (migrationError.code) console.error('   código:', migrationError.code);
      console.error(migrationError.stack);

      logger.error('Erro ao executar migrações', {
        error: {
          message: migrationError.message,
          code: migrationError.code,
          stack: migrationError.stack
        },
        timestamp: new Date().toISOString()
      });
      throw migrationError;
    }
    
    // Executar seeds
    try {
      logger.info('\n=== 🌱 EXECUTANDO SEEDS ===');
      const seedResults = await db.seed.run();
      
      logger.info('Seeds executados com sucesso', {
        seedFiles: seedResults.map(r => r.file),
        count: seedResults.length,
        timestamp: new Date().toISOString()
      });
    } catch (seedError) {
      logger.warn('Erro ao executar seeds', {
        error: {
          message: seedError.message,
          code: seedError.code
        },
        timestamp: new Date().toISOString()
      });
      // Não lançar erro para seeds, pois não são críticos
    }
    
    return db;
  } catch (error) {
    logger.error('\n=== ❌ ERRO CRÍTICO NO BANCO DE DADOS ===', {
      error: {
        type: error.constructor.name,
        message: error.message,
        code: error.code,
        stack: error.stack
      },
      context: {
        host: dbConfig.connection.host,
        database: dbConfig.connection.database,
        timestamp: new Date().toISOString()
      }
    });
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