// Vários admins acompanhando a MESMA OS.
//
// Antes existia só a coluna `ordem_servico.admin_responsavel_id` (UM admin).
// Quem quisesse acompanhar junto simplesmente não recebia nada: nem
// notificação, nem a OS na tela de Acompanhamento.
//
// Por que tabela nova em vez de trocar a coluna por um array:
//   1. A coluna continua existindo e continua sendo gravada com o PRIMEIRO
//      admin escolhido. Todo código que já lia `os.admin_responsavel_id`
//      (notificações, SLA, acompanhamento) segue funcionando igual, e app
//      antigo — que só sabe mandar um id — não quebra.
//   2. Consulta "quais OS este admin acompanha?" vira um índice comum
//      (tenant_id, admin_id), em vez de varrer array/JSON linha a linha.
//
// A unique evita duplicar o mesmo admin na mesma OS quando o técnico
// reenvia (fila offline reprocessando, toque duplo, etc).
exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('os_admins_responsaveis');
  if (!exists) {
    await knex.schema.createTable('os_admins_responsaveis', (table) => {
      table.increments('id').primary();
      table.integer('tenant_id').notNullable();
      table.integer('os_id').notNullable();
      table.integer('admin_id').notNullable();
      table.timestamp('criado_em').defaultTo(knex.fn.now());
      table.unique(['tenant_id', 'os_id', 'admin_id'], 'uniq_os_admin');
      table.index(['tenant_id', 'admin_id'], 'idx_os_admin_por_admin');
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('os_admins_responsaveis');
};
