// Cache do briefing da OS (análise que o técnico vê antes de bater na porta).
//
// Por que cachear: o briefing chama a Groq, que custa latência e tem limite de
// requisições. Sem cache, cada vez que o técnico abrisse a OS geraria de novo —
// e o resultado é praticamente o mesmo, porque as entradas (mensagem do IXC,
// sinal, histórico) quase não mudam durante um atendimento.
//
// `contexto_hash` guarda a impressão digital das ENTRADAS: quando o sinal é
// remedido ou entra uma OS nova no histórico, o hash muda e o briefing é
// regerado sozinho — sem precisar de rotina de expiração.
exports.up = async function (knex) {
  const exists = await knex.schema.hasTable('os_briefing');
  if (!exists) {
    await knex.schema.createTable('os_briefing', (table) => {
      table.increments('id').primary();
      table.integer('tenant_id').notNullable();
      table.integer('os_id').notNullable();
      table.jsonb('resumo').notNullable();      // o briefing pronto, como o app recebe
      table.string('contexto_hash', 64).nullable();
      table.boolean('com_ia').defaultTo(false); // false = só os fatos (IA falhou)
      table.string('modelo', 100).nullable();
      table.timestamp('gerado_em').defaultTo(knex.fn.now());
      table.unique(['tenant_id', 'os_id'], 'uniq_briefing_os');
    });
  }
};

exports.down = async function (knex) {
  await knex.schema.dropTableIfExists('os_briefing');
};
