/**
 * Adiciona a coluna `telefone` em `usuarios` para permitir login por número
 * (resolve a queixa de erro ao digitar o nome exato).
 *
 * Segurança / não-quebra:
 *  - Coluna NULLABLE: usuários já existentes ficam com telefone NULL e continuam
 *    logando pelo NOME (o login aceita telefone OU nome).
 *  - Índice único PARCIAL (WHERE telefone IS NOT NULL): garante telefone único por
 *    empresa SEM conflitar com os vários NULL dos usuários antigos.
 *  - Idempotente: usa IF NOT EXISTS / hasColumn.
 */
exports.up = async function (knex) {
  const temColuna = await knex.schema.hasColumn('usuarios', 'telefone');
  if (!temColuna) {
    await knex.schema.alterTable('usuarios', (t) => {
      t.string('telefone', 20).nullable();
    });
  }

  // Um telefone por empresa (ignora NULL dos usuários antigos).
  await knex.raw(`
    CREATE UNIQUE INDEX IF NOT EXISTS uniq_usuarios_tenant_telefone
    ON usuarios (tenant_id, telefone)
    WHERE telefone IS NOT NULL
  `);
};

exports.down = async function (knex) {
  await knex.raw('DROP INDEX IF EXISTS uniq_usuarios_tenant_telefone');
  const temColuna = await knex.schema.hasColumn('usuarios', 'telefone');
  if (temColuna) {
    await knex.schema.alterTable('usuarios', (t) => {
      t.dropColumn('telefone');
    });
  }
};
