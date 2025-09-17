const path = require('path');

module.exports = {
  development: {
    client: 'sqlite3',
    connection: {
      filename: path.join(__dirname, 'database', 'seenet.sqlite')
    },
    useNullAsDefault: true,
    migrations: {
      directory: path.join(__dirname, 'src', 'migrations')
    },
    seeds: {
      directory: path.join(__dirname, 'src', 'seeds')
    },
    pool: {
      afterCreate: (conn, done) => {
        conn.run('PRAGMA foreign_keys = ON', done);
      }
    }
  },

  production: {
    client: 'sqlite3',
    connection: {
      filename: path.join(__dirname, 'database', 'seenet.sqlite')
    },
    useNullAsDefault: true,
    migrations: {
      directory: path.join(__dirname, 'src', 'migrations')
    },
    pool: {
      min: 2,
      max: 10,
      afterCreate: (conn, done) => {
        conn.run('PRAGMA foreign_keys = ON', done);
        conn.run('PRAGMA journal_mode = WAL', done);
      }
    }
  }
};