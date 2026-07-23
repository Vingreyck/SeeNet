const { db } = require('../config/database');
const IXCService = require('../services/IXCService');
const notificationService = require('../services/NotificationService');

class OrdensServicoController {
  /**
   * Buscar OSs do técnico logado (pendentes e em execução)
   * GET /api/ordens-servico/minhas
   */
  async buscarMinhasOSs(req, res) {
    try {
      const userId = req.user.id;
      const tenantId = req.tenantId;

      // ⚡ Sync SOB DEMANDA (best-effort): faz a OS nova do IXC aparecer na hora
      // em vez de esperar o ciclo de fundo (2min). É throttlado por técnico (20s)
      // no próprio sincronizador. Protegido por timeout curto: se o IXC demorar,
      // NÃO segura a resposta — devolve o que já está no banco e o sync termina
      // em background (a OS entra no próximo poll). Nunca deixa a busca falhar.
      try {
        const SincronizadorIXC = require('../services/SincronizadorIXC');
        const sync = SincronizadorIXC._instanciaAtiva;
        if (sync) {
          await Promise.race([
            sync.sincronizarTecnicoAgora(tenantId, userId),
            new Promise((resolve) => setTimeout(resolve, 6000)),
          ]);
        }
      } catch (_) { /* sync on-demand nunca quebra a listagem */ }

      // (sem log aqui — o app consulta isso o tempo todo; logar cada poll afoga o Railway)
      const rows = await db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.tecnico_id', userId)
        .where('os.tenant_id', tenantId)
        .whereIn('os.status', ['pendente', 'em_execucao', 'em_deslocamento', 'reaberta'])
        .select(
          'os.*',
          'u.nome as tecnico_nome'
        )
        .orderByRaw(`
          CASE os.prioridade
            WHEN 'urgente' THEN 1
            WHEN 'alta' THEN 2
            WHEN 'media' THEN 3
            WHEN 'baixa' THEN 4
          END
        `)
        .orderBy('os.data_criacao', 'desc');

      return res.json(rows);
    } catch (error) {
      console.error('❌ Erro ao buscar OSs:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar ordens de serviço',
        details: error.message
      });
    }
  }

  /**
   * ✅ NOVO: Buscar OSs concluídas do técnico
   * GET /api/ordens-servico/concluidas
   */
  async buscarOSsConcluidas(req, res) {
    try {
      const userId = req.user.id;
      const tenantId = req.tenantId;
      const { limite = 50, pagina = 1, busca = '' } = req.query;

      // (sem log de poll — mesma razão do buscarMinhasOSs)

      let query = db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.tecnico_id', userId)
        .where('os.tenant_id', tenantId)
        .where('os.status', 'concluida')
        .select(
          'os.*',
          'u.nome as tecnico_nome'
        );

      // Filtro de busca por nome do cliente
      if (busca && busca.trim() !== '') {
        query = query.whereRaw('LOWER(os.cliente_nome) LIKE ?', [`%${busca.toLowerCase()}%`]);
      }

      // Ordenar por data de conclusão (mais recentes primeiro)
      query = query.orderBy('os.data_conclusao', 'desc');

      // Paginação
      const offset = (parseInt(pagina) - 1) * parseInt(limite);
      query = query.limit(parseInt(limite)).offset(offset);

      const rows = await query;

      console.log(`✅ ${rows.length} OS(s) concluída(s) encontrada(s)`);

      return res.json(rows);
    } catch (error) {
      console.error('❌ Erro ao buscar OSs concluídas:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar ordens de serviço concluídas',
        details: error.message
      });
    }
  }

  /**
   * Buscar detalhes de uma OS específica
   * GET /api/ordens-servico/:id/detalhes
   */
  async buscarDetalhesOS(req, res) {
    try {
      const { id } = req.params;
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`🔍 Buscando detalhes da OS ${id}`);

      const os = await db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.id', id)
        .where('os.tenant_id', tenantId)
        .where('os.tecnico_id', userId)
        .select(
          'os.*',
          'u.nome as tecnico_nome',
          'u.email as tecnico_email'
        )
        .first();

      if (!os) {
        return res.status(404).json({
          success: false,
          error: 'OS não encontrada ou você não tem permissão para acessá-la'
        });
      }

      // Buscar anexos
      const anexos = await db('os_anexos')
        .where('ordem_servico_id', id)
        .select('id', 'tipo', 'url_arquivo', 'nome_arquivo', 'data_upload');

      os.anexos = anexos;

      console.log(`✅ Detalhes da OS ${id} obtidos`);

      return res.json(os);
    } catch (error) {
      console.error('❌ Erro ao buscar detalhes da OS:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar detalhes da OS'
      });
    }
  }

/**
 * Técnico iniciou deslocamento para a OS
 * POST /api/ordens-servico/:id/deslocar
 */
async deslocarParaOS(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { latitude, longitude, admin_responsavel_id } = req.body;  // ✅ NOVO: admin_responsavel_id
    const userId = req.user.id;
    const tenantId = req.tenantId;

    console.log(`🚗 Técnico deslocando para OS ${id} (admin responsável: ${admin_responsavel_id || 'nenhum'})`);

    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .forUpdate() // trava a linha: 2 ações simultâneas na MESMA OS não passam juntas
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    // Aceita 'pendente' (OS nova) e 'reaberta' (admin reabriu no IXC uma OS que
    // já estava concluída — Sincronizador marca como 'reaberta', ver SincronizadorIXC).
    // Sem 'reaberta' aqui, o deslocamento de OS reaberta caía em 400 silencioso.
    if (os.status !== 'pendente' && os.status !== 'reaberta') {
      await trx.rollback();
      console.warn(`⚠️ Deslocamento recusado: OS ${id} está em status '${os.status}' (esperado 'pendente' ou 'reaberta')`);
      return res.status(400).json({ success: false, error: 'OS já foi iniciada' });
    }

    // Atualizar status + admin responsável
    await trx('ordem_servico')
      .where('id', id)
      .update({
        status: 'em_deslocamento',
        latitude_inicio: latitude,
        longitude_inicio: longitude,
        admin_responsavel_id: admin_responsavel_id || null,  // ✅ NOVO
        data_inicio_deslocamento: db.fn.now(),
        data_atualizacao: db.fn.now()
      });

    await trx.commit();

    // Sincronizar com IXC FORA da transação: o HTTP ao IXC não deve segurar a
    // conexão do pool aberta durante a chamada externa. A falha do IXC já não
    // causava rollback antes (continua sendo best-effort).
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarDeslocamentoComIXC(db, os, { latitude, longitude });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar com IXC:', error.message);
      }
    }

    console.log(`✅ OS ${os.numero_os} - Técnico em deslocamento`);

    // ✅ NOTIFICAÇÃO: Avisar admin específico
    if (admin_responsavel_id) {
      try {
        const tecnico = await db('usuarios').where('id', userId).first();
        await notificationService.enviarParaUsuario(
          db,
          admin_responsavel_id,
          '🚗 Técnico em Deslocamento',
          `${tecnico.nome} iniciou deslocamento para OS #${os.numero_os} - ${os.cliente_nome}`,
          { route: '/ordens-servico', tipo: 'os_deslocamento', referencia_id: String(id) }
        );
      } catch (notifErr) {
        console.warn('⚠️ Falha ao notificar admin:', notifErr.message);
      }
    }

    return res.json({ success: true, message: 'Deslocamento iniciado com sucesso' });
  } catch (error) {
    try { await trx.rollback(); } catch (_) {}
    console.error('❌ Erro ao iniciar deslocamento:', error);
    return res.status(500).json({ success: false, error: 'Erro ao iniciar deslocamento' });
  }
}


/**
 * Sincronizar deslocamento com IXC (apenas como mensagem)
 *
 * LIMITAÇÃO DA API IXC:
 * O status "DS" (Deslocamento) só pode ser alterado pelo app "Inmap Service".
 * Não há endpoint público da API REST para mudar para este status.
 *
 * SOLUÇÃO:
 * Registramos o deslocamento como mensagem/interação no histórico da OS.
 */
