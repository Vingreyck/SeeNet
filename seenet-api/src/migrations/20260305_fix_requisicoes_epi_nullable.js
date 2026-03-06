exports.up = function(knex) {
  return knex.schema.alterTable('requisicoes_epi', (table) => {
    table.text('assinatura_base64').nullable().alter();
    table.text('foto_base64').nullable().alter();
  });
};

exports.down = function(knex) {
  return knex.schema.alterTable('requisicoes_epi', (table) => {
    table.text('assinatura_base64').notNullable().alter();
    table.text('foto_base64').notNullable().alter();
  });
};