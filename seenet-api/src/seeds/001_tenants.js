exports.seed = async function(knex) {
  // Limpar dados existentes
  await knex('logs_sistema').del();
  await knex('transcricoes_tecnicas').del();
  await knex('diagnosticos').del();
  await knex('respostas_checkmark').del();
  await knex('avaliacoes').del();
  await knex('checkmarks').del();
  await knex('categorias_checkmark').del();
  await knex('usuarios').del();
  await knex('tenants').del();

  // Inserir tenants de teste
  const tenants = await knex('tenants').insert([
    {
      id: 1,
      nome: 'SeeNet Demo',
      codigo: 'DEMO2024',
      descricao: 'Empresa de demonstração do sistema SeeNet',
      plano: 'profissional',
      ativo: true,
      configuracoes: JSON.stringify({
        gemini_enabled: true,
        max_diagnosticos_mes: 100,
        backup_automatico: true
      }),
      limites: JSON.stringify({
        usuarios_max: 25,
        storage_mb: 1000,
        api_calls_dia: 500
      }),
      contato_email: 'admin@seenet.com',
      contato_telefone: '(11) 99999-9999'
    },
    {
      id: 2,
      nome: 'TechCorp Ltda',
      codigo: 'TECH2024',
      descricao: 'Empresa de tecnologia especializada em redes',
      plano: 'empresarial',
      ativo: true,
      configuracoes: JSON.stringify({
        gemini_enabled: true,
        max_diagnosticos_mes: 500,
        backup_automatico: true,
        custom_branding: true
      }),
      limites: JSON.stringify({
        usuarios_max: 100,
        storage_mb: 5000,
        api_calls_dia: 1000
      }),
      contato_email: 'suporte@techcorp.com',
      contato_telefone: '(21) 98888-8888'
    }
  ]).returning('id');

  console.log('✅ Tenants criados:', tenants);
};
