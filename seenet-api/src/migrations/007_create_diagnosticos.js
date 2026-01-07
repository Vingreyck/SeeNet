exports.up = function(knex) {
  return knex.schema.createTable('diagnosticos', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('avaliacao_id').unsigned().notNullable();
    table.integer('categoria_id').unsigned().notNullable();
    table.text('prompt_enviado').notNullable();
    table.text('resposta_gemini').notNullable();
    table.text('resumo_diagnostico');
    table.enum('status_api', ['pendente', 'sucesso', 'erro']).defaultTo('pendente');
    table.text('erro_api');
    table.integer('tokens_utilizados');
    table.string('modelo_ia', 50); // Gemini, etc.
    table.decimal('custo_api', 10, 6); // Custo da requisição
    table.timestamp('data_upload').defaultTo(knex.fn.now());
    
    // Foreign keys
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('avaliacao_id').references('id').inTable('avaliacoes').onDelete('CASCADE');
    table.foreign('categoria_id').references('id').inTable('categorias_checkmark').onDelete('CASCADE');
    
    // Índices
    table.index(['tenant_id', 'avaliacao_id']);
    table.index(['tenant_id', 'status_api']);
    table.index('data_upload');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('diagnosticos');
};