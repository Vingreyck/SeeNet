/**
 * Admin escolhe, por técnico, se ele faz APR. Quem NÃO faz (faz_apr=false)
 * pula a tela de APR mesmo em OS de assunto que normalmente exige (60/4/32).
 * Default TRUE — comportamento de hoje não muda pra ninguém até o admin
 * desmarcar alguém explicitamente. Idempotente.
 */
exports.up = async function (knex) {
  const temColuna = await knex.schema.hasColumn('usuarios', 'faz_apr');
  if (!temColuna) {
    await knex.schema.alterTable('usuarios', (t) => {
      t.boolean('faz_apr').notNullable().defaultTo(true);
    });
  }
};

exports.down = async function (knex) {
  const temColuna = await knex.schema.hasColumn('usuarios', 'faz_apr');
  if (temColuna) {
    await knex.schema.alterTable('usuarios', (t) => {
      t.dropColumn('faz_apr');
    });
  }
};
