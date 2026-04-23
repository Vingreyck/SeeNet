// src/seeds/seed_pgr_catalogo_telecom.js
// Catálogo de perigos pré-populado para ISPs / Telecomunicações
// Baseado em NR-1, NR-6, NR-10, NR-12, NR-15, NR-16, NR-17, NR-21, NR-33, NR-35

exports.seed = async function(knex) {
  // Verifica se já existe catálogo global
  const existe = await knex('pgr_catalogo_perigos').whereNull('tenant_id').first();
  if (existe) {
    console.log('📋 Catálogo PGR telecom já existe, pulando seed');
    return;
  }

  console.log('🏗️ Populando catálogo de perigos para Telecomunicações...');

  const catalogo = [
    // ══════════════════════════════════════════════════════════
    // RISCOS DE ACIDENTE
    // ══════════════════════════════════════════════════════════
    {
      codigo: 'AC-01',
      tipo_risco: 'acidente',
      nome: 'Queda de altura — postes e escadas',
      descricao: 'Risco de queda durante trabalho em postes, torres, escadas extensíveis e estruturas elevadas para instalação e manutenção de cabos de fibra óptica e equipamentos.',
      fonte_geradora: 'Trabalho em postes de energia/telecom, uso de escadas extensíveis, subida em torres e caixas de emenda aéreas',
      possiveis_danos: 'Fraturas, traumatismo craniano, lesões medulares, óbito',
      nr_referencia: 'NR-35',
    },
    {
      codigo: 'AC-02',
      tipo_risco: 'acidente',
      nome: 'Choque elétrico — proximidade com rede energizada',
      descricao: 'Risco de contato direto ou indireto com condutores elétricos energizados durante trabalho em postes compartilhados com rede de energia elétrica.',
      fonte_geradora: 'Proximidade com rede elétrica de média e baixa tensão em postes compartilhados, cabos metálicos condutivos, ferramentas próximas a fios energizados',
      possiveis_danos: 'Queimaduras, fibrilação cardíaca, parada cardiorrespiratória, óbito',
      nr_referencia: 'NR-10',
    },
    {
      codigo: 'AC-03',
      tipo_risco: 'acidente',
      nome: 'Acidente de trânsito — deslocamento entre atendimentos',
      descricao: 'Risco de acidentes durante deslocamento em veículos (motos e carros) entre pontos de atendimento, especialmente em áreas rurais e estradas vicinais.',
      fonte_geradora: 'Condução de veículos em vias urbanas e rurais, pressão por tempo entre atendimentos, condições de tráfego adversas',
      possiveis_danos: 'Politraumatismo, fraturas, lesões cervicais, óbito',
      nr_referencia: 'NR-1',
    },
    {
      codigo: 'AC-04',
      tipo_risco: 'acidente',
      nome: 'Queda de objetos e materiais',
      descricao: 'Risco de queda de ferramentas, bobinas de cabo, equipamentos e materiais durante trabalho em altura ou transporte.',
      fonte_geradora: 'Manuseio de ferramentas e materiais em altura, transporte de escadas e bobinas de fibra óptica',
      possiveis_danos: 'Contusões, fraturas, traumatismo craniano em terceiros',
      nr_referencia: 'NR-35, NR-18',
    },
    {
      codigo: 'AC-05',
      tipo_risco: 'acidente',
      nome: 'Cortes e perfurações — manuseio de fibra e ferramentas',
      descricao: 'Risco de cortes por fibra óptica (fragmentos de vidro), facas de corte, alicates e ferramentas cortantes usadas na preparação de cabos.',
      fonte_geradora: 'Clivagem e preparação de fibra óptica, corte de cabos, uso de estiletes e ferramentas manuais',
      possiveis_danos: 'Cortes superficiais e profundos, perfuração de pele por fragmentos de fibra, infecções',
      nr_referencia: 'NR-6',
    },
    {
      codigo: 'AC-06',
      tipo_risco: 'acidente',
      nome: 'Mordida de animais — cães em residências',
      descricao: 'Risco de mordida de cães e outros animais domésticos ao acessar residências de clientes para instalação e manutenção.',
      fonte_geradora: 'Acesso a residências de clientes, áreas externas com animais soltos',
      possiveis_danos: 'Mordidas, lacerações, infecções, raiva',
      nr_referencia: 'NR-1',
    },
    {
      codigo: 'AC-07',
      tipo_risco: 'acidente',
      nome: 'Ataque de insetos — abelhas, marimbondos em postes',
      descricao: 'Risco de picadas de insetos (abelhas, marimbondos, aranhas) durante trabalho em postes, caixas de emenda e áreas externas.',
      fonte_geradora: 'Colmeias e ninhos em postes, caixas de emenda, áreas rurais',
      possiveis_danos: 'Reações alérgicas, choque anafilático, picadas múltiplas',
      nr_referencia: 'NR-21',
    },
    {
      codigo: 'AC-08',
      tipo_risco: 'acidente',
      nome: 'Arco elétrico por aproximação',
      descricao: 'Risco de arco elétrico quando cabos, cordoalhas ou ferramentas se aproximam de condutores de média tensão mesmo sem contato direto.',
      fonte_geradora: 'Lançamento de cabos em postes próximos à rede elétrica, uso de escadas metálicas, bobinas com cordoalha de aço',
      possiveis_danos: 'Queimaduras graves, projeção do trabalhador, óbito',
      nr_referencia: 'NR-10',
    },

    // ══════════════════════════════════════════════════════════
    // RISCOS FÍSICOS
    // ══════════════════════════════════════════════════════════
    {
      codigo: 'FI-01',
      tipo_risco: 'fisico',
      nome: 'Radiação solar — exposição prolongada a céu aberto',
      descricao: 'Exposição prolongada à radiação ultravioleta (UV) durante trabalho externo em postes, telhados e vias públicas.',
      fonte_geradora: 'Trabalho a céu aberto durante todo o dia, especialmente entre 10h e 16h no Nordeste',
      possiveis_danos: 'Insolação, queimaduras solares, desidratação, câncer de pele a longo prazo',
      nr_referencia: 'NR-21',
    },
    {
      codigo: 'FI-02',
      tipo_risco: 'fisico',
      nome: 'Calor excessivo — trabalho em ambiente aberto',
      descricao: 'Exposição a temperaturas elevadas durante trabalho externo, agravada pelo uso de EPIs como capacete e camisa manga longa.',
      fonte_geradora: 'Clima quente do semiárido sergipano, trabalho em postes sem sombra, uso de EPIs que retêm calor',
      possiveis_danos: 'Desidratação, exaustão por calor, cãibras, síncope térmica',
      nr_referencia: 'NR-15, NR-21',
    },
    {
      codigo: 'FI-03',
      tipo_risco: 'fisico',
      nome: 'Chuva e intempéries — trabalho em condições climáticas adversas',
      descricao: 'Exposição a chuva, ventos fortes e descargas atmosféricas durante trabalho externo.',
      fonte_geradora: 'Trabalho em postes e áreas abertas durante períodos chuvosos',
      possiveis_danos: 'Hipotermia, escorregamentos, descarga elétrica atmosférica, queda por superfície molhada',
      nr_referencia: 'NR-21',
    },
    {
      codigo: 'FI-04',
      tipo_risco: 'fisico',
      nome: 'Radiação não ionizante — equipamentos de transmissão',
      descricao: 'Exposição a radiação de radiofrequência (RF) emitida por antenas, rádios e equipamentos de transmissão wireless.',
      fonte_geradora: 'Proximidade com antenas de rádio e equipamentos de transmissão em torres e POPs',
      possiveis_danos: 'Efeitos térmicos nos tecidos, cefaleia, fadiga',
      nr_referencia: 'NR-15 Anexo 7',
    },

    // ══════════════════════════════════════════════════════════
    // RISCOS QUÍMICOS
    // ══════════════════════════════════════════════════════════
    {
      codigo: 'QU-01',
      tipo_risco: 'quimico',
      nome: 'Fragmentos de fibra óptica — micropartículas de vidro',
      descricao: 'Inalação ou contato cutâneo com micropartículas de vidro durante clivagem e emenda de fibra óptica.',
      fonte_geradora: 'Clivagem de fibra, limpeza de conectores, preparação de cabos em caixas de emenda',
      possiveis_danos: 'Irritação cutânea, microlesões, irritação ocular, inalação de partículas finas',
      nr_referencia: 'NR-9',
    },
    {
      codigo: 'QU-02',
      tipo_risco: 'quimico',
      nome: 'Produtos químicos de limpeza de conectores',
      descricao: 'Contato com álcool isopropílico e solventes usados na limpeza de conectores ópticos e ferramentas.',
      fonte_geradora: 'Limpeza de conectores com álcool isopropílico, uso de gel de emenda',
      possiveis_danos: 'Irritação de pele, dermatite, irritação ocular',
      nr_referencia: 'NR-9',
    },

    // ══════════════════════════════════════════════════════════
    // RISCOS BIOLÓGICOS
    // ══════════════════════════════════════════════════════════
    {
      codigo: 'BI-01',
      tipo_risco: 'biologico',
      nome: 'Contato com agentes biológicos em residências',
      descricao: 'Risco de contato com fungos, bactérias e parasitas ao acessar residências, forros, porões e áreas insalubres de clientes.',
      fonte_geradora: 'Acesso a forros de residências com acúmulo de sujeira, poeira e fezes de animais; contato com esgoto em áreas externas',
      possiveis_danos: 'Doenças de pele, infecções respiratórias, leptospirose, micoses',
      nr_referencia: 'NR-9',
    },

    // ══════════════════════════════════════════════════════════
    // RISCOS ERGONÔMICOS
    // ══════════════════════════════════════════════════════════
    {
      codigo: 'ER-01',
      tipo_risco: 'ergonomico',
      nome: 'Postura inadequada — trabalho em postes e espaços confinados',
      descricao: 'Manutenção de posturas forçadas e inadequadas durante trabalho em postes (braços elevados), caixas de emenda aéreas e espaços restritos.',
      fonte_geradora: 'Trabalho prolongado com braços acima da cabeça em postes, posição agachada em caixas subterrâneas',
      possiveis_danos: 'Dores musculoesqueléticas, LER/DORT, tendinite, lombalgia',
      nr_referencia: 'NR-17',
    },
    {
      codigo: 'ER-02',
      tipo_risco: 'ergonomico',
      nome: 'Sobrecarga de peso — transporte de equipamentos',
      descricao: 'Levantamento e transporte manual de escadas, bobinas de cabo, caixas de ferramentas e equipamentos pesados.',
      fonte_geradora: 'Transporte de escadas extensíveis (~15kg), bobinas de fibra (~10kg), caixa de ferramentas, máquinas de fusão',
      possiveis_danos: 'Lombalgia, hérnias de disco, lesões musculares',
      nr_referencia: 'NR-17',
    },
    {
      codigo: 'ER-03',
      tipo_risco: 'ergonomico',
      nome: 'Esforço repetitivo — fusão de fibra e crimpar conectores',
      descricao: 'Movimentos repetitivos de mãos e dedos durante fusão de fibra óptica, crimpagem de conectores e preparação de cabos.',
      fonte_geradora: 'Operação de máquina de fusão, decapagem de cabos, crimpagem repetitiva',
      possiveis_danos: 'Síndrome do túnel do carpo, tendinite, tenossinovite',
      nr_referencia: 'NR-17',
    },

    // ══════════════════════════════════════════════════════════
    // RISCOS PSICOSSOCIAIS (NR-1 atualizada 2025)
    // ══════════════════════════════════════════════════════════
    {
      codigo: 'PS-01',
      tipo_risco: 'psicossocial',
      nome: 'Pressão por produtividade e metas',
      descricao: 'Estresse causado por metas de atendimento diário, cobranças por tempo de execução e volume de ordens de serviço.',
      fonte_geradora: 'Metas de OSs diárias, pressão de supervisores e clientes, avaliação de desempenho',
      possiveis_danos: 'Estresse crônico, ansiedade, síndrome de burnout, distúrbios do sono',
      nr_referencia: 'NR-1 (riscos psicossociais)',
    },
    {
      codigo: 'PS-02',
      tipo_risco: 'psicossocial',
      nome: 'Trabalho isolado em áreas remotas',
      descricao: 'Atuação individual em áreas rurais e periféricas sem suporte imediato de colegas ou supervisão presencial.',
      fonte_geradora: 'Atendimentos em zona rural, áreas remotas sem sinal, trabalho individual sem dupla',
      possiveis_danos: 'Sensação de abandono, ansiedade, dificuldade de socorro em emergências',
      nr_referencia: 'NR-1',
    },
    {
      codigo: 'PS-03',
      tipo_risco: 'psicossocial',
      nome: 'Violência urbana — risco de assalto em campo',
      descricao: 'Risco de abordagem criminosa durante atendimentos em áreas com alto índice de violência, especialmente com equipamentos de valor.',
      fonte_geradora: 'Áreas periféricas, horários noturnos, transporte de equipamentos visíveis (escadas, ferramentas)',
      possiveis_danos: 'Trauma psicológico, lesões físicas, perda de equipamentos',
      nr_referencia: 'NR-1',
    },
    {
      codigo: 'PS-04',
      tipo_risco: 'psicossocial',
      nome: 'Jornada variável e irregular',
      descricao: 'Necessidade de atendimentos fora do horário comercial, plantões de emergência e jornadas prolongadas em dias de alta demanda.',
      fonte_geradora: 'Plantões de emergência, picos de demanda (chuvas, quedas de link), chamados urgentes fora do expediente',
      possiveis_danos: 'Fadiga crônica, distúrbios do sono, conflitos familiares, esgotamento',
      nr_referencia: 'NR-1',
    },
  ];

  // Inserir todos com tenant_id NULL (catálogo global)
  await knex('pgr_catalogo_perigos').insert(
    catalogo.map(p => ({ ...p, tenant_id: null }))
  );

  console.log(`✅ ${catalogo.length} perigos telecom cadastrados no catálogo global`);
};