/**
 * Quem respondeu a APR. Sem isso, `/apr/status` só sabia dizer "esta OS TEM
 * APR" — então, ao ENCAMINHAR a OS, o técnico novo herdava a APR do colega e
 * nunca preenchia a dele. APR é documento de segurança: quem assina tem que
 * ser quem avaliou o risco no local.
 *
 * Backfill: as respostas que já existem passam a pertencer ao técnico
 * atualmente responsável pela OS (é a suposição correta na esmagadora maioria
 * — OS que nunca foi encaminhada). Assim ninguém é obrigado a refazer uma APR
 * já feita por causa do deploy.
 *
 * Idempotente (IF NOT EXISTS + backfill só onde está NULL), então rodar de
 * novo é seguro — é o que permite `transaction: false`.
 *
 * ⚠️ `transaction: false` + lock_timeout + retry: ver a explicação completa em
 * 20260807000000_add_faz_apr_usuarios.js. Resumo: as migrations rodam no BOOT
 * e o container ANTIGO ainda está servindo, com o SincronizadorIXC segurando
 * lock numa transação longa; sem lock_timeout o ALTER pendura em silêncio e o
 * healthcheck derruba o deploy.
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
  await comRetry(knex, 'ALTER respostas_apr.usuario_id',
    `ALTER TABLE respostas_apr ADD COLUMN IF NOT EXISTS usuario_id INTEGER`);

  // Backfill: só onde ainda está NULL, então repetir não faz estrago.
  await comRetry(knex, 'backfill respostas_apr.usuario_id', `
    UPDATE respostas_apr r
    SET usuario_id = os.tecnico_id
    FROM ordem_servico os
    WHERE os.id = r.ordem_servico_id AND r.usuario_id IS NULL
  `);
};

exports.down = async function (knex) {
  await comRetry(knex, 'DROP respostas_apr.usuario_id',
    `ALTER TABLE respostas_apr DROP COLUMN IF EXISTS usuario_id`);
};