async sincronizarDeslocamentoComIXC(trx, os, dados) {
  console.log(`🔄 Registrando deslocamento da OS ${os.numero_os} no IXC (como mensagem)...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', os.tecnico_id)
    .where('tenant_id', os.tenant_id)
    .first();

  const tecnico = await trx('usuarios')
    .where('id', os.tecnico_id)
    .first();

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  // Formatar data/hora
  const agora = new Date();
  const dataHora = agora.toLocaleString('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short'
  });

  // Montar mensagem completa
  const mensagem = `🚗 DESLOCAMENTO INICIADO

Técnico: ${tecnico.nome}
Data/Hora: ${dataHora}
${dados.latitude && dados.longitude ? `Coordenadas: ${dados.latitude}, ${dados.longitude}` : ''}

Status: Técnico a caminho do local de atendimento.

📱 Registrado via SeeNet`;

  // ⚠️ Não mudamos o status (IXC não permite via API)
  // Apenas registramos como mensagem no histórico
  await ixc.adicionarMensagemOS(parseInt(os.id_externo), {
    mensagem: mensagem,
    id_tecnico: mapeamento?.tecnico_ixc_id || '',
    latitude: dados.latitude || '',
    longitude: dados.longitude || ''
  });

  console.log(`✅ OS ${os.numero_os} - Deslocamento registrado como mensagem no IXC`);
}

/**
 * Técnico chegou ao local
 * POST /api/ordens-servico/:id/chegar-local
 */
async chegarAoLocal(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const userId = req.user.id;
    const tenantId = req.tenantId;

    console.log(`📍 Técnico chegou ao local da OS ${id}`);

    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .forUpdate() // trava a linha: 2 ações simultâneas na MESMA OS não passam juntas
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    if (os.status !== 'em_deslocamento') {
      await trx.rollback();
      return res.status(400).json({ success: false, error: 'OS não está em deslocamento' });
    }

    // Atualizar para "em_execucao"
    await trx('ordem_servico')
      .where('id', id)
      .update({
        status: 'em_execucao',
        latitude_execucao: latitude,
        longitude_execucao: longitude,
        data_inicio: db.fn.now(),
        data_atualizacao: db.fn.now()
      });

    await trx.commit();

    // Sincronizar com IXC FORA da transação: o HTTP ao IXC não deve segurar a
    // conexão do pool aberta durante a chamada externa. A falha do IXC já não
    // causava rollback antes (continua sendo best-effort).
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarExecucaoComIXC(db, os, { latitude, longitude });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar execução com IXC:', error.message);
      }
    }

        // ✅ NOTIFICAÇÃO: Avisar admin que técnico chegou
        if (os.admin_responsavel_id) {
          try {
            const tecnico = await db('usuarios').where('id', userId).first();
            await notificationService.enviarParaUsuario(
              db,
              os.admin_responsavel_id,
              '📍 Técnico Chegou ao Local',
              `${tecnico.nome} chegou no cliente - OS #${os.numero_os}`,
              { route: '/ordens-servico', tipo: 'os_chegada', referencia_id: String(id) }
            );
          } catch (notifErr) {
            console.warn('⚠️ Falha ao notificar admin:', notifErr.message);
          }
        }

    console.log(`✅ OS ${os.numero_os} em execução`);

    return res.json({
      success: true,
      message: 'Execução iniciada com sucesso'
    });
  } catch (error) {
    try { await trx.rollback(); } catch (_) {}
    console.error('❌ Erro ao iniciar execução:', error);
    return res.status(500).json({ success: false, error: 'Erro ao iniciar execução' });
  }
}

/**
 * Sincronizar execução com IXC
 */
async sincronizarExecucaoComIXC(trx, os, dados) {
  console.log(`🔄 Sincronizando execução da OS ${os.numero_os} com IXC...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', os.tecnico_id)
    .where('tenant_id', os.tenant_id)
    .first();

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  await ixc.executarOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamento?.tecnico_ixc_id,
    mensagem: 'Iniciando execução do serviço',
    data_inicio: os.data_inicio_deslocamento || new Date().toISOString(),
    latitude: dados.latitude,
    longitude: dados.longitude
  });

  console.log(`✅ OS ${os.numero_os} - Status "EX" (Execução) no IXC`);
}

/**
 * Reagendar OS (cliente não estava no local)
 * POST /api/ordens-servico/:id/reagendar
 * → IXC vira RAG (Aguardando Agendamento); local vira 'reagendada' (sai de "em campo").
 */
async reagendarOS(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { latitude, longitude, motivo } = req.body;
    const userId = req.user.id;
    const tenantId = req.tenantId;

    console.log(`📅 Reagendando OS ${id} (cliente ausente)...`);

    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .forUpdate() // trava a linha: ações simultâneas na MESMA OS não passam juntas
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    // Só reagenda OS que o técnico está de fato atendendo (foi ao local).
    if (!['em_deslocamento', 'em_execucao'].includes(os.status)) {
      await trx.rollback();
      return res.status(400).json({ success: false, error: 'OS não está em deslocamento/execução' });
    }

    // Status local 'reagendada' → sai de "em campo" (não é pendente nem concluída,
    // então o sincronizador NÃO mexe). Quando um atendente reagendar no IXC (a OS
    // volta pra Aberta/Agendada), o sync a traz de volta pra "pendente".
    await trx('ordem_servico')
      .where('id', id)
      .update({
        status: 'reagendada',
        data_atualizacao: db.fn.now()
      });

    await trx.commit();

    // Sincroniza com IXC FORA da transação (best-effort, igual chegar/finalizar).
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarReagendamentoComIXC(db, os, { latitude, longitude, motivo });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar reagendamento com IXC:', error.message);
      }
    }

    // Avisa o admin que a OS foi reagendada (cliente ausente).
    if (os.admin_responsavel_id) {
      try {
        const tecnico = await db('usuarios').where('id', userId).first();
        await notificationService.enviarParaUsuario(
          db,
          os.admin_responsavel_id,
          '📅 OS Reagendada',
          `${tecnico.nome} reagendou a OS #${os.numero_os} (cliente ausente)`,
          { route: '/ordens-servico', tipo: 'os_reagendada', referencia_id: String(id) }
        );
      } catch (notifErr) {
        console.warn('⚠️ Falha ao notificar admin:', notifErr.message);
      }
    }

    console.log(`✅ OS ${os.numero_os} reagendada (RAG)`);

    return res.json({
      success: true,
      message: 'OS reagendada com sucesso'
    });
  } catch (error) {
    try { await trx.rollback(); } catch (_) {}
    console.error('❌ Erro ao reagendar OS:', error);
    return res.status(500).json({ success: false, error: 'Erro ao reagendar OS' });
  }
}

/**
 * Sincronizar reagendamento com IXC (status RAG)
 */
async sincronizarReagendamentoComIXC(trx, os, dados) {
  console.log(`🔄 Sincronizando reagendamento da OS ${os.numero_os} com IXC...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', os.tecnico_id)
    .where('tenant_id', os.tenant_id)
    .first();

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  await ixc.reagendarOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamento?.tecnico_ixc_id,
    mensagem: dados.motivo || 'Reagendamento: cliente não estava no local (via SeeNet)',
    latitude: dados.latitude,
    longitude: dados.longitude
  });

  console.log(`✅ OS ${os.numero_os} - Status "RAG" (Aguardando Agendamento) no IXC`);
}

/**
 * Encaminhar OS para outro técnico
 * POST /api/ordens-servico/:id/encaminhar   body: { tecnico_id }
 * → some pra mim (troca o tecnico_id local) e aparece pro técnico destino.
 *   No IXC troca o técnico responsável (pro sync não reverter).
 */
async encaminharOS(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { tecnico_id, motivo } = req.body; // destino + mensagem do encaminhamento
    const userId = req.user.id;
    const tenantId = req.tenantId;

    if (!tecnico_id || parseInt(tecnico_id) === userId) {
      await trx.rollback();
      return res.status(400).json({ success: false, error: 'Técnico de destino inválido' });
    }

    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .forUpdate() // trava a linha
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    // Técnico de destino (mesma empresa, ativo)
    const alvo = await trx('usuarios')
      .where('id', tecnico_id)
      .where('tenant_id', tenantId)
      .where('ativo', true)
      .first();

    if (!alvo) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'Técnico de destino não encontrado' });
    }

    // Reatribui: troca o dono (some pra mim, aparece pro outro) e volta a
    // 'pendente' (o novo técnico começa do zero: deslocar → chegar → etc.).
    await trx('ordem_servico')
      .where('id', id)
      .update({
        tecnico_id: tecnico_id,
        status: 'pendente',
        data_atualizacao: db.fn.now()
      });

    await trx.commit();

    // IXC FORA da transação (best-effort): troca o técnico responsável no IXC
    // pra sincronização não reverter o encaminhamento.
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarEncaminhamentoComIXC(db, os, alvo, motivo);
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar encaminhamento com IXC:', error.message);
      }
    }

    // Avisa o técnico que RECEBEU a OS.
    try {
      const remetente = await db('usuarios').where('id', userId).first();
      await notificationService.enviarParaUsuario(
        db,
        tecnico_id,
        '📨 Nova OS encaminhada',
        `${remetente?.nome || 'Um técnico'} encaminhou a OS #${os.numero_os} para você`,
        { route: '/ordens-servico', tipo: 'os_encaminhada', referencia_id: String(id) }
      );
    } catch (notifErr) {
      console.warn('⚠️ Falha ao notificar técnico destino:', notifErr.message);
    }

    console.log(`✅ OS ${os.numero_os} encaminhada para ${alvo.nome}`);

    return res.json({ success: true, message: 'OS encaminhada com sucesso' });
  } catch (error) {
    try { await trx.rollback(); } catch (_) {}
    console.error('❌ Erro ao encaminhar OS:', error);
    return res.status(500).json({ success: false, error: 'Erro ao encaminhar OS' });
  }
}

/**
 * Sincronizar encaminhamento com IXC (troca o técnico responsável)
 */
