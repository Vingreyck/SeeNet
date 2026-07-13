exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('foto_fachada');
  if (!exists) {
    await knex.schema.createTable('foto_fachada', (table) => {
      table.increments('id').primary();
      table.integer('tenant_id').notNullable();
      // Chave do local: cliente do IXC (1 foto por cliente), igual ao agrupamento
      // do histórico de endereço. Ver buscarHistoricoEndereco.
      table.string('cliente_id_externo').notNullable();
      table.text('foto_base64').notNullable();
      table.string('mime').defaultTo('image/jpeg');
      table.integer('tecnico_id').nullable();
      table.string('os_id_origem').nullable();
      table.timestamp('created_at').defaultTo(knex.fn.now());
      table.timestamp('updated_at').defaultTo(knex.fn.now());
      table.unique(['tenant_id', 'cliente_id_externo']);
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('foto_fachada');
};
