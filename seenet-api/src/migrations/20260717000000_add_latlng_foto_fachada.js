exports.up = async function (knex) {
  const hasLat = await knex.schema.hasColumn('foto_fachada', 'latitude');
  if (!hasLat) {
    await knex.schema.alterTable('foto_fachada', (table) => {
      table.decimal('latitude', 10, 7).nullable();
      table.decimal('longitude', 10, 7).nullable();
    });
  }
};

exports.down = async function (knex) {
  const hasLat = await knex.schema.hasColumn('foto_fachada', 'latitude');
  if (hasLat) {
    await knex.schema.alterTable('foto_fachada', (table) => {
      table.dropColumn('latitude');
      table.dropColumn('longitude');
    });
  }
};