async sincronizarEncaminhamentoComIXC(trx, os, alvo, motivo) {
  console.log(`🔄 Encaminhando OS ${os.numero_os} no IXC para ${alvo.nome}...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamentoAlvo = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', alvo.id)
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!mapeamentoAlvo?.tecnico_ixc_id) {
    throw new Error('Técnico de destino não está mapeado no IXC');
  }

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  // Encaminhamento REAL do IXC (Ações → Encaminhar): troca o colaborador
  // responsável (id_tecnico) e registra a mensagem/motivo. Mantém o setor.
  await ixc.encaminharOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamentoAlvo.tecnico_ixc_id,
    mensagem: motivo || `Encaminhada para ${alvo.nome} via SeeNet`
  });

  console.log(`✅ OS ${os.numero_os} - encaminhada no IXC p/ colaborador ${mapeamentoAlvo.tecnico_ixc_id}`);
}

/**
 * Finalizar execução de OS
 * POST /api/ordens-servico/:id/finalizar
 */
async finalizarExecucao(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    const tenantId = req.tenantId;
    const dados = req.body;

    console.log(`🏁 Finalizando execução da OS ${id}`);

    // 1. Buscar OS
    const os = await db('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .first();

    if (!os) {
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    if (os.status !== 'em_execucao') {
      return res.status(400).json({ success: false, error: 'OS não está em execução' });
    }

    // 2. Atualizar dados da OS no banco
    await db('ordem_servico')
      .where('id', id)
      .update({
        status: 'concluida',
        data_conclusao: new Date(),
        onu_modelo: dados.onu_modelo,
        onu_serial: dados.onu_serial,
        onu_status: dados.onu_status,
        onu_sinal_optico: dados.onu_sinal_optico,
        relato_problema: dados.relato_problema,
        relato_solucao: dados.relato_solucao,
        materiais_utilizados: dados.materiais_utilizados,
        observacoes: dados.observacoes,
        assinatura_cliente: dados.assinatura,
        data_atualizacao: new Date()
      });

    // 🗑️ OS finalizada → apaga o rascunho do wizard (não é mais necessário).
    try {
      await db('os_rascunho').where('tenant_id', tenantId).where('os_id', id).del();
    } catch (_) { /* best-effort */ }

    // 3. Buscar mapeamento do técnico IXC
    const mapeamentoTecnico = await db('mapeamento_tecnicos_ixc')
      .where('usuario_id', os.tecnico_id)
      .where('tenant_id', tenantId)
      .first();

    if (!mapeamentoTecnico) {
      console.warn('⚠️ Técnico não mapeado no IXC — continuando sem sync de técnico');
    }

    const tecnicoIdIxc = mapeamentoTecnico?.tecnico_ixc_id || null;

    // 4. Processar fotos
    let fotosBase64 = [];
    if (dados.fotos && dados.fotos.length > 0) {
      console.log(`📸 Processando ${dados.fotos.length} foto(s)...`);
      fotosBase64 = dados.fotos.map((foto, index) => ({
        tipo: foto.tipo || 'Foto',
        descricao: foto.descricao || `Foto ${index + 1}`,
        base64: foto.base64 || foto.data
      }));
    }

    // 5+6. Gerar PDFs em paralelo
    console.log('📄 Gerando PDFs em paralelo...');
    const tecnico = await db('usuarios').where('id', os.tecnico_id).first();

    // 📋 APR só para os assuntos que exigem Análise Preliminar de Risco:
    // 60 (instalação FTTH), 4 e 32. Nos demais, finaliza sem APR.
    let assuntoIdOS = '';
    try {
      const dIxc = os.dados_ixc
        ? (typeof os.dados_ixc === 'string' ? JSON.parse(os.dados_ixc) : os.dados_ixc)
        : {};
      assuntoIdOS = String(dIxc.id_assunto || dados.id_assunto || '');
    } catch (_) { assuntoIdOS = String(dados.id_assunto || ''); }
    const ASSUNTOS_COM_APR = ['60', '4', '32'];
    const geraApr = ASSUNTOS_COM_APR.includes(assuntoIdOS);

    const [aprResult, osResult] = await Promise.allSettled([
      (async () => {
        if (!geraApr) {
          console.log(`ℹ️ Assunto ${assuntoIdOS || 'N/D'} não exige APR — pulando geração`);
          return null;
        }
        const AprPdfService = require('../services/AprPdfService');
        return await AprPdfService.gerarPdfApr(id, tenantId);
      })(),
      (async () => {
        const OSPdfService = require('../services/OSPdfService');
        return await OSPdfService.gerarPdfOSDireto(os, dados, tecnico?.nome || 'Técnico', tenantId);
      })(),
    ]);

    let pdfBuffer    = aprResult.status === 'fulfilled' ? aprResult.value : null;
    let pdfAprBase64 = pdfBuffer ? pdfBuffer.toString('base64') : null;
    if (pdfBuffer)        console.log(`✅ PDF APR gerado (${pdfBuffer.length} bytes)`);
    else if (geraApr)     console.warn('⚠️ Erro ao gerar PDF APR:', aprResult.reason?.message);

    let pdfOSBuffer = osResult.status === 'fulfilled' ? osResult.value : null;
    if (pdfOSBuffer) console.log(`✅ PDF OS gerado (${pdfOSBuffer.length} bytes)`);
    else             console.warn('⚠️ Erro ao gerar PDF OS:', osResult.reason?.message);

    // ✅ RESPONDER AO TÉCNICO AGORA: a OS já está salva como 'concluida' no banco
    // e os PDFs já foram gerados. O técnico não precisa esperar a sincronização
    // com o IXC (que é a parte lenta e cujo resultado não vai nesta resposta).
    res.json({
      success: true,
      message: 'OS finalizada com sucesso',
      data: {
        os_id: id,
        numero_os: os.numero_os,
        status: 'finalizada',
        pdf_apr_gerado: pdfAprBase64 !== null,
        pdf_os_gerado: pdfOSBuffer !== null,
        fotos_enviadas: fotosBase64.length
      }
    });

    // ── A PARTIR DAQUI, RODA EM SEGUNDO PLANO (não trava o técnico) ──────────
    // Falhas do IXC aqui já eram silenciosas antes (capturadas e logadas), então
    // o que o técnico vê não muda — ele só para de esperar.
    (async () => {
     try {

    // 7. Conectar ao IXC
    console.log('🔄 Preparando sincronização com IXC...');
    let ixcService = null;

    if (os.id_externo) {
      try {
        const integracao = await db('integracao_ixc')
          .where('tenant_id', tenantId)
          .where('ativo', true)
          .first();

        if (!integracao) throw new Error('Integração IXC não configurada');

        ixcService = new IXCService(integracao.url_api, integracao.token_api);
        console.log('✅ Conexão IXC estabelecida');
      } catch (error) {
        console.error('⚠️ Erro ao conectar com IXC:', error.message);
      }
    }

    // 8. Enviar itens de estoque para o IXC
    if (dados.itens_estoque && dados.itens_estoque.length > 0 && ixcService) {
      console.log(`📦 Enviando ${dados.itens_estoque.length} item(ns) de estoque para o IXC...`);

      const mapeamentoEstoque = await db('mapeamento_tecnicos_ixc')
        .where('usuario_id', os.tecnico_id)
        .where('tenant_id', tenantId)
        .first();

      // Material/comodato da OS descontam da LOJA da cidade (id_almoxarifado_loja)
      // quando o admin mapeou; senão cai no almox pessoal do técnico (compat).
      // O EPI continua no almox pessoal (não passa por aqui).
      const idAlmox = mapeamentoEstoque?.id_almoxarifado_loja
        || mapeamentoEstoque?.id_almoxarifado
        || 22;
      const hoje = new Date();
      const dataFormatada = `${String(hoje.getDate()).padStart(2,'0')}/${String(hoje.getMonth()+1).padStart(2,'0')}/${hoje.getFullYear()}`;

      // Comodato precisa de id_contrato + filial_id → busca a OS no IXC uma vez
      // (quando há patrimônio ou quando falta o contrato).
      const temPatrimonio = dados.itens_estoque.some(i =>
        i.id_patrimonio && i.id_patrimonio !== '' && i.id_patrimonio !== '0');
      let idContratoIxc = os.id_contrato_ixc || '';
      let idFilialIxc = '';
      let idLoginIxc = '';
      if (os.id_externo && (!idContratoIxc || temPatrimonio)) {
        try {
          const osIxc = await ixcService.buscarDetalhesOS(os.id_externo);
          if (!idContratoIxc) idContratoIxc = osIxc?.id_contrato_kit || osIxc?.id_contrato || '';
          idFilialIxc = osIxc?.id_filial || '';
          idLoginIxc = osIxc?.id_login || ''; // login do cliente → vai no comodato
          console.log(`📋 id_contrato IXC: ${idContratoIxc} | filial: ${idFilialIxc} | login: ${idLoginIxc}`);
        } catch (e) {
          console.warn('⚠️ Não foi possível buscar dados da OS no IXC:', e.message);
        }
      }

      for (const item of dados.itens_estoque) {
        const ehPatrimonio = !!(item.id_patrimonio &&
          item.id_patrimonio !== '' &&
          item.id_patrimonio !== '0');

        try {
          if (ehPatrimonio && os.tipo_os !== 'E') {
            // 📦 COMODATO: patrimônio (roteador/ONU) entregue ao cliente → vai pra
            // aba COMODATO da OS via endpoint dedicado su_oss_mov_comodato_wiz.
            // Campos obrigatórios conforme doc do IXC (id_contrato, filial_id,
            // status_comodato='E', etc.). Antes ia como produto → caía em Produtos.
            await ixcService.adicionarComodatoOS({
              id_oss_mensagem:             '',
              id_saida:                    '',
              id_oss_chamado:              os.id_externo.toString(),
              id_contrato:                 (idContratoIxc || '').toString(),
              id_login:                    (idLoginIxc || '').toString(),
              id_patrimonio:               item.id_patrimonio.toString(),
              id_produto:                  item.id_produto.toString(),
              descricao:                   item.descricao || '',
              data:                        dataFormatada,
              id_unidade:                  '1',
              // Patrimônio SÓ pode sair do almox onde ele está fisicamente. Usa o
              // almox do próprio patrimônio (item.id_almoxarifado); só cai no almox
              // da loja se o app não mandar. Evita "Patrimônio está indisponível".
              id_almox:                    (item.id_almoxarifado && item.id_almoxarifado !== '0' && item.id_almoxarifado !== '')
                                             ? item.id_almoxarifado.toString()
                                             : idAlmox.toString(),
              filial_id:                   (idFilialIxc || '1').toString(),
              qtde_saida:                  item.quantidade.toString(),
              valor_unitario:              item.valor_unitario.toFixed(2),
              pcomissao:                   '',
              pdesconto:                   '',
              vdesconto:                   '',
              valor_total:                 item.valor_total.toFixed(2),
              patrimonio:                  item.id_patrimonio.toString(),
              // MAC: o que o técnico leu da ONU no wizard (dados.onu_mac) tem
              // prioridade; senão o MAC do patrimônio no IXC (item.mac).
              mac:                         dados.onu_mac || item.mac || '',
              numero_serie:                item.numero_serie || '',
              numero_patrimonial:          item.numero_patrimonial || '',
              garantia_oss:                '',
              id_terceiro_oss:             '',
              id_su_oss_kit_equipamento:   '',
              id_classificacao_tributaria: '1',
              tipo:                        'C',
              estoque:                     'S',
              unidade_sigla:               'UND',
              fator_conversao:             '1',
              tipo_produto:                item.tipo_produto || 'P',
              status_comodato:             'E',
              status_patrimonio:           '',
              ultima_situacao_patrimonio:  '',
              id_pedido_os:                '',
            });
          } else if (os.tipo_os === 'E') {
            await ixcService.adicionarProdutoEstruturaOS({
              id_oss_chamado:              os.id_externo,
              id_produto:                  item.id_produto,
              descricao:                   item.descricao || '',
              qtde_saida:                  item.quantidade.toString(),
              data:                        dataFormatada,
              id_unidade:                  '1',
              id_almox:                    idAlmox.toString(),
              id_classificacao_tributaria: '1',
              tipo:                        'C',
              estoque:                     'S',
              unidade_sigla:               'UND',
              fator_conversao:             '1.000000000',
              valor_unitario:              item.valor_unitario.toFixed(2),
              valor_total:                 item.valor_total.toFixed(2),
              id_estrutura:                '',
              id_oss_mensagem:             '',
              id_saida:                    '',
              id_su_oss_kit_equipamento:   '',
              tipo_produto:                '',
              saldo_produto:               '',
              ultima_situacao_patrimonio:  '',
              id_pedido_os:                '',
              pcomissao:                   '',
              pdesconto:                   '',
              vdesconto:                   '',
            });
          } else {
            // Produto de consumo (não-patrimônio) → aba Produtos da OS.
            await ixcService.adicionarProdutoOS({
              id_oss_chamado:              os.id_externo,
              id_produto:                  item.id_produto,
              descricao:                   item.descricao || '',
              qtde_saida:                  item.quantidade.toString(),
              data:                        dataFormatada,
              id_unidade:                  '1',
              id_almox:                    idAlmox.toString(),
              id_classificacao_tributaria: '1',
              // tipo='S' (Saída) — obrigatório p/ a venda gerada faturar. Antes ia
              // 'C', que o IXC grava vazio → venda travava em "aguardando faturamento".
              tipo:                        'S',
              estoque:                     'S',
              unidade_sigla:               'UND',
              fator_conversao:             '1.000000000',
              valor_unitario:              item.valor_unitario.toFixed(2),
              valor_total:                 item.valor_total.toFixed(2),
              id_patrimonio:               '',
              patrimonio:                  '',
              numero_serie:                '',
              numero_patrimonial:          '',
              tipo_produto:                'O',
              ultima_situacao_patrimonio:  '',
              garantia_oss:                '',
              pcomissao:                   '',
              pdesconto:                   '',
              vdesconto:                   '',
              id_oss_mensagem:             '',
              id_saida:                    '',
              id_terceiro_oss:             '',
              id_su_oss_kit_equipamento:   '',
              id_estrutura:                '',
              id_pedido_os:                '',
            });
          }
          console.log(`   ✅ ${ehPatrimonio ? '[COMODATO]' : '[PRODUTO]'} ${item.descricao} x${item.quantidade}`);
        } catch (estoqueError) {
          console.error(`   ❌ Erro ao enviar item ${item.descricao}:`, estoqueError.message);
        }
      }
    }

    // 9. Sincronizar finalização com IXC
    if (ixcService && os.id_externo) {
      try {
        console.log('🔄 Sincronizando com IXC...');

        // 9a. Garantir status EX no IXC antes de fechar
        try {
          await ixcService.executarOS(parseInt(os.id_externo), {
            id_tecnico_ixc: tecnicoIdIxc,
            mensagem: 'Técnico em execução',
          });
          console.log('✅ OS marcada como EX no IXC');
        } catch (exErr) {
          console.warn('⚠️ Não foi possível marcar como EX, tentando fechar direto:', exErr.message);
        }

        // 9b. Finalizar OS no IXC
        // 📋 Instalação FTTH (assunto 60): a mensagem é o CHECKLIST de fechamento
        // (modo completo BBnet). Nos demais casos, o relatório padrão.
        const chk = dados.checklist_instalacao;
        let mensagemFinal;
        if (chk) {
          const marca = (v) => v ? '(X) SIM | (  ) NÃO' : '(  ) SIM | (X) NÃO';
          mensagemFinal =
            `1 - ATENDIDO POR: ${chk.atendido_por || ''}\n` +
            `4 - HABILITOU ACESSO REMOTO: ${marca(chk.acesso_remoto)}\n` +
            `5 - MUDOU SENHA PADRÃO? ${marca(chk.senha_padrao)}\n` +
            `6 - ATIVOU IPV6: ${marca(chk.ipv6)}\n` +
            `7 - CLIENTE ASSINA: ${marca(chk.cliente_assina)}`;
        } else {
          mensagemFinal =
            `Serviço finalizado via SeeNet\n\n` +
            `PROBLEMA: ${dados.relato_problema || 'N/A'}\n` +
            `SOLUÇÃO: ${dados.relato_solucao   || 'N/A'}\n` +
            `MATERIAIS: ${dados.materiais_utilizados || 'Nenhum'}\n` +
            `OBS: ${dados.observacoes || 'Nenhuma'}`;
        }

        // 📍 Localização de FINALIZAÇÃO (capturada no app, obrigatória) → vai na
        // descrição da OS no IXC como prova de conclusão no local do cliente.
        if (dados.latitude_final && dados.longitude_final) {
          mensagemFinal +=
            `\n\n📍 LOCALIZAÇÃO DE FINALIZAÇÃO: ${dados.latitude_final}, ${dados.longitude_final}` +
            `\nMapa: https://www.google.com/maps/search/?api=1&query=${dados.latitude_final},${dados.longitude_final}`;
        }

        await ixcService.finalizarOS(os.id_externo, {
          mensagem_resposta: mensagemFinal,
          id_tecnico_ixc: tecnicoIdIxc,
          latitude: dados.latitude_final || '',
          longitude: dados.longitude_final || '',
          // 📋 Fechamento "modo completo" só na instalação FTTH (assunto 60):
          // viabilidade=1 (concluída c/ sucesso), resposta=48 (FECHAMENTO
          // INSTALAÇÃO), próxima tarefa=66 (auditoria de ativação), gera comissão.
          ...(chk ? {
            id_su_diagnostico: '1',
            id_resposta: '48',
            id_proxima_tarefa: '66',
            gera_comissao: 'S',
          // 📋 OS de cobrança (assunto 90): próxima tarefa escolhida pelo
          // técnico no popup (40=negociar débitos, 41=recepcionar
          // equipamentos, 43=cancelar contrato por inadimplência).
          } : dados.id_proxima_tarefa ? {
            id_proxima_tarefa: dados.id_proxima_tarefa.toString(),
          } : {})
        });
        console.log('✅ OS finalizada no IXC');

        // 📋 PDF do checklist de instalação → campo de arquivos da OS no IXC.
        let pdfChecklistBuffer = null;
        if (chk) {
          try {
            const ChecklistInstalacaoPdfService = require('../services/ChecklistInstalacaoPdfService');
            pdfChecklistBuffer = await ChecklistInstalacaoPdfService.gerar(
              os, chk, tecnico?.nome || 'Técnico', tenantId);
            console.log(`✅ PDF checklist instalação gerado (${pdfChecklistBuffer.length} bytes)`);
          } catch (e) {
            console.warn('⚠️ Erro ao gerar PDF checklist:', e.message);
          }
        }

        // 9c+9d+9e. Uploads em paralelo
        const uploads = [];

        if (pdfChecklistBuffer) {
          uploads.push(
            ixcService.uploadFotoOS(os.id_externo, os.cliente_id_externo, {
              buffer: pdfChecklistBuffer,
              descricao: `Checklist de Instalação - OS ${os.numero_os}`,
              nome: `Checklist_Instalacao_OS_${os.numero_os}.pdf`,
              ext: 'pdf'
            }).then(() => console.log('   ✅ PDF checklist enviado'))
              .catch(e  => console.error('   ❌ PDF checklist:', e.message))
          );
        }

        for (const foto of fotosBase64) {
          uploads.push(
            ixcService.uploadFotoOS(os.id_externo, os.cliente_id_externo, {
              base64: foto.base64,
              descricao: foto.descricao,
              nome: `foto_${Date.now()}.jpg`,
              ext: 'jpg'
            }).then(() => console.log(`   ✅ ${foto.descricao} enviada`))
              .catch(e  => console.error(`   ❌ ${foto.descricao}:`, e.message))
          );
        }

        if (pdfBuffer) {
          uploads.push(
            ixcService.uploadFotoOS(os.id_externo, os.cliente_id_externo, {
              buffer: pdfBuffer,
              descricao: `APR - Análise Preliminar de Risco - OS ${os.numero_os}`,
              nome: `APR_OS_${os.numero_os}.pdf`,
              ext: 'pdf'
            }).then(() => console.log('   ✅ PDF APR enviado'))
              .catch(e  => console.error('   ❌ PDF APR:', e.message))
          );
        }

        if (pdfOSBuffer) {
          uploads.push(
            ixcService.uploadFotoOS(os.id_externo, os.cliente_id_externo, {
              buffer: pdfOSBuffer,
              descricao: `Chamado Técnico - OS ${os.numero_os}`,
              nome: `OS_${os.numero_os}_${Date.now()}.pdf`,
              ext: 'pdf'
            }).then(() => console.log('   ✅ PDF OS enviado'))
              .catch(e  => console.error('   ❌ PDF OS:', e.message))
          );
        }

        if (uploads.length > 0) {
                  console.log(`📤 Enviando ${uploads.length} arquivo(s) em paralelo...`);
                  await Promise.allSettled(uploads);
                }

              } catch (ixcError) {
                console.error('❌ Erro ao sincronizar com IXC:', ixcError.message);
              }
            }

            // 10. Notificar admin
            if (os.admin_responsavel_id) {
      try {
        const tecnico = await db('usuarios').where('id', os.tecnico_id).first();
        await notificationService.enviarParaUsuario(
          db,
          os.admin_responsavel_id,
          '✅ OS Finalizada',
          `${tecnico.nome} finalizou a OS #${os.numero_os} - ${os.cliente_nome}`,
          { route: '/ordens-servico', tipo: 'os_finalizada', referencia_id: String(id) }
        );
      } catch (notifErr) {
        console.warn('⚠️ Falha ao notificar admin:', notifErr.message);
      }
    }

     } catch (bgErr) {
       console.error('❌ Erro na sincronização em background da OS:', bgErr.message);
     }
    })();

  } catch (error) {
    console.error('❌ Erro ao finalizar OS:', error);
    return res.status(500).json({
      success: false,
      error: 'Erro ao finalizar OS',
      details: error.message
    });
  }
}

  /**
   * Sincronizar finalização com IXC
   */
