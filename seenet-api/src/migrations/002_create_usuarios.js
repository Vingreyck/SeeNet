exports.up = function(knex) {
  return knex.schema.createTable('usuarios', function(table) {
    table.increments('id').primary();
    table.integer('tenant_id').unsigned().notNullable();
    table.string('nome', 255).notNullable();
    table.string('email', 255).notNullable();
    table.string('senha', 255).notNullable();
    table.enum('tipo_usuario', ['tecnico', 'administrador']).defaultTo('tecnico');
    table.boolean('ativo').defaultTo(true);
    table.integer('tentativas_login').defaultTo(0);
    table.timestamp('ultimo_login');
    table.json('configuracoes').defaultTo('{}');
    table.timestamp('data_upload').defaultTo(knex.fn.now());
    table.timestamp('data_atualizacao').defaultTo(knex.fn.now());
    
    // Foreign keys
    table.foreign('tenant_id').references('id').inTable('tenants').onDelete('CASCADE');
    
    // Índices
    table.index(['tenant_id', 'email']); // Email único por tenant
    table.index('tenant_id');
    table.index('ativo');
    table.index('tipo_usuario');
    
    // Constraint: email único por tenant
    table.unique(['tenant_id', 'email']);
  });
};

exports.down = function(knex) {
  return knex.schema.dropTable('usuarios');
};