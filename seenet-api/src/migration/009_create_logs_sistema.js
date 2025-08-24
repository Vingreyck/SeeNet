exports.up = function(knex) {
  return knex.schema.createTable('logs_sistema', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned();
    table.integer('usuario_id').unsigned();
    table.string('acao', 100).notNullable();
    table.enum('nivel', ['info', 'warning', 'error']).defaultTo('info');
    table.string('tabela_afetada', 50);
    table.integer('registro_id').unsigned();
    table.json('dados_anteriores');
    table.json('dados_novos');
    table.string('ip_address', 45);
    table.string('user_agent', 500);
    table.text('detalhes');
    table.timestamp('data_acao').defaultTo(knex.fn.now());
    
    // Foreign keys (nullable para logs de sistema)
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('SET NULL');
    table.foreign('usuario_id').references('id').inTable('usuarios').onDelete('SET NULL');
    
    // Índices para performance
    table.index(['tenant_id', 'data_acao']);
    table.index(['usuario_id', 'data_acao']);
    table.index(['acao', 'data_acao']);
    table.index(['nivel', 'data_acao']);
    table.index('data_acao');
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('logs_sistema');
};