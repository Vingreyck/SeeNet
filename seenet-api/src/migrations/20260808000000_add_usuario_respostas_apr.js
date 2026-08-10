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
 * Idempotente.
 */
exports.up = async function (knex) {
  const temColuna = await knex.schema.hasColumn('respostas_apr', 'usuario_id');
  if (!temColuna) {
    await knex.schema.alterTable('respostas_apr', (t) => {
      t.integer('usuario_id').nullable();
    });
    await knex.raw(`
      UPDATE respostas_apr r
      SET usuario_id = os.tecnico_id
      FROM ordem_servico os
      WHERE os.id = r.ordem_servico_id AND r.usuario_id IS NULL
    `);
  }
};

exports.down = async function (knex) {
  const temColuna = await knex.schema.hasColumn('respostas_apr', 'usuario_id');
  if (temColuna) {
    await knex.schema.alterTable('respostas_apr', (t) => {
      t.dropColumn('usuario_id');
    });
  }
};
