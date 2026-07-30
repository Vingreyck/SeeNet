/**
 * Versão do app que cada usuário está usando (header X-App-Version, gravado no
 * login). Serve pra responder "esse técnico atualizou mesmo?" sem depender de
 * arqueologia de horários no IXC — foi o que custou horas em 29/jul/2026.
 * Idempotente.
 */
exports.up = async function (knex) {
  const temColuna = await knex.schema.hasColumn('usuarios', 'versao_app');
  if (!temColuna) {
    await knex.schema.alterTable('usuarios', (t) => {
      t.string('versao_app', 40).nullable();
      t.timestamp('versao_app_em').nullable();
    });
  }
};

exports.down = async function (knex) {
  const temColuna = await knex.schema.hasColumn('usuarios', 'versao_app');
  if (temColuna) {
    await knex.schema.alterTable('usuarios', (t) => {
      t.dropColumn('versao_app');
      t.dropColumn('versao_app_em');
    });
  }
};
