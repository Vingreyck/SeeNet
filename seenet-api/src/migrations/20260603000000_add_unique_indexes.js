/**
 * Índices únicos para impedir DUPLICADOS criados por condição de corrida
 * (SELECT-existe? -> INSERT em dois passos, sem trava).
 *
 *  - usuarios(tenant_id, nome): um usuário por nome dentro de cada empresa.
 *  - mapeamento_tecnicos_ixc(usuario_id, tenant_id): um mapeamento IXC por
 *    técnico em cada empresa.
 *
 * Segurança:
 *  - Já validamos (via /api/auth/debug/check-duplicados) que NÃO há duplicados,
 *    então a criação não falha.
 *  - CREATE UNIQUE INDEX IF NOT EXISTS torna a migração idempotente.
 *  - A criação do índice de mapeamento só ocorre se a tabela existir, evitando
 *    que o boot quebre em ambientes onde a tabela ainda não foi criada.
 */
exports.up = async function (knex) {
  await knex.raw(`
    CREATE UNIQUE INDEX IF NOT EXISTS uniq_usuarios_tenant_nome
    ON usuarios (tenant_id, nome)
  `);

  const temMapeamento = await knex.schema.hasTable('mapeamento_tecnicos_ixc');
  if (temMapeamento) {
    await knex.raw(`
      CREATE UNIQUE INDEX IF NOT EXISTS uniq_mapeamento_usuario_tenant
      ON mapeamento_tecnicos_ixc (usuario_id, tenant_id)
    `);
  }
};

exports.down = async function (knex) {
  await knex.raw('DROP INDEX IF EXISTS uniq_usuarios_tenant_nome');
  await knex.raw('DROP INDEX IF EXISTS uniq_mapeamento_usuario_tenant');
};
