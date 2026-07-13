// Trilha de posições do técnico (histórico) — a localizacao_tecnico guarda só a
// posição ATUAL (upsert); esta tabela acumula pontos pra desenhar a rota
// percorrida no mapa do admin. Retenção: 7 dias (limpeza no ciclo de sync).
exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('localizacao_trilha');
  if (!exists) {
    await knex.schema.createTable('localizacao_trilha', (table) => {
      table.increments('id').primary();
      table.integer('tenant_id').notNullable();
      table.integer('tecnico_id').notNullable();
      table.integer('ordem_servico_id').notNullable();
      table.double('latitude').notNullable();
      table.double('longitude').notNullable();
      table.double('velocidade').nullable();
      table.double('precisao').nullable();
      table.timestamp('criado_em').defaultTo(knex.fn.now());
      table.index(['ordem_servico_id', 'criado_em'], 'idx_trilha_os_data');
      table.index('criado_em', 'idx_trilha_criado_em'); // p/ limpeza por idade
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('localizacao_trilha');
};
