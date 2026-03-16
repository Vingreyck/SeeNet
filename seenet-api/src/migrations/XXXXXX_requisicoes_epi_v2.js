// ================================================================
// ARQUIVO: migrations/XXXXXX_requisicoes_epi_v2.js
// ================================================================
exports.up = async function (knex) {
  // Verificar quais colunas já existem ANTES de entrar no alterTable
  const [
    hasReqIxc,
    hasItensIxc,
    hasDataEntrega,
    hasAssinatura,
    hasFoto,
    hasDataConfirmacao,
    hasRegistroManual,
    hasCriadoPor,
  ] = await Promise.all([
    knex.schema.hasColumn('requisicoes_epi', 'id_requisicao_ixc'),
    knex.schema.hasColumn('requisicoes_epi', 'itens_ixc'),
    knex.schema.hasColumn('requisicoes_epi', 'data_entrega'),
    knex.schema.hasColumn('requisicoes_epi', 'assinatura_recebimento_base64'),
    knex.schema.hasColumn('requisicoes_epi', 'foto_recebimento_base64'),
    knex.schema.hasColumn('requisicoes_epi', 'data_confirmacao_recebimento'),
    knex.schema.hasColumn('requisicoes_epi', 'registro_manual'),
    knex.schema.hasColumn('requisicoes_epi', 'criado_por_gestor_id'),
  ]);

  // Tornar foto e assinatura originais nullable (eram NOT NULL na migration antiga)
  // Rodar direto no Postgres se der erro:
  // ALTER TABLE requisicoes_epi ALTER COLUMN assinatura_base64 DROP NOT NULL;
  // ALTER TABLE requisicoes_epi ALTER COLUMN foto_base64 DROP NOT NULL;
  try {
    await knex.raw('ALTER TABLE requisicoes_epi ALTER COLUMN assinatura_base64 DROP NOT NULL');
    await knex.raw('ALTER TABLE requisicoes_epi ALTER COLUMN foto_base64 DROP NOT NULL');
  } catch (_) {
    // Ignora se já for nullable
  }

  return knex.schema.alterTable('requisicoes_epi', (table) => {
    if (!hasReqIxc)
      table.string('id_requisicao_ixc', 50).nullable();

    if (!hasItensIxc)
      table.jsonb('itens_ixc').nullable();

    if (!hasDataEntrega)
      table.timestamp('data_entrega').nullable();

    if (!hasAssinatura)
      table.text('assinatura_recebimento_base64').nullable();

    if (!hasFoto)
      table.text('foto_recebimento_base64').nullable();

    if (!hasDataConfirmacao)
      table.timestamp('data_confirmacao_recebimento').nullable();

    if (!hasRegistroManual)
      table.boolean('registro_manual').defaultTo(false);

    if (!hasCriadoPor)
      table.integer('criado_por_gestor_id').nullable()
        .references('id').inTable('usuarios');
  });
};

exports.down = function (knex) {
  return knex.schema.alterTable('requisicoes_epi', (table) => {
    table.dropColumn('id_requisicao_ixc');
    table.dropColumn('itens_ixc');
    table.dropColumn('data_entrega');
    table.dropColumn('assinatura_recebimento_base64');
    table.dropColumn('foto_recebimento_base64');
    table.dropColumn('data_confirmacao_recebimento');
    table.dropColumn('registro_manual');
    table.dropColumn('criado_por_gestor_id');
  });
};