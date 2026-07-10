exports.up = async function (knex) {
  const hasNumero = await knex.schema.hasColumn('ordem_servico', 'cliente_numero');
  const hasBairro = await knex.schema.hasColumn('ordem_servico', 'cliente_bairro');
  await knex.schema.alterTable('ordem_servico', (table) => {
    if (!hasNumero) table.string('cliente_numero').nullable();
    if (!hasBairro) table.string('cliente_bairro').nullable();
  });
};

exports.down = async function (knex) {
  await knex.schema.alterTable('ordem_servico', (table) => {
    table.dropColumn('cliente_numero');
    table.dropColumn('cliente_bairro');
  });
};
