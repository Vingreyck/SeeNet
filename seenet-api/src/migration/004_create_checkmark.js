exports.up = function(knex) {
  return knex.schema.createTable('checkmarks', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('categoria_id').unsigned().notNullable();
    table.string('titulo', 255).notNullable();
    table.text('descricao');
    table.text('prompt_chatgpt').notNullable();
    table.boolean('ativo').defaultTo(true);
    table.integer('ordem').defaultTo(0);
    table.boolean('global').defaultTo(false); // Checkmarks globais vs específicos do tenant
    table.timestamp('data_criacao').defaultTo(knex.fn.now());
    
    // Foreign keys
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('categoria_id').references('id').inTable('categorias_checkmark').onDelete('CASCADE');
    
    // Índices
    table.index(['tenant_id', 'categoria_id', 'ativo']);
    table.index('categoria_id');
    table.index('global');
    table.index('ordem');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('checkmarks');
};