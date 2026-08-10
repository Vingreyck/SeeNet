/**
 * Admin escolhe, por técnico, se ele faz APR. Quem NÃO faz (faz_apr=false)
 * pula a tela de APR mesmo em OS de assunto que normalmente exige (60/4/32).
 * Default TRUE — comportamento de hoje não muda pra ninguém até o admin
 * desmarcar alguém explicitamente. Idempotente.
 *
 * ⚠️ POR QUE `transaction: false` + lock_timeout + retry:
 * `db.migrate.latest()` roda no BOOT (config/database.js). No deploy do
 * Railway o container ANTIGO continua servindo até o novo passar no
 * healthcheck — e o SincronizadorIXC dele mantém uma transação LONGA que
 * segura lock em `usuarios`. Um ALTER TABLE precisa de ACCESS EXCLUSIVE,
 * então ele entrava na fila, ficava esperando em SILÊNCIO e o healthcheck
 * (120s) matava o deploy. Foi o que derrubou os deploys de 10/ago.
 * Com lock_timeout curto o ALTER falha rápido em vez de pendurar, e a gente
 * tenta de novo até pegar uma janela entre os ciclos do sync.
 */
const LOCK_TIMEOUT = '3s';
const TENTATIVAS = 20;
const ESPERA_MS = 3000;

async function comRetry(knex, descricao, sql) {
  for (let i = 1; i <= TENTATIVAS; i++) {
    try {
      await knex.raw(`SET lock_timeout = '${LOCK_TIMEOUT}'`);
      await knex.raw(sql);
      return;
    } catch (e) {
      // 55P03 = lock_not_available (não conseguiu o lock a tempo)
      const ehLock = e.code === '55P03' || /lock timeout|lock_not_available/i.test(e.message || '');
      if (!ehLock) throw e;
      console.warn(`⏳ ${descricao}: tabela ocupada (tentativa ${i}/${TENTATIVAS}) — tentando de novo...`);
      await new Promise((r) => setTimeout(r, ESPERA_MS));
    }
  }
  throw new Error(`${descricao}: não consegui o lock após ${TENTATIVAS} tentativas`);
}

exports.config = { transaction: false };

exports.up = async function (knex) {
  await comRetry(knex, 'ALTER usuarios.faz_apr',
    `ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS faz_apr BOOLEAN NOT NULL DEFAULT TRUE`);
};

exports.down = async function (knex) {
  await comRetry(knex, 'DROP usuarios.faz_apr',
    `ALTER TABLE usuarios DROP COLUMN IF EXISTS faz_apr`);
};
