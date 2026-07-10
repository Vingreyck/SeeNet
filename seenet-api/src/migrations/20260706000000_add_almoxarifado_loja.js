/**
 * Mapeamento da LOJA da cidade no técnico.
 *
 * Material/comodato da OS passam a descontar da LOJA da cidade
 * (id_almoxarifado_loja), enquanto o EPI continua no almox PESSOAL do técnico
 * (id_almoxarifado). Por isso é um campo SEPARADO — não repontar o existente.
 *
 * A tabela mapeamento_tecnicos_ixc foi criada manualmente (fora das migrations),
 * então aqui só adicionamos as colunas com guarda hasColumn.
 */
exports.up = async function (knex) {
  const temTabela = await knex.schema.hasTable('mapeamento_tecnicos_ixc');
  if (!temTabela) return;

  const temColuna = await knex.schema.hasColumn('mapeamento_tecnicos_ixc', 'id_almoxarifado_loja');
  if (!temColuna) {
    await knex.schema.alterTable('mapeamento_tecnicos_ixc', (table) => {
      table.integer('id_almoxarifado_loja').nullable();
      table.string('almoxarifado_loja_nome').nullable();
    });
  }
};

exports.down = async function (knex) {
  const temTabela = await knex.schema.hasTable('mapeamento_tecnicos_ixc');
  if (!temTabela) return;

  const temColuna = await knex.schema.hasColumn('mapeamento_tecnicos_ixc', 'id_almoxarifado_loja');
  if (temColuna) {
    await knex.schema.alterTable('mapeamento_tecnicos_ixc', (table) => {
      table.dropColumn('id_almoxarifado_loja');
      table.dropColumn('almoxarifado_loja_nome');
    });
  }
};
