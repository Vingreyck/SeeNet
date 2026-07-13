// Guarda o último saldo conhecido de cada equipamento por loja, pra o alerta ser
// EVENT-DRIVEN (só avisa quando o saldo CAI abaixo do mínimo ou piora) e não
// re-disparar a cada 12h nem a cada deploy. Persistente = sobrevive a restart.
exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('estoque_estado');
  if (!exists) {
    await knex.schema.createTable('estoque_estado', (table) => {
      table.increments('id').primary();
      table.integer('tenant_id').notNullable();
      table.integer('id_almoxarifado').notNullable();
      table.string('id_produto').notNullable();
      table.decimal('saldo', 14, 3).notNullable().defaultTo(0);
      table.timestamp('atualizado_em').defaultTo(knex.fn.now());
      table.unique(['tenant_id', 'id_almoxarifado', 'id_produto']);
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('estoque_estado');
};