async sincronizarFinalizacaoComIXC(trx, os, dados) {
  console.log(`🔄 Sincronizando finalização da OS ${os.numero_os} com IXC...`);

  // Buscar configuração IXC
  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

// ✅ CORRETO — usa db direto (sem transação)
const mapeamentoTecnico = await db('mapeamento_tecnicos_ixc')
  .where('usuario_id', os.tecnico_id)
  .where('tenant_id', tenantId)
  .first();

if (!mapeamentoTecnico) {
  console.warn('⚠️ Técnico não mapeado no IXC — finalizando sem sync de técnico');
}

const tecnicoIdIxc = mapeamentoTecnico?.tecnico_ixc_id || null;

  // Montar mensagem completa
  let mensagemResposta = '';

  mensagemResposta += '═══════════════════════════════════\n';
  mensagemResposta += '  RELATÓRIO DE ATENDIMENTO TÉCNICO\n';
  mensagemResposta += '═══════════════════════════════════\n\n';

  if (dados.relato_problema) {
    mensagemResposta += '📋 PROBLEMA IDENTIFICADO:\n';
    mensagemResposta += `${dados.relato_problema}\n\n`;
  }

  if (dados.relato_solucao) {
    mensagemResposta += '✅ SOLUÇÃO APLICADA:\n';
    mensagemResposta += `${dados.relato_solucao}\n\n`;
  }

  if (dados.onu_modelo || dados.onu_serial || dados.onu_status) {
    mensagemResposta += '🔧 DADOS TÉCNICOS DA ONU:\n';
    if (dados.onu_modelo) mensagemResposta += `• Modelo: ${dados.onu_modelo}\n`;
    if (dados.onu_serial) mensagemResposta += `• Serial: ${dados.onu_serial}\n`;
    if (dados.onu_status) mensagemResposta += `• Status: ${dados.onu_status}\n`;
    if (dados.onu_sinal_optico) mensagemResposta += `• Sinal Óptico: ${dados.onu_sinal_optico} dBm\n`;
    mensagemResposta += '\n';
  }

  if (dados.materiais_utilizados) {
    mensagemResposta += '🛠️ MATERIAIS UTILIZADOS:\n';
    mensagemResposta += `${dados.materiais_utilizados}\n\n`;
  }

  if (dados.observacoes) {
    mensagemResposta += '💬 OBSERVAÇÕES ADICIONAIS:\n';
    mensagemResposta += `${dados.observacoes}\n\n`;
  }

  mensagemResposta += '═══════════════════════════════════\n';
  mensagemResposta += `📱 Atendimento via SeeNet\n`;
  mensagemResposta += '═══════════════════════════════════';

  // Criar cliente IXC
  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  // 1️⃣ Finalizar OS no IXC
  await ixc.finalizarOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamento.tecnico_ixc_id,
    mensagem_resposta: mensagemResposta,
    latitude: os.latitude || '',
    longitude: os.longitude || '',
    data_inicio: os.data_inicio,
    data_final: new Date().toISOString()
  });

  console.log(`✅ OS ${os.numero_os} sincronizada com IXC (Finalizada)`);

