// Login por CPF (sem senha). Adiciona a coluna `cpf` (única por empresa) e
// torna a coluna `senha` OPCIONAL (cadastro novo não envia senha).
// Idempotente — seguro rodar mais de uma vez.
exports.up = async function (knex) {
  const hasCpf = await knex.schema.hasColumn('usuarios', 'cpf');
  if (!hasCpf) {
    await knex.schema.alterTable('usuarios', (table) => {
      table.string('cpf', 14).nullable();
    });
  }
  // CPF único por empresa, ignorando NULL (antigos sem CPF não conflitam).
  await knex.raw(
    'CREATE UNIQUE INDEX IF NOT EXISTS uniq_usuarios_tenant_cpf ON usuarios (tenant_id, cpf) WHERE cpf IS NOT NULL'
  );
  // Login sem senha: senha deixa de ser obrigatória.
  await knex.raw('ALTER TABLE usuarios ALTER COLUMN senha DROP NOT NULL');
};

exports.down = async function (knex) {
  // Down seguro: NÃO re-obriga senha (poderia quebrar usuários sem senha) nem
  // remove a coluna cpf (poderia perder dados). Só remove o índice.
  await knex.raw('DROP INDEX IF EXISTS uniq_usuarios_tenant_cpf');
};
