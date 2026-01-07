exports.up = function(knex) {
  return knex.schema.createTable('transcricoes_tecnicas', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.integer('tecnico_id').unsigned().notNullable();
    table.string('titulo', 255).notNullable();
    table.text('descricao');
    table.text('transcricao_original').notNullable();
    table.text('pontos_da_acao').notNullable();
    table.enum('status', ['gravando', 'processando', 'concluida', 'erro']).defaultTo('concluida');
    table.integer('duracao_segundos');
    table.string('categoria_problema', 100);
    table.string('cliente_info', 500);
    table.timestamp('data_inicio');
    table.timestamp('data_fim');
    table.timestamp('data_criacao').defaultTo(knex.fn.now());
    
    // Foreign keys
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    table.foreign('tecnico_id').references('id').inTable('usuarios').onDelete('CASCADE');
    
    // Índices
    table.index(['tenant_id', 'tecnico_id']);
    table.index(['tenant_id', 'status']);
    table.index('data_criacao');
    table.index('categoria_problema');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('transcricoes_tecnicas');
};
