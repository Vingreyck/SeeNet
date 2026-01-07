exports.up = function(knex) {
  return knex.schema.createTable('categorias_checkmark', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.string('nome', 255).notNullable();
    table.text('descricao');
    table.boolean('ativo').defaultTo(true);
    table.integer('ordem').defaultTo(0);
    table.boolean('global').defaultTo(false); // Categorias globais vs específicas do tenant
    table.timestamp('data_upload').defaultTo(knex.fn.now());
    
    // Foreign keys
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    
    // Índices
    table.index(['tenant_id', 'ativo']);
    table.index('global');
    table.index('ordem');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('categorias_checkmark');
};