// 2️⃣ Enviar fotos para IXC (se houver)
if (dados.fotos && dados.fotos.length > 0) {
  console.log(`📸 Enviando ${dados.fotos.length} foto(s) para IXC...`);

  for (let i = 0; i < dados.fotos.length; i++) {
    const fotoData = dados.fotos[i];

    try {
      // Montar descrição completa
      const labelTipo = {
        'roteador': '📡 Roteador',
        'onu': '📦 ONU',
        'local': '🏠 Local',
        'antes': '📷 Antes',
        'depois': '✅ Depois',
        'problema': '⚠️ Problema',
        'outro': '📎 Outro'
      };

      const descricaoCompleta = fotoData.descricao
        ? `Foto ${i + 1} - ${labelTipo[fotoData.tipo] || fotoData.tipo}: ${fotoData.descricao}`
        : `Foto ${i + 1} - ${labelTipo[fotoData.tipo] || fotoData.tipo}`;

      await ixc.uploadFotoOS(
        parseInt(os.id_externo),
        parseInt(os.cliente_id),
        {
          descricao: descricaoCompleta,
          base64: fotoData.base64
        }
      );

      console.log(`✅ Foto ${i + 1}/${dados.fotos.length} enviada: ${descricaoCompleta}`);
    } catch (fotoError) {
      console.error(`❌ Erro ao enviar foto ${i + 1}:`, fotoError.message);
    }
  }
}
}
/**
   * ✅ Baixar relatório PDF do IXC em background
   * Executa após finalizar a OS sem bloquear a resposta
   */
  async baixarRelatorioPDFBackground(osId, osIdExterno, tenantId) {
    try {
      console.log(`📄 Iniciando download do relatório da OS ${osIdExterno} em background...`);

      // Aguardar 5 segundos para IXC processar/gerar o relatório
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Buscar integração IXC
      const integracao = await db('integracao_ixc')
        .where('tenant_id', tenantId)
        .where('ativo', true)
        .first();

      if (!integracao) {
        throw new Error('Integração IXC não configurada');
      }

      const ixc = new IXCService(integracao.url_api, integracao.token_api);

      // Buscar e baixar relatório
      const relatorio = await ixc.buscarRelatorioPDF(osIdExterno);

      // Salvar no banco
      await db('os_anexos').insert({
        ordem_servico_id: osId,
        tipo: 'relatorio',
        descricao: relatorio.descricao,
        url_arquivo: relatorio.buffer.toString('base64'),
        nome_arquivo: relatorio.nome,
        data_upload: db.fn.now()
      });

      console.log(`✅ Relatório PDF baixado e salvo: ${relatorio.nome}`);
    } catch (error) {
      console.error(`❌ Erro ao baixar relatório da OS ${osIdExterno}:`, error.message);
      // Não propaga erro - execução em background
    }
  }

