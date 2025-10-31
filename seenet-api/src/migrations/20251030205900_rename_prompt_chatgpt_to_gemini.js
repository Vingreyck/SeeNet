exports.up = async function(knex) {
  // Verificar se coluna antiga ainda existe
  const hasOldColumn = await knex.schema.hasColumn('checkmarks', 'prompt_chatgpt');
  
  if (hasOldColumn) {
    await knex.schema.table('checkmarks', (table) => {
      table.renameColumn('prompt_chatgpt', 'prompt_gemini');
    });
    console.log('✅ Coluna prompt_chatgpt renomeada para prompt_gemini');
  } else {
    console.log('⚠️ Coluna prompt_chatgpt não encontrada, pulando...');
  }
};

exports.down = async function(knex) {
  // Reverter: gemini -> chatgpt
  const hasNewColumn = await knex.schema.hasColumn('checkmarks', 'prompt_gemini');
  
  if (hasNewColumn) {
    await knex.schema.table('checkmarks', (table) => {
      table.renameColumn('prompt_gemini', 'prompt_chatgpt');
    });
    console.log('✅ Coluna prompt_gemini revertida para prompt_chatgpt');
  }
};