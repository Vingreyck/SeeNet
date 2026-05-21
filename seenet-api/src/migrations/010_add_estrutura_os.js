exports.up = function(knex) {
  return knex.schema.alterTable('ordem_servico', (table) => {
    table.string('tipo_os', 1).defaultTo('C');
    table.string('id_estrutura', 20).nullable();
    table.string('nome_estrutura', 255).nullable();
  });
};

exports.down = function(knex) {
  return knex.schema.alterTable('ordem_servico', (table) => {
    table.dropColumn('tipo_os');
    table.dropColumn('id_estrutura');
    table.dropColumn('nome_estrutura');
  });
};