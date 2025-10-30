const path = require('path');
require('dotenv').config();

module.exports = {
  development: {
    client: 'pg',
    connection: {
      host: process.env.DB_HOST || 'db.tcqhyzbkkigukrqniefx.supabase.co',
      port: process.env.DB_PORT || 5432,
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || '1524Br101',
      database: process.env.DB_NAME || 'postgres',
      ssl: { rejectUnauthorized: false }
    },
    migrations: {
      directory: path.join(__dirname, 'src', 'migrations')
    },
    seeds: {
      directory: path.join(__dirname, 'src', 'seeds')
    },
    pool: {
      min: 2,
      max: 10
    }
  },

  production: {
    client: 'pg',
    connection: {
      host: process.env.DB_HOST,
      port: process.env.DB_PORT || 5432,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      ssl: { rejectUnauthorized: false }
    },
    migrations: {
      directory: path.join(__dirname, 'src', 'migrations')
    },
    seeds: {
      directory: path.join(__dirname, 'src', 'seeds')
    },
    pool: {
      min: 2,
      max: 10
    }
  }
};