/**
   * Listar admins do tenant (para o técnico escolher)
   * GET /api/ordens-servico/admins
   */
  async listarAdmins(req, res) {
    try {
      const tenantId = req.tenantId;

      const admins = await db('usuarios')
              .where('tenant_id', tenantId)
              .where('ativo', true)
              .where('tipo_usuario', 'administrador')
              .whereNot('id', req.user.id)
              .where('visivel_como_responsavel', true)
              .select('id', 'nome', 'email', 'foto_perfil')
              .orderBy('nome');

      return res.json({
        success: true,
        admins: admins
      });
    } catch (error) {
      console.error('❌ Erro ao listar admins:', error);
      return res.status(500).json({ success: false, error: 'Erro ao listar administradores' });
    }
  }

  /**
   * Listar técnicos da empresa (pra encaminhar OS). Só técnicos ATIVOS e
   * MAPEADOS no IXC (senão a OS encaminhada não sincroniza), menos o próprio.
   */
  async listarTecnicos(req, res) {
    try {
      const tenantId = req.tenantId;

      const tecnicos = await db('usuarios as u')
        .join('mapeamento_tecnicos_ixc as m', function () {
          this.on('m.usuario_id', 'u.id').andOn('m.tenant_id', 'u.tenant_id');
        })
        .where('u.tenant_id', tenantId)
        .where('u.ativo', true)
        .where('u.tipo_usuario', 'tecnico')
        .where('m.ativo', true)
        .whereNot('u.id', req.user.id)
        .select('u.id', 'u.nome', 'u.email', 'u.foto_perfil')
        .orderBy('u.nome');

      return res.json({ success: true, tecnicos });
    } catch (error) {
      console.error('❌ Erro ao listar técnicos:', error);
      return res.status(500).json({ success: false, error: 'Erro ao listar técnicos' });
    }
  }

  /**
     * Técnico envia localização ao vivo (a cada 10s durante deslocamento)
     * PUT /api/ordens-servico/:id/location
     */async atualizarLocalizacao(req, res) {
         try {
           const { id } = req.params;
           const { latitude, longitude, velocidade, precisao } = req.body;
           const userId = req.user.id;
           const tenantId = req.tenantId;

           // ✅ FIX: rejeitar id inválido antes de ir ao banco
           const osId = parseInt(id);
           if (!osId || isNaN(osId)) {
             return res.status(400).json({ success: false, error: 'ID da OS inválido' });
           }

           if (!latitude || !longitude) {
             return res.status(400).json({ success: false, error: 'Coordenadas obrigatórias' });
           }

           await db.raw(`
             INSERT INTO localizacao_tecnico (tenant_id, tecnico_id, ordem_servico_id, latitude, longitude, velocidade, precisao, atualizado_em)
             VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
             ON CONFLICT (tecnico_id, ordem_servico_id)
             DO UPDATE SET latitude = ?, longitude = ?, velocidade = ?, precisao = ?, atualizado_em = NOW()
           `, [tenantId, userId, osId, latitude, longitude, velocidade || null, precisao || null,
               latitude, longitude, velocidade || null, precisao || null]);

           // 🛣️ TRILHA (histórico p/ desenhar a rota no mapa do admin): guarda 1
           // ponto a cada ≥15s por OS. Best-effort — falha aqui NUNCA derruba o
           // tracking ao vivo acima.
           try {
             const ultimo = await db('localizacao_trilha')
               .where('ordem_servico_id', osId)
               .orderBy('id', 'desc')
               .select('criado_em')
               .first();
             const idadeMs = ultimo
               ? Date.now() - new Date(ultimo.criado_em).getTime()
               : Infinity;
             if (idadeMs >= 15000) {
               await db('localizacao_trilha').insert({
                 tenant_id: tenantId,
                 tecnico_id: userId,
                 ordem_servico_id: osId,
                 latitude,
                 longitude,
                 velocidade: velocidade || null,
                 precisao: precisao || null,
               });
             }
           } catch (trilhaErr) {
             console.warn('⚠️ Trilha não gravada:', trilhaErr.message);
           }

           return res.json({ success: true });
         } catch (error) {
           console.error('❌ Erro ao atualizar localização:', error.message);
           return res.status(500).json({ success: false, error: 'Erro ao atualizar localização' });
         }
       }

    /**
     * Admin consulta localização do técnico em uma OS
     * GET /api/ordens-servico/:id/location
     */
    async consultarLocalizacao(req, res) {
      try {
        const { id } = req.params;
        const tenantId = req.tenantId;

        // Verificar se é admin
        if (req.user.tipo_usuario !== 'administrador') {
          return res.status(403).json({ success: false, error: 'Apenas administradores' });
        }

        const localizacao = await db('localizacao_tecnico as l')
          .join('usuarios as u', 'u.id', 'l.tecnico_id')
          .join('ordem_servico as os', 'os.id', 'l.ordem_servico_id')
          .where('l.ordem_servico_id', id)
          .where('l.tenant_id', tenantId)
          .select(
            'l.latitude', 'l.longitude', 'l.velocidade', 'l.precisao', 'l.atualizado_em',
            'u.nome as tecnico_nome',
            'os.numero_os', 'os.cliente_nome', 'os.cliente_endereco', 'os.status as os_status'
          )
          .first();

        if (!localizacao) {
          return res.status(404).json({ success: false, error: 'Localização não encontrada' });
        }

        return res.json({
          success: true,
          data: localizacao
        });
      } catch (error) {
        console.error('❌ Erro ao consultar localização:', error.message);
        return res.status(500).json({ success: false, error: 'Erro ao consultar localização' });
      }
    }

    /**
     * Admin consulta a TRILHA (rota percorrida) do técnico numa OS.
     * GET /api/ordens-servico/:id/trilha → pontos em ordem cronológica.
     */
    async consultarTrilha(req, res) {
      try {
        const { id } = req.params;
        const tenantId = req.tenantId;

        if (req.user.tipo_usuario !== 'administrador') {
          return res.status(403).json({ success: false, error: 'Apenas administradores' });
        }

        const pontos = await db('localizacao_trilha')
          .where('ordem_servico_id', id)
          .where('tenant_id', tenantId)
          .orderBy('id', 'asc')
          .limit(2000)
          .select('latitude', 'longitude', 'velocidade', 'criado_em');

        return res.json({ success: true, data: pontos });
      } catch (error) {
        console.error('❌ Erro ao consultar trilha:', error.message);
        return res.status(500).json({ success: false, error: 'Erro ao consultar trilha' });
      }
    }

    /**
     * Admin lista todas as OSs em andamento que ele é responsável
     * GET /api/ordens-servico/acompanhamento
     */
    async listarAcompanhamento(req, res) {
      try {
        const userId = req.user.id;
        const tenantId = req.tenantId;

        if (req.user.tipo_usuario !== 'administrador') {
          return res.status(403).json({ success: false, error: 'Apenas administradores' });
        }

        const oss = await db('ordem_servico as os')
          .join('usuarios as t', 't.id', 'os.tecnico_id')
          .leftJoin('localizacao_tecnico as l', function() {
            this.on('l.tecnico_id', 'os.tecnico_id')
                .andOn('l.ordem_servico_id', 'os.id');
          })
          .where('os.admin_responsavel_id', userId)
          .where('os.tenant_id', tenantId)
          .whereIn('os.status', ['em_deslocamento', 'em_execucao'])
          .select(
            'os.id', 'os.numero_os', 'os.status', 'os.cliente_nome',
            'os.cliente_endereco', 'os.prioridade',
            'os.data_inicio_deslocamento',
            't.nome as tecnico_nome', 't.foto_perfil as tecnico_foto',
            'l.latitude', 'l.longitude', 'l.velocidade', 'l.atualizado_em'
          )
          .orderBy('os.data_inicio_deslocamento', 'desc');

        return res.json({
          success: true,
          data: oss
        });
      } catch (error) {
        console.error('❌ Erro ao listar acompanhamento:', error.message);
        return res.status(500).json({ success: false, error: 'Erro ao listar acompanhamento' });
      }
    }

    /**
     * Técnico para de enviar localização (limpar ao chegar)
     * DELETE /api/ordens-servico/:id/location
     */
    async pararLocalizacao(req, res) {
      try {
        const { id } = req.params;
        const userId = req.user.id;

        await db('localizacao_tecnico')
          .where('tecnico_id', userId)
          .where('ordem_servico_id', id)
          .delete();

        return res.json({ success: true });
      } catch (error) {
        console.error('❌ Erro ao parar localização:', error.message);
        return res.status(500).json({ success: false });
      }
    }

    /**
     * Histórico de atendimentos no mesmo endereço
     * GET /api/ordens-servico/:id/historico-endereco
     */
    async buscarHistoricoEndereco(req, res) {
      try {
        const { id } = req.params;
        const tenantId = req.tenantId;

        // Buscar o endereço da OS atual
        const osAtual = await db('ordem_servico')
          .where('id', id)
          .where('tenant_id', tenantId)
          .select('cliente_endereco', 'cliente_id_externo')
          .first();

        if (!osAtual) {
          return res.status(404).json({ success: false, error: 'OS não encontrada' });
        }

        // Buscar histórico pelo mesmo cliente_id_externo OU mesmo endereço
        let query = db('ordem_servico')
          .where('tenant_id', tenantId)
          .where('id', '!=', id)
          .where('status', 'concluida')
          .orderBy('data_conclusao', 'desc')
          .limit(5)
          .select(
            'id', 'numero_os', 'tipo_servico', 'cliente_nome',
            'relato_problema', 'relato_solucao', 'data_conclusao',
            'tecnico_id'
          );

        if (osAtual.cliente_id_externo) {
          query = query.where('cliente_id_externo', osAtual.cliente_id_externo);
        } else if (osAtual.cliente_endereco) {
          query = query.where('cliente_endereco', osAtual.cliente_endereco);
        } else {
          return res.json({ success: true, data: [] });
        }

        const historico = await query;

        // Buscar nome dos técnicos
        const tecnicoIds = [...new Set(historico.map(h => h.tecnico_id).filter(Boolean))];
        const tecnicos = tecnicoIds.length > 0
          ? await db('usuarios').whereIn('id', tecnicoIds).select('id', 'nome')
          : [];

        const tecnicoMap = {};
        tecnicos.forEach(t => { tecnicoMap[t.id] = t.nome; });

        const resultado = historico.map(h => ({
          ...h,
          tecnico_nome: tecnicoMap[h.tecnico_id] || 'Técnico',
          data_conclusao: h.data_conclusao,
        }));

        return res.json({ success: true, data: resultado });
      } catch (error) {
        console.error('❌ Erro ao buscar histórico do endereço:', error);
        return res.status(500).json({ success: false, error: error.message });
      }
    }

    /**
     * Salvar/atualizar a foto da FACHADA (frente da casa) do cliente da OS.
     * Chave = cliente_id_externo (1 foto por cliente, igual ao histórico de endereço).
     * Fica só no SeeNet — não sobe pro IXC.
     * POST /api/ordens-servico/:id/fachada  body: { foto_base64, mime? }
     */
    async salvarFachada(req, res) {
      try {
        const { id } = req.params;
        const tenantId = req.tenantId;
        const userId = req.user.id;
        const { foto_base64, mime, latitude, longitude } = req.body;

        if (!foto_base64) {
          return res.status(400).json({ success: false, error: 'foto_base64 é obrigatório' });
        }

        const os = await db('ordem_servico')
          .where('id', id).where('tenant_id', tenantId)
          .select('cliente_id_externo').first();
        if (!os) {
          return res.status(404).json({ success: false, error: 'OS não encontrada' });
        }
        if (!os.cliente_id_externo) {
          return res.status(400).json({ success: false, error: 'OS sem cliente_id_externo — não é possível vincular a foto da fachada' });
        }

        const existente = await db('foto_fachada')
          .where('tenant_id', tenantId)
          .where('cliente_id_externo', os.cliente_id_externo)
          .first();

        const dadosBase = {
          foto_base64,
          mime: mime || 'image/jpeg',
          tecnico_id: userId,
          os_id_origem: String(id),
        };
        // Coluna nova (lat/lng de onde a foto foi tirada) — se a migração ainda
        // não rodou nesse deploy, cai no fallback e salva sem coordenada.
        const dadosComLoc = (latitude != null && longitude != null)
          ? { ...dadosBase, latitude, longitude }
          : dadosBase;

        try {
          if (existente) {
            await db('foto_fachada').where('id', existente.id).update({ ...dadosComLoc, updated_at: db.fn.now() });
          } else {
            await db('foto_fachada').insert({ tenant_id: tenantId, cliente_id_externo: os.cliente_id_externo, ...dadosComLoc });
          }
        } catch (errLoc) {
          if (dadosComLoc === dadosBase) throw errLoc;
          console.warn('⚠️ Falha ao salvar lat/lng da fachada (migração pendente?), salvando sem coordenada:', errLoc.message);
          if (existente) {
            await db('foto_fachada').where('id', existente.id).update({ ...dadosBase, updated_at: db.fn.now() });
          } else {
            await db('foto_fachada').insert({ tenant_id: tenantId, cliente_id_externo: os.cliente_id_externo, ...dadosBase });
          }
        }

        console.log(`📷 Foto da fachada salva (cliente ${os.cliente_id_externo}, OS ${id})`);
        return res.json({ success: true, message: 'Foto da fachada salva' });
      } catch (error) {
        console.error('❌ Erro ao salvar foto da fachada:', error);
        return res.status(500).json({ success: false, error: error.message });
      }
    }

    /**
     * Buscar a foto da fachada do cliente desta OS (se existir).
     * GET /api/ordens-servico/:id/fachada  →  { success, data: {foto_base64, mime, data} | null }
     */
    async buscarFachada(req, res) {
      try {
        const { id } = req.params;
        const tenantId = req.tenantId;

        const os = await db('ordem_servico')
          .where('id', id).where('tenant_id', tenantId)
          .select('cliente_id_externo').first();
        if (!os || !os.cliente_id_externo) {
          return res.json({ success: true, data: null });
        }

        const foto = await db('foto_fachada')
          .where('tenant_id', tenantId)
          .where('cliente_id_externo', os.cliente_id_externo)
          .first();
        if (!foto) {
          return res.json({ success: true, data: null });
        }

        return res.json({
          success: true,
          data: {
            foto_base64: foto.foto_base64,
            mime: foto.mime || 'image/jpeg',
            data: foto.updated_at,
            tecnico_id: foto.tecnico_id,
            latitude: foto.latitude != null ? Number(foto.latitude) : null,
            longitude: foto.longitude != null ? Number(foto.longitude) : null,
          },
        });
      } catch (error) {
        console.error('❌ Erro ao buscar foto da fachada:', error);
        return res.status(500).json({ success: false, error: error.message });
      }
    }
