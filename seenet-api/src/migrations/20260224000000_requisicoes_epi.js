exports.up = function (knex) {
  return knex.schema
    // Foto de perfil nos usuários
    .alterTable('usuarios', (table) => {
      table.text('foto_perfil').nullable(); // base64 ou URL
    })
    // Requisições de EPI
    .createTable('requisicoes_epi', (table) => {
      table.increments('id').primary();
      table.integer('tenant_id').notNullable().references('id').inTable('tenants');
      table.integer('tecnico_id').notNullable().references('id').inTable('usuarios');
      table.integer('gestor_id').nullable().references('id').inTable('usuarios'); // quem aprovou/recusou
      table.string('status', 20).notNullable().defaultTo('pendente'); // pendente, aprovada, recusada
      table.jsonb('epis_solicitados').notNullable(); // array de strings com os EPIs marcados
      table.text('assinatura_base64').notNullable(); // assinatura do técnico
      table.text('foto_base64').notNullable(); // foto rosto + material
      table.text('observacao_gestor').nullable(); // motivo recusa ou obs aprovação
      table.text('pdf_base64').nullable(); // PDF gerado após aprovação
      table.timestamp('data_criacao').defaultTo(knex.fn.now());
      table.timestamp('data_atualizacao').defaultTo(knex.fn.now());
      table.timestamp('data_resposta').nullable(); // quando gestor respondeu
    });
};

exports.down = function (knex) {
  return knex.schema
    .dropTableIfExists('requisicoes_epi')
    .alterTable('usuarios', (table) => {
      table.dropColumn('foto_perfil');
    });
};