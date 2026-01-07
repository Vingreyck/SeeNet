exports.up = function(knex) {
  return knex.schema.createTable('tenants', function(table) {
    table.increments('id').primary();
    table.string('nome', 255).notNullable();
    table.string('codigo', 20).notNullable().unique();
    table.text('descricao');
    table.enum('plano', ['basico', 'profissional', 'empresarial', 'enterprise']).defaultTo('basico');
    table.boolean('ativo').defaultTo(true);
    table.json('configuracoes').defaultTo('{}');
    table.json('limites').defaultTo('{}');
    table.string('contato_email', 255);
    table.string('contato_telefone', 20);
    table.timestamp('data_upload').defaultTo(knex.fn.now());
    table.timestamp('data_atualizacao').defaultTo(knex.fn.now());
    
    // Índices
    table.index('codigo');
    table.index('ativo');
    table.index('plano');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('tenants');
};