/**
     * Dashboard de indicadores
     * GET /api/ordens-servico/dashboard
     */
    async buscarDashboard(req, res) {
      try {
        const tenantId = req.tenantId;
        const agora = new Date();
        const mes = parseInt(req.query.mes) || agora.getMonth() + 1;
        const ano = parseInt(req.query.ano) || agora.getFullYear();

        const inicioMes = new Date(ano, mes - 1, 1);
        const fimMes = new Date(ano, mes, 0, 23, 59, 59);

        const nomeMes = inicioMes.toLocaleDateString('pt-BR', {
          month: 'long', year: 'numeric'
        });

        const porStatus = await db('ordem_servico')
          .where('tenant_id', tenantId)
          .select('status')
          .count('id as total')
          .groupBy('status');

        const porTecnico = await db('ordem_servico as os')
          .join('usuarios as u', 'u.id', 'os.tecnico_id')
          .where('os.tenant_id', tenantId)
          .where('os.data_criacao', '>=', inicioMes)
          .where('os.data_criacao', '<=', fimMes)
          .select('u.nome as tecnico', 'os.status')
          .count('os.id as total')
          .groupBy('u.nome', 'os.status');

        const tempoMedio = await db('ordem_servico')
          .where('tenant_id', tenantId)
          .where('status', 'concluida')
          .whereNotNull('data_inicio')
          .whereNotNull('data_conclusao')
          .where('data_criacao', '>=', inicioMes)
          .where('data_criacao', '<=', fimMes)
          .select(
            db.raw('AVG(EXTRACT(EPOCH FROM (data_conclusao - data_inicio))/3600) as media_horas')
          ).first();

        const totalMes = await db('ordem_servico')
          .where('tenant_id', tenantId)
          .where('data_criacao', '>=', inicioMes)
          .where('data_criacao', '<=', fimMes)
          .count('id as total').first();

        const concluidasNoPrazo = await db('ordem_servico')
          .where('tenant_id', tenantId)
          .where('status', 'concluida')
          .where('data_criacao', '>=', inicioMes)
          .where('data_criacao', '<=', fimMes)
          .whereNotNull('data_agendamento')
          .whereRaw('data_conclusao <= data_agendamento')
          .count('id as total').first();

        // 📊 PRODUTIVIDADE por técnico (OSs CONCLUÍDAS no mês, pelos timestamps
        // que o fluxo já grava): deslocamento = data_inicio_deslocamento→data_inicio;
        // execução = data_inicio→data_conclusao. CASEs descartam negativos e
        // outliers (deslocamento >4h / execução >12h — OS esquecida aberta não
        // pode destruir a média).
        const produtividade = await db('ordem_servico as os')
          .join('usuarios as u', 'u.id', 'os.tecnico_id')
          .where('os.tenant_id', tenantId)
          .where('os.status', 'concluida')
          .whereNotNull('os.data_conclusao')
          .where('os.data_conclusao', '>=', inicioMes)
          .where('os.data_conclusao', '<=', fimMes)
          .groupBy('u.id', 'u.nome')
          .select(
            'u.nome as tecnico',
            db.raw('COUNT(os.id) as concluidas'),
            db.raw(`AVG(CASE
              WHEN os.data_inicio_deslocamento IS NOT NULL AND os.data_inicio IS NOT NULL
                AND os.data_inicio > os.data_inicio_deslocamento
                AND EXTRACT(EPOCH FROM (os.data_inicio - os.data_inicio_deslocamento)) < 14400
              THEN EXTRACT(EPOCH FROM (os.data_inicio - os.data_inicio_deslocamento))
            END) / 60 as media_deslocamento_min`),
            db.raw(`AVG(CASE
              WHEN os.data_inicio IS NOT NULL AND os.data_conclusao > os.data_inicio
                AND EXTRACT(EPOCH FROM (os.data_conclusao - os.data_inicio)) < 43200
              THEN EXTRACT(EPOCH FROM (os.data_conclusao - os.data_inicio))
            END) / 60 as media_execucao_min`)
          )
          .orderByRaw('COUNT(os.id) DESC');

        // Dias decorridos do mês consultado (p/ média de OSs/dia no app)
        const fimJanela = agora < fimMes ? agora : fimMes;
        const diasDecorridos = Math.max(
          1, Math.ceil((fimJanela - inicioMes) / 86400000));

        return res.json({
          success: true,
          data: {
            por_status: porStatus,
            por_tecnico: porTecnico,
            produtividade: produtividade.map(p => ({
              tecnico: p.tecnico,
              concluidas: parseInt(p.concluidas) || 0,
              media_deslocamento_min: p.media_deslocamento_min != null
                ? Math.round(parseFloat(p.media_deslocamento_min)) : null,
              media_execucao_min: p.media_execucao_min != null
                ? Math.round(parseFloat(p.media_execucao_min)) : null,
            })),
            dias_decorridos: diasDecorridos,
            tempo_medio_horas: parseFloat(tempoMedio?.media_horas || 0).toFixed(1),
            taxa_conclusao_prazo: totalMes?.total > 0
              ? Math.round((concluidasNoPrazo?.total / totalMes?.total) * 100)
              : 0,
            mes_referencia: nomeMes,
            mes_atual: mes,
            ano_atual: ano
          }
        });
      } catch (error) {
        console.error('❌ Erro ao buscar dashboard:', error);
        return res.status(500).json({ success: false, error: error.message });
      }
    }

    /**
     * Job de verificação de SLA
     */
    async verificarSLAs() {
      try {
        const agora = new Date();
        const em2horas = new Date(agora.getTime() + 2 * 60 * 60 * 1000);

        const ossProximas = await db('ordem_servico as os')
          .join('usuarios as t', 't.id', 'os.tecnico_id')
          .whereIn('os.status', ['pendente', 'em_deslocamento'])
          .whereNotNull('os.data_agendamento')
          .where('os.data_agendamento', '<=', em2horas)
          .where('os.data_agendamento', '>', agora)
          .whereNull('os.sla_notificado_em')
          .select(
            'os.id', 'os.numero_os', 'os.cliente_nome',
            'os.data_agendamento', 'os.admin_responsavel_id',
            'os.tecnico_id', 't.nome as tecnico_nome'
          );

        console.log(`⏰ SLA Check: ${ossProximas.length} OS(s) próximas do prazo`);

        for (const os of ossProximas) {
          try {
            const minutos = Math.round(
              (new Date(os.data_agendamento) - agora) / 60000
            );

            if (os.admin_responsavel_id) {
              await notificationService.enviarParaUsuario(
                db, os.admin_responsavel_id,
                '⚠️ SLA Próximo do Vencimento',
                `OS #${os.numero_os} - ${os.cliente_nome} vence em ${minutos} minutos (${os.tecnico_nome})`,
                { route: '/ordens-servico', tipo: 'sla_alerta', referencia_id: String(os.id) }
              );
            }

            await notificationService.enviarParaUsuario(
              db, os.tecnico_id,
              '⚠️ Prazo de Atendimento',
              `OS #${os.numero_os} - ${os.cliente_nome} deve ser atendida em ${minutos} minutos`,
              { route: '/ordens-servico', tipo: 'sla_alerta', referencia_id: String(os.id) }
            );

            await db('ordem_servico')
              .where('id', os.id)
              .update({ sla_notificado_em: agora });

          } catch (e) {
            console.error(`❌ Erro ao notificar SLA da OS ${os.numero_os}:`, e.message);
          }
        }
      } catch (error) {
        console.error('❌ Erro no job de SLA:', error.message);
      }
    }

  /**
   * 💾 Salvar o RASCUNHO do wizard no servidor (atrelado à OS). Chamado ao
   * reagendar/encaminhar → o próximo técnico continua de onde parou (todos os
   * dados: fotos, assinatura, produtos/patrimônios, ONU, relatos, APR...).
   * POST /api/ordens-servico/:id/rascunho  body: { dados: {...} }
   */
  async salvarRascunho(req, res) {
    try {
      const { id } = req.params;
      const tenantId = req.tenantId;
      const userId = req.user.id;
      const { dados } = req.body;

      if (dados == null) {
        return res.status(400).json({ success: false, error: 'dados é obrigatório' });
      }

      const os = await db('ordem_servico')
        .where('id', id).where('tenant_id', tenantId).select('id').first();
      if (!os) {
        return res.status(404).json({ success: false, error: 'OS não encontrada' });
      }

      const dadosStr = typeof dados === 'string' ? dados : JSON.stringify(dados);

      const existente = await db('os_rascunho')
        .where('tenant_id', tenantId).where('os_id', id).first();
      if (existente) {
        await db('os_rascunho').where('id', existente.id).update({
          dados: dadosStr, atualizado_por: userId, atualizado_em: db.fn.now(),
        });
      } else {
        await db('os_rascunho').insert({
          tenant_id: tenantId, os_id: id, dados: dadosStr, atualizado_por: userId,
        });
      }

      return res.json({ success: true });
    } catch (error) {
      console.error('❌ Erro ao salvar rascunho da OS:', error.message);
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  /**
   * 📥 Buscar o rascunho do wizard salvo no servidor pra esta OS.
   * GET /api/ordens-servico/:id/rascunho → { success, data: {...} | null }
   */
  async buscarRascunho(req, res) {
    try {
      const { id } = req.params;
      const tenantId = req.tenantId;

      const row = await db('os_rascunho')
        .where('tenant_id', tenantId).where('os_id', id).first();
      if (!row) return res.json({ success: true, data: null });

      let dados = row.dados;
      try { dados = typeof dados === 'string' ? JSON.parse(dados) : dados; } catch (_) {}
      return res.json({ success: true, data: dados });
    } catch (error) {
      console.error('❌ Erro ao buscar rascunho da OS:', error.message);
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  /**
   * 🗑️ Apagar o rascunho do wizard (chamado ao FINALIZAR a OS).
   * DELETE /api/ordens-servico/:id/rascunho
   */
  async deletarRascunho(req, res) {
    try {
      const { id } = req.params;
      const tenantId = req.tenantId;
      await db('os_rascunho').where('tenant_id', tenantId).where('os_id', id).del();
      return res.json({ success: true });
    } catch (error) {
      console.error('❌ Erro ao apagar rascunho da OS:', error.message);
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  /**
   * 🧹 Limpar MAC do login do cliente da OS (botão "Limpar MAC" do IXC).
   * POST /api/ordens-servico/:id/limpar-mac
   * O id_login é lido do dados_ixc da OS (o app não precisa mandar nada).
   */
  async limparMac(req, res) {
    try {
      const { id } = req.params;
      const tenantId = req.tenantId;

      const os = await db('ordem_servico')
        .where('id', id).where('tenant_id', tenantId)
        .select('dados_ixc').first();
      if (!os) {
        return res.status(404).json({ success: false, error: 'OS não encontrada' });
      }

      let idLogin = null;
      try {
        const d = typeof os.dados_ixc === 'string' ? JSON.parse(os.dados_ixc) : os.dados_ixc;
        idLogin = (d && d.id_login && d.id_login !== '0') ? d.id_login : null;
      } catch (_) {}
      if (!idLogin) {
        return res.status(400).json({ success: false, error: 'Esta OS não tem login vinculado — não dá pra limpar o MAC.' });
      }

      const integracao = await db('integracao_ixc')
        .where('tenant_id', tenantId).where('ativo', true).first();
      if (!integracao) {
        return res.status(400).json({ success: false, error: 'Integração IXC não configurada' });
      }
      const ixc = new IXCService(integracao.url_api, integracao.token_api);
      await ixc.limparMac(idLogin);

      return res.json({ success: true, message: 'MAC limpo com sucesso' });
    } catch (error) {
      console.error('❌ Erro ao limpar MAC:', error.message);
      return res.status(500).json({ success: false, error: error.message || 'Erro ao limpar MAC' });
    }
  }

}

module.exports = new OrdensServicoController();