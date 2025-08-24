exports.seed = async function(knex) {
  // Categorias globais (aplicam a todos os tenants)
  const categorias = await knex('categorias_checkmark').insert([
    // Categorias globais
    { tenant_id: 1, nome: 'Lentidão', descricao: 'Problemas de velocidade, buffering e lentidão geral', ordem: 1, global: true },
    { tenant_id: 1, nome: 'IPTV', descricao: 'Travamentos, buffering, canais fora do ar, qualidade de vídeo', ordem: 2, global: true },
    { tenant_id: 1, nome: 'Aplicativos', descricao: 'Apps não carregam, erro de carregamento da logo', ordem: 3, global: true },
    { tenant_id: 1, nome: 'Acesso Remoto', descricao: 'Ativação de acessos remotos dos roteadores', ordem: 4, global: true },
    
    // Replicar para o segundo tenant
    { tenant_id: 2, nome: 'Lentidão', descricao: 'Problemas de velocidade, buffering e lentidão geral', ordem: 1, global: true },
    { tenant_id: 2, nome: 'IPTV', descricao: 'Travamentos, buffering, canais fora do ar, qualidade de vídeo', ordem: 2, global: true },
    { tenant_id: 2, nome: 'Aplicativos', descricao: 'Apps não carregam, erro de carregamento da logo', ordem: 3, global: true },
    { tenant_id: 2, nome: 'Acesso Remoto', descricao: 'Ativação de acessos remotos dos roteadores', ordem: 4, global: true },
    
    // Categoria específica do TechCorp
    { tenant_id: 2, nome: 'Infraestrutura Corporativa', descricao: 'Problemas específicos de rede corporativa', ordem: 5, global: false }
  ]).returning('id');

  console.log('✅ Categorias criadas:', categorias.length);
};