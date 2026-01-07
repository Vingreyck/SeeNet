exports.up = function(knex) {
  return knex.schema.createTable('avaliacoes', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('tecnico_id').unsigned().notNullable();
    table.string('titulo', 255);
    table.text('descricao');
    table.enum('status', ['em_andamento', 'concluida', 'cancelada']).defaultTo('em_andamento');
    table.string('cliente_info', 500); // Informações do cliente
    table.string('localizacao', 255); // Local do atendimento
    table.timestamp('data_inicio').defaultTo(knex.fn.now());
    table.timestamp('data_conclusao');
    table.timestamp('data_upload').defaultTo(knex.fn.now());
    table.timestamp('data_atualizacao').defaultTo(knex.fn.now());
    
    // Foreign keys
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('tecnico_id').references('id').inTable('usuarios').onDelete('CASCADE');
    
    // Índices
    table.index(['tenant_id', 'tecnico_id']);
    table.index(['tenant_id', 'status']);
    table.index('data_upload');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('avaliacoes');
};