exports.seed = async function(knex) {
  // Verificar se já existem checkmarks
  const existingCheckmarks = await knex('checkmarks')
    .select('id')
    .limit(1);
  
  if (existingCheckmarks.length > 0) {
    console.log('✅ Checkmarks já existem, pulando seed...');
    return;
  }

  const tenant = await knex('tenants').where('codigo', 'DEMO2024').first();
  if (!tenant) {
    console.log('⚠️ Tenant DEMO2024 não encontrado');
    return;
  }

  const categorias = await knex('categorias_checkmark')
    .where('tenant_id', tenant.id)
    .orderBy('ordem');

  const checkmarks = [];

  for (const cat of categorias) {
    let items = [];
    
    if (cat.nome.toLowerCase().includes('lentidão')) {
      items = [
        { titulo: 'Velocidade abaixo do contratado', descricao: 'Cliente relata velocidade abaixo do contratado', prompt: 'Analise lentidão com velocidade abaixo do contratado. Forneça diagnóstico e soluções práticas.' },
        { titulo: 'Ping alto > 100ms', descricao: 'Ping alto causando travamentos', prompt: 'Ping acima de 100ms. Analise causas e soluções para reduzir latência.' },
        { titulo: 'Perda de pacotes', descricao: 'Perda de pacotes na conexão', prompt: 'Diagnóstico para perda de pacotes. Identifique causas e soluções.' },
        { titulo: 'Problemas no cabo', descricao: 'Problemas físicos no cabeamento', prompt: 'Analise problemas de cabeamento e forneça orientações.' },
        { titulo: 'Wi-Fi com sinal fraco', descricao: 'Sinal WiFi fraco ou instável', prompt: 'Sinal WiFi fraco. Diagnóstico e soluções para melhorar cobertura.' },
        { titulo: 'Roteador com defeito', descricao: 'Equipamento apresentando falhas', prompt: 'Possível defeito no roteador. Diagnóstico e verificações.' },
        { titulo: 'Muitos dispositivos', descricao: 'Sobrecarga por excesso de dispositivos', prompt: 'Rede sobrecarregada por muitos dispositivos conectados.' },
        { titulo: 'Interferência', descricao: 'Interferência afetando o sinal', prompt: 'Interferência de equipamentos afetando a conexão.' }
      ];
    } else if (cat.nome.toLowerCase().includes('iptv')) {
      items = [
        { titulo: 'Canais travando', descricao: 'Canais travando ou congelando', prompt: 'Travamento em canais IPTV. Analise e forneça soluções.' },
        { titulo: 'Buffering constante', descricao: 'Buffering constante nos canais', prompt: 'IPTV com buffering constante. Diagnóstico e soluções.' },
        { titulo: 'Canal fora do ar', descricao: 'Canais específicos fora do ar', prompt: 'Canais IPTV fora do ar. Analise causas e soluções.' },
        { titulo: 'Qualidade baixa', descricao: 'Qualidade de vídeo baixa', prompt: 'Qualidade de vídeo ruim no IPTV. Diagnóstico e melhorias.' },
        { titulo: 'IPTV não abre', descricao: 'Aplicativo IPTV não abre', prompt: 'IPTV não consegue inicializar. Diagnóstico e soluções.' },
        { titulo: 'Erro de autenticação', descricao: 'Problemas de login no IPTV', prompt: 'Erros de autenticação no IPTV. Analise e solucione.' },
        { titulo: 'Audio dessincronizado', descricao: 'Audio fora de sincronia', prompt: 'Sincronização entre audio e vídeo no IPTV.' },
        { titulo: 'Demora para carregar', descricao: 'Lentidão para iniciar canais', prompt: 'Canais demoram para carregar ou inicializar.' }
      ];
    } else if (cat.nome.toLowerCase().includes('aplicativo')) {
      items = [
        { titulo: 'App não abre', descricao: 'Aplicativos não conseguem abrir', prompt: 'Aplicativos não abrem. Diagnóstico e soluções.' },
        { titulo: 'Erro de conexão', descricao: 'Apps com erro de conexão', prompt: 'Aplicativos com erro de conexão. Analise e solucione.' },
        { titulo: 'Buffering constante', descricao: 'Apps com buffering', prompt: 'Apps com buffering constante. Diagnóstico e soluções.' },
        { titulo: 'Qualidade baixa', descricao: 'Qualidade baixa nos apps', prompt: 'Qualidade de streaming baixa. Diagnóstico e melhorias.' },
        { titulo: 'Error code', descricao: 'Códigos de erro específicos', prompt: 'App apresenta códigos de erro. Analise e forneça soluções.' },
        { titulo: 'App trava', descricao: 'Aplicativo trava durante uso', prompt: 'App para de responder ou trava durante uso.' },
        { titulo: 'Login não funciona', descricao: 'Problemas de autenticação', prompt: 'Não consegue fazer login nos aplicativos.' },
        { titulo: 'Conteúdo não carrega', descricao: 'Conteúdo dos apps não carrega', prompt: 'Apps abrem mas conteúdo não carrega.' }
      ];
    } else {
      items = [
        { titulo: 'Problema geral 1', descricao: `Problema relacionado a ${cat.nome}`, prompt: `Analise problema em ${cat.nome} e forneça soluções.` },
        { titulo: 'Problema geral 2', descricao: `Outro problema em ${cat.nome}`, prompt: `Diagnóstico de problema em ${cat.nome}.` }
      ];
    }

    items.forEach((item, index) => {
      checkmarks.push({
        tenant_id: tenant.id,
        categoria_id: cat.id,
        titulo: item.titulo,
        descricao: item.descricao,
        prompt_gemini: item.prompt,
        ativo: true,
        ordem: index + 1,
        global: false,
        data_criacao: new Date().toISOString()
      });
    });
  }

  await knex('checkmarks').insert(checkmarks);
  console.log(`✅ ${checkmarks.length} checkmarks criados`);
};