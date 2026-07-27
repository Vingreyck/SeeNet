exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('os_fotos_ixc_enviadas');
  if (!exists) {
    await knex.schema.createTable('os_fotos_ixc_enviadas', (t) => {
      t.increments('id').primary();
      t.integer('tenant_id').notNullable();
      t.integer('os_id').notNullable();
      t.string('hash', 64).notNullable(); // sha256 do conteúdo da foto
      t.timestamp('enviado_em').defaultTo(knex.fn.now());
      t.unique(['tenant_id', 'os_id', 'hash']);
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('os_fotos_ixc_enviadas');
};
