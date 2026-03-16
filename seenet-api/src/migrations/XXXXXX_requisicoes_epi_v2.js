exports.up = async function (knex) {
  const hasCol = (col) => knex.schema.hasColumn('requisicoes_epi', col);

  // Tornar foto e assinatura nullable (técnico só envia na confirmação)
  // Se der erro de tipo no Postgres, rode manualmente:
  // ALTER TABLE requisicoes_epi ALTER COLUMN assinatura_base64 DROP NOT NULL;
  // ALTER TABLE requisicoes_epi ALTER COLUMN foto_base64 DROP NOT NULL;

  return knex.schema.alterTable('requisicoes_epi', async (table) => {
    // IXC
    if (!(await hasCol('id_requisicao_ixc')))
      table.string('id_requisicao_ixc', 50).nullable();

    if (!(await hasCol('itens_ixc')))
      table.jsonb('itens_ixc').nullable(); // [{id_produto, descricao, quantidade, id_item_ixc, qtde_saldo}]

    // Data de entrega (gestor define na aprovação)
    if (!(await hasCol('data_entrega')))
      table.timestamp('data_entrega').nullable();

    // Confirmação de recebimento (técnico preenche depois)
    if (!(await hasCol('assinatura_recebimento_base64')))
      table.text('assinatura_recebimento_base64').nullable();

    if (!(await hasCol('foto_recebimento_base64')))
      table.text('foto_recebimento_base64').nullable();

    if (!(await hasCol('data_confirmacao_recebimento')))
      table.timestamp('data_confirmacao_recebimento').nullable();

    // Registro manual pelo gestor
    if (!(await hasCol('registro_manual')))
      table.boolean('registro_manual').defaultTo(false);

    if (!(await hasCol('criado_por_gestor_id')))
      table.integer('criado_por_gestor_id').nullable().references('id').inTable('usuarios');
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