// Rascunho do wizard da OS salvo no SERVIDOR (atrelado à OS, não ao técnico).
// Quando o técnico reagenda/encaminha, todo o progresso (fotos base64,
// assinatura, produtos/patrimônios, ONU, relatos, localização, rascunho da APR)
// é salvo aqui pra o PRÓXIMO técnico (ou o mesmo, em outro aparelho) continuar.
exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('os_rascunho');
  if (!exists) {
    await knex.schema.createTable('os_rascunho', (t) => {
      t.increments('id').primary();
      t.integer('tenant_id').notNullable();
      t.integer('os_id').notNullable(); // ordem_servico.id (estável entre técnicos)
      t.text('dados').notNullable();     // JSON com todo o estado do wizard
      t.integer('atualizado_por').nullable();
      t.timestamp('atualizado_em').defaultTo(knex.fn.now());
      t.unique(['tenant_id', 'os_id']);
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('os_rascunho');
};
