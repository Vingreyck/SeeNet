exports.up = function(knex) {
  return knex.schema.createTable('respostas_checkmark', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('avaliacao_id').unsigned().notNullable();
    table.integer('checkmark_id').unsigned().notNullable();
    table.boolean('marcado').defaultTo(false);
    table.text('observacoes');
    table.timestamp('data_resposta').defaultTo(knex.fn.now());
    
    // Foreign keys
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('avaliacao_id').references('id').inTable('avaliacoes').onDelete('CASCADE');
    table.foreign('checkmark_id').references('id').inTable('checkmarks').onDelete('CASCADE');
    
    // Índices
    table.index(['tenant_id', 'avaliacao_id']);
    table.index('avaliacao_id');
    table.index('checkmark_id');
    
    // Constraint: uma resposta por checkmark por avaliação
    table.unique(['avaliacao_id', 'checkmark_id']);
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('respostas_checkmark');
};
