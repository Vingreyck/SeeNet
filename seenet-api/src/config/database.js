const knex = require('knex');
const path = require('path');
const logger = require('./logger');

const dbConfig = {
  client: 'sqlite3',
  connection: {
    filename: path.join(__dirname, '../../database/seenet.sqlite')
  },
  useNullAsDefault: true,
  migrations: {
    directory: path.join(__dirname, '../migrations')
  },
  seeds: {
    directory: path.join(__dirname, '../seeds')
  },
  pool: {
    afterCreate: (conn, done) => {
      // Habilitar foreign keys no SQLite
      conn.run('PRAGMA foreign_keys = ON', done);
    }
  }
};

const db = knex(dbConfig);

async function initDatabase() {
  try {
    // Criar diretório do banco se não existir
    const fs = require('fs');
    const dbDir = path.dirname(dbConfig.connection.filename);
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }

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

module.exports = { db, initDatabase };