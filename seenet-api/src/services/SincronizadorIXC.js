const { db } = require('../config/database');
const notificationService = require('./NotificationService');
const IXCService = require('./IXCService');

class SincronizadorIXC {
  constructor() {
    this.intervalo = 120000;
    this.sincronizacaoAtiva = false;
    this.intervalId = null;
    this.cacheClientes = new Map();
    this.cacheAssuntos = new Map();
    this.cacheFibra = new Map(); // login → dados de fibra (Caixa FTTH / Porta FTTH)
    this.cacheLogin = new Map(); // id_login → login string (o su_oss_chamado só traz id_login)
    this.maxOSsPorSync = 10;

    // ⚡ Sync SOB DEMANDA (técnico abriu/atualizou a lista) — throttle por técnico
    // pra não martelar o IXC se ficar batendo "atualizar".
    this._ultimoSyncTecnico = new Map(); // "tenant:usuario" → timestamp
    this.throttleTecnicoMs = 20000; // no máx 1 sync on-demand a cada 20s por técnico

    // ✅ Circuit breaker — para de tentar quando IXC está fora
    this.falhasConsecutivas = new Map(); // tenant_id → { count, pausadoAte }
    this.maxFalhas = 3;
    this.pausaDuracao = 10 * 60 * 1000; // 10 minutos
  }

  // ── Circuit Breaker ──────────────────────────────────────────

  _circuitAberto(tenantId) {
    const estado = this.falhasConsecutivas.get(tenantId);
    if (!estado) return false;

    if (estado.pausadoAte && Date.now() < estado.pausadoAte) {
      const restante = Math.ceil((estado.pausadoAte - Date.now()) / 60000);
      console.log(`⚡ [CB] Tenant ${tenantId} pausado — retomando em ${restante}min`);
      return true;
    }

    // Passou o tempo de pausa — resetar
    if (estado.pausadoAte && Date.now() >= estado.pausadoAte) {
      this.falhasConsecutivas.delete(tenantId);
      console.log(`✅ [CB] Circuit breaker FECHADO para tenant ${tenantId} — tentando novamente`);
    }

    return false;
  }

  _registrarFalha(tenantId, empresaNome) {
    const estado = this.falhasConsecutivas.get(tenantId) || { count: 0, pausadoAte: null };
    estado.count++;

    if (estado.count >= this.maxFalhas) {
      estado.pausadoAte = Date.now() + this.pausaDuracao;
      console.log(`⚡ [CB] Circuit breaker ABERTO — ${empresaNome} (${estado.count} falhas consecutivas)`);
      console.log(`   🕐 Próxima tentativa em 10 minutos`);

      // Notificar admin sobre IXC fora
      this._notificarCircuitAberto(tenantId, empresaNome).catch(() => {});
    }

    this.falhasConsecutivas.set(tenantId, estado);
  }

  _registrarSucesso(tenantId) {
    if (this.falhasConsecutivas.has(tenantId)) {
      const anterior = this.falhasConsecutivas.get(tenantId);
      if (anterior.count > 0) {
        console.log(`✅ [CB] IXC respondendo novamente para tenant ${tenantId}`);
      }
      this.falhasConsecutivas.delete(tenantId);
    }
  }

  async _notificarCircuitAberto(tenantId, empresaNome) {
    try {
      const admins = await db('usuarios')
        .where('tenant_id', tenantId)
        .where('tipo_usuario', 'administrador')
        .where('ativo', true)
        .select('id');

      for (const admin of admins) {
        await notificationService.enviarParaUsuario(
          db,
          admin.id,
          '⚡ Sincronização IXC pausada',
          `A conexão com o IXC de ${empresaNome} falhou 3 vezes. Sincronização pausada por 10 minutos.`,
          { tipo: 'circuit_breaker', route: '/admin/dashboard' }
        );
      }
    } catch (e) {
      // Não bloqueia
    }
  }

  // ── Ciclo principal ──────────────────────────────────────────

  iniciar() {
    if (this.sincronizacaoAtiva) {
      console.log('⚠️ Sincronização já está ativa');
      return;
    }

    console.log('🚀 Iniciando sincronização automática com IXC...');
    console.log(`⏱️ Intervalo: ${this.intervalo / 1000} segundos`);
    console.log(`📊 Máximo: ${this.maxOSsPorSync} OSs por ciclo`);

    this.sincronizacaoAtiva = true;
    // Expõe a instância ativa pro sync sob demanda (buscarMinhasOSs) reusar a
    // MESMA instância (mesmos caches, circuit breaker e mutex _cicloRodando).
    SincronizadorIXC._instanciaAtiva = this;
    this.sincronizarTodasEmpresas();

    this.intervalId = setInterval(() => {
      this.sincronizarTodasEmpresas();
    }, this.intervalo);
  }

  parar() {
    if (!this.sincronizacaoAtiva) {
      console.log('⚠️ Sincronização não está ativa');
      return;
    }

    console.log('🛑 Parando sincronização automática...');
    clearInterval(this.intervalId);
    this.sincronizacaoAtiva = false;
    this.cacheClientes.clear();
    this.cacheAssuntos.clear();
    this.falhasConsecutivas.clear();
  }

  async sincronizarTodasEmpresas() {
    // 🔒 Evita ciclos sobrepostos: se o ciclo anterior ainda está rodando (IXC
    // lento, demorou mais que o intervalo de 2min), pula este disparo em vez de
    // empilhar dois ciclos ao mesmo tempo.
    if (this._cicloRodando) {
      console.log('⏭️ Sincronização anterior ainda em andamento — pulando este ciclo');
      return;
    }
    this._cicloRodando = true;
    try {
      console.log('\n🔄 === INICIANDO CICLO DE SINCRONIZAÇÃO ===');
      console.log(`⏰ ${new Date().toLocaleString('pt-BR')}`);

      const integracoes = await db('integracao_ixc as i')
        .join('tenants as t', 't.id', 'i.tenant_id')
        .where('i.ativo', true)
        .select(
          'i.id', 'i.tenant_id', 'i.url_api', 'i.token_api',
          'i.ultima_sincronizacao', 't.nome as empresa_nome', 't.codigo as codigo_empresa'
        );

      console.log(`📋 ${integracoes.length} empresa(s) com integração ativa`);

      for (const integracao of integracoes) {
        await this.sincronizarEmpresa(integracao);
      }

      this.cacheClientes.clear();
      this.cacheFibra.clear();
      this.cacheLogin.clear();

      // 🛣️ Retenção da trilha GPS: apaga pontos com +7 dias (barato — indexado
      // por criado_em; na maioria dos ciclos deleta 0 linhas).
      try {
        await db('localizacao_trilha')
          .where('criado_em', '<', db.raw("NOW() - INTERVAL '7 days'"))
          .del();
      } catch (_) { /* tabela pode ainda não existir no 1º boot */ }

      console.log('✅ Ciclo de sincronização concluído\n');
    } catch (error) {
      console.error('❌ Erro no ciclo de sincronização:', error.message);
    } finally {
      this._cicloRodando = false;
    }
  }

  async sincronizarEmpresa(integracao) {
    // ✅ Circuit breaker — pular se IXC estiver fora
    if (this._circuitAberto(integracao.tenant_id)) return;

    const trx = await db.transaction();

    try {
      console.log(`\n📡 Sincronizando: ${integracao.empresa_nome}`);

      const ixc = new IXCService(integracao.url_api, integracao.token_api);

      const mapeamentos = await trx('mapeamento_tecnicos_ixc as m')
        .join('usuarios as u', 'u.id', 'm.usuario_id')
        .where('m.tenant_id', integracao.tenant_id)
        .where('m.ativo', true)
        .select(
          'm.usuario_id', 'm.tecnico_ixc_id', 'm.tecnico_ixc_nome',
          'u.nome as tecnico_seenet_nome'
        );

      console.log(`👷 ${mapeamentos.length} técnico(s) mapeado(s)`);

      if (mapeamentos.length === 0) {
        console.log('⚠️ Nenhum técnico mapeado, pulando sincronização');
        await trx.commit();
        return;
      }

      let totalOSsSincronizadas = 0;

      for (const mapeamento of mapeamentos) {
        try {
          const ossIXC = await ixc.buscarOSs({ tecnicoId: mapeamento.tecnico_ixc_id });

          // Só loga técnicos COM OS — antes eram 3 linhas × 33 técnicos × ciclo
          // de 2min (a maioria "0 OS"), o que afogava o log do Railway.
          if (ossIXC.length > 0) {
            console.log(`   📋 ${mapeamento.tecnico_seenet_nome}: ${ossIXC.length} OS(s) abertas no IXC`);
          }

          const ossParaProcessar = ossIXC.slice(0, this.maxOSsPorSync);
          const idsExternosIXC = ossIXC.map(os => os.id.toString());

          for (const osIXC of ossParaProcessar) {
            await this.sincronizarOS(trx, integracao.tenant_id, mapeamento.usuario_id, osIXC, ixc);
            totalOSsSincronizadas++;
          }

          // 🔒 SÓ cancela se o IXC retornou ALGUMA OS. Lista vazia pode ser
          // instabilidade do IXC (buscarOSs engole o erro e devolve []), e cancelar
          // tudo nesse caso apagaria OSs reais. Na dúvida, não cancela nada.
          if (idsExternosIXC.length > 0) {
            const ossCanceladas = await trx('ordem_servico')
              .where('tenant_id', integracao.tenant_id)
              .where('tecnico_id', mapeamento.usuario_id)
              .where('origem', 'IXC')
              .whereIn('status', ['pendente'])
              .whereNotIn('id_externo', idsExternosIXC)
              .update({ status: 'cancelada', data_atualizacao: db.fn.now() });

            if (ossCanceladas > 0) {
              console.log(`   🗑️ ${ossCanceladas} OS(s) cancelada(s)`);
            }

            // 🔄 OSs em_execucao/em_deslocamento que SUMIRAM da lista de abertas
            // provavelmente foram finalizadas/canceladas MANUALMENTE no IXC
            // (buscarOSs exclui status F e C). Sem isso, elas travam pra sempre
            // em "em campo" no app. Confere o status REAL de cada uma e só
            // sincroniza se o IXC confirmar F (concluída) ou C (cancelada) —
            // OS que o técnico está de fato executando continua na lista aberta
            // do IXC, então nem entra aqui.
            // ⚠️ INCLUI 'reaberta': OS reaberta no IXC que depois é finalizada ou
            // reatribuída SUMIA da lista de abertas mas ficava presa no app pra
            // sempre — o status 'reaberta' (criado na feature de reabertura) não
            // estava aqui. Foi o bug do "David com OSs que não são dele".
            const ossTravadas = await trx('ordem_servico')
              .where('tenant_id', integracao.tenant_id)
              .where('tecnico_id', mapeamento.usuario_id)
              .where('origem', 'IXC')
              .whereIn('status', ['pendente', 'reaberta', 'em_execucao', 'em_deslocamento'])
              .whereNotNull('id_externo')
              .whereNotIn('id_externo', idsExternosIXC)
              .select('id', 'id_externo', 'numero_os');

            for (const osTravada of ossTravadas) {
              try {
                const osReal = await ixc.buscarDetalhesOS(osTravada.id_externo);
                if (!osReal) continue; // não confirmou → não mexe (segurança)
                let novoStatus = null;
                if (osReal.status === 'F') novoStatus = 'concluida';
                else if (osReal.status === 'C') novoStatus = 'cancelada';
                else if (osReal.status === 'RAG') novoStatus = 'reagendada'; // "Necessário reagendar" no IXC
                // Ainda ABERTA no IXC, mas o dono agora é OUTRO técnico
                // (reatribuída) → tira da lista deste; o novo dono recebe pela
                // própria sync. Sem isso, ficava presa em "em campo".
                else if (osReal.id_tecnico &&
                         String(osReal.id_tecnico) !== String(mapeamento.tecnico_ixc_id)) {
                  novoStatus = 'cancelada';
                }
                if (novoStatus) {
                  const upd = { status: novoStatus, data_atualizacao: db.fn.now() };
                  if (novoStatus === 'concluida') upd.data_conclusao = db.fn.now();
                  await trx('ordem_servico').where('id', osTravada.id).update(upd);
                  console.log(`   🔄 OS ${osTravada.numero_os} → ${novoStatus} (mudou no IXC)`);
                }
              } catch (e) {
                // erro ao consultar o IXC → não mexe nessa OS
              }
            }
          }

        } catch (error) {
          console.error(`   ❌ Erro ao sincronizar técnico ${mapeamento.tecnico_seenet_nome}:`, error.message);
          // Erro por técnico não abre o circuit breaker — só erros de empresa inteira
        }
      }

      await trx('integracao_ixc')
        .where('id', integracao.id)
        .update({ ultima_sincronizacao: db.fn.now() });

      await trx.commit();

      // ✅ Registrar sucesso — fecha o circuit breaker se estava contando falhas
      this._registrarSucesso(integracao.tenant_id);

      console.log(`✅ Total: ${totalOSsSincronizadas} OS(s) sincronizada(s)`);

    } catch (error) {
      await trx.rollback();
      console.error(`❌ Erro ao sincronizar empresa ${integracao.empresa_nome}:`, error.message);

      // ✅ Registrar falha — pode abrir o circuit breaker
      this._registrarFalha(integracao.tenant_id, integracao.empresa_nome);
    }
  }

  /**
   * ⚡ Sincroniza SÓ um técnico, na hora (chamado quando o técnico abre/atualiza
   * a lista de OS). Faz a OS nova do IXC aparecer sem esperar o ciclo de 2min.
   *
   * Seguro por design:
   *  - throttle por técnico (não martela o IXC);
   *  - respeita o circuit breaker (IXC fora → nem tenta);
   *  - usa o MESMO mutex `_cicloRodando` do ciclo de fundo → NUNCA rodam juntos,
   *    logo sem corrida/duplicata/deadlock (mesma garantia de hoje);
   *  - só INSERE/ATUALIZA OS (via sincronizarOS). NÃO cancela nem mexe em OS
   *    "travada"/sumida — isso continua exclusivo do ciclo de fundo (conservador).
   *  - qualquer falha é engolida: a busca no banco segue normal.
   *
   * Retorna { ok, motivo? } — o chamador não precisa usar o retorno.
   */
  async sincronizarTecnicoAgora(tenantId, usuarioId) {
    const chave = `${tenantId}:${usuarioId}`;

    // Throttle: no máx 1 sync on-demand a cada throttleTecnicoMs por técnico
    const agora = Date.now();
    const ultima = this._ultimoSyncTecnico.get(chave) || 0;
    if (agora - ultima < this.throttleTecnicoMs) return { ok: false, motivo: 'throttle' };

    // Circuit breaker: IXC fora → não tenta (o ciclo de fundo cuida quando voltar)
    if (this._circuitAberto(tenantId)) return { ok: false, motivo: 'circuit' };

    // Mutex único: se QUALQUER sync está rodando (ciclo de fundo ou outro
    // on-demand), desiste — os dados vêm do banco e o ciclo cobre logo.
    // check + set SEM await entre eles = atômico no event loop (sem corrida).
    if (this._cicloRodando) return { ok: false, motivo: 'ocupado' };
    this._cicloRodando = true;
    this._ultimoSyncTecnico.set(chave, agora);

    let empresaNome = `tenant ${tenantId}`;
    try {
      const integracao = await db('integracao_ixc as i')
        .join('tenants as t', 't.id', 'i.tenant_id')
        .where('i.tenant_id', tenantId).where('i.ativo', true)
        .select('i.url_api', 'i.token_api', 't.nome as empresa_nome')
        .first();
      if (!integracao) return { ok: false, motivo: 'sem_integracao' };
      empresaNome = integracao.empresa_nome || empresaNome;

      const mapeamento = await db('mapeamento_tecnicos_ixc')
        .where('tenant_id', tenantId).where('usuario_id', usuarioId).where('ativo', true)
        .first();
      if (!mapeamento) return { ok: false, motivo: 'sem_mapeamento' };

      const ixc = new IXCService(integracao.url_api, integracao.token_api);
      const ossIXC = await ixc.buscarOSs({ tecnicoId: mapeamento.tecnico_ixc_id });
      const ossParaProcessar = ossIXC.slice(0, this.maxOSsPorSync);

      const trx = await db.transaction();
      try {
        for (const osIXC of ossParaProcessar) {
          await this.sincronizarOS(trx, tenantId, usuarioId, osIXC, ixc);
        }
        await trx.commit();
      } catch (e) {
        await trx.rollback();
        throw e;
      }

      // Mesmos caches temporários que o ciclo de fundo limpa a cada volta.
      this.cacheClientes.clear();
      this.cacheFibra.clear();
      this.cacheLogin.clear();

      this._registrarSucesso(tenantId);
      return { ok: true, total: ossParaProcessar.length };
    } catch (error) {
      console.error(`⚡ [on-demand] Erro ao sincronizar técnico ${usuarioId}:`, error.message);
      this._registrarFalha(tenantId, empresaNome);
      return { ok: false, motivo: 'erro' };
    } finally {
      this._cicloRodando = false;
    }
  }

  async sincronizarOS(trx, tenantId, tecnicoId, osIXC, ixcService) {
    try {
      if (!osIXC || !osIXC.id) {
        console.log('   ⚠️ OS do IXC sem dados, pulando');
        return;
      }

      const osExistente = await trx('ordem_servico')
        .where('tenant_id', tenantId)
        .where('id_externo', osIXC.id.toString())
        .first();

      let clienteNome = osIXC.cliente_nome || 'Cliente não identificado';
      let clienteEndereco = osIXC.endereco || null;
      let clienteTelefone = osIXC.telefone || null;
      let clienteNumero = osIXC.numero || null;
      let clienteBairro = osIXC.bairro || null;

      if (osIXC.id_cliente && (!clienteNome || clienteNome === 'Cliente não identificado' || !clienteNumero || !clienteBairro)) {
        let clienteIXC = this.cacheClientes.get(osIXC.id_cliente);

        if (!clienteIXC) {
          try {
            clienteIXC = await ixcService.buscarCliente(osIXC.id_cliente);
            if (clienteIXC) this.cacheClientes.set(osIXC.id_cliente, clienteIXC);
          } catch (error) {
            console.error(`   ❌ Erro ao buscar cliente ${osIXC.id_cliente}:`, error.message);
          }
        }

        if (clienteIXC) {
          clienteNome = clienteIXC.razao || clienteNome;
          clienteEndereco = clienteIXC.endereco || clienteEndereco;
          clienteTelefone = clienteIXC.telefone_celular || clienteIXC.telefone || clienteTelefone;
          clienteNumero = clienteIXC.numero || clienteNumero;
          clienteBairro = clienteIXC.bairro || clienteBairro;
        }
      }

      const prioridadeMap = { 'A': 'alta', 'M': 'media', 'B': 'baixa', 'U': 'urgente', 'N': 'media' };
      const prioridade = prioridadeMap[osIXC.prioridade] || 'media';

      const statusMap = {
        'A': 'pendente', 'AG': 'pendente', 'EN': 'pendente', 'EA': 'em_execucao',
        'E': 'em_execucao', 'EX': 'em_execucao', 'F': 'concluida', 'C': 'cancelada'
      };
      const status = statusMap[osIXC.status] || 'pendente';

      let nomeEstrutura = null;
      if (osIXC.tipo === 'E' && osIXC.id_estrutura && osIXC.id_estrutura !== '0') {
        try {
          const params = new URLSearchParams({
            qtype: 'estrutura.id', query: osIXC.id_estrutura,
            oper: '=', page: '1', rp: '1'
          });
          const resp = await ixcService.clientListar.post('/estrutura', params.toString());
          nomeEstrutura = resp.data?.registros?.[0]?.descricao || null;
          if (nomeEstrutura) console.log(`   🏗️ Estrutura ${osIXC.id_estrutura} → "${nomeEstrutura}"`);
        } catch (_) {}
      }

      // 🔑 LOGIN: o su_oss_chamado só traz `id_login` (numérico). Resolve a STRING
      // do login (ex: "copadomundo2026") p/ o card mostrar e a busca de fibra rodar.
      if (!osIXC.login && osIXC.id_login && osIXC.id_login !== '0') {
        let loginStr = this.cacheLogin.get(osIXC.id_login);
        if (loginStr === undefined) {
          loginStr = await ixcService.buscarLoginPorId(osIXC.id_login);
          this.cacheLogin.set(osIXC.id_login, loginStr);
        }
        if (loginStr) osIXC.login = loginStr;
      }

      // 🔌 FIBRA (Caixa FTTH / Porta FTTH) pro card — busca por login, com cache.
      // Merge no osIXC ANTES do JSON.stringify (o dados_ixc leva junto → o app lê).
      if (osIXC.login) {
        let fibra = this.cacheFibra.get(osIXC.login);
        if (fibra === undefined) {
          fibra = await ixcService.buscarClienteFibra(osIXC.login);
          this.cacheFibra.set(osIXC.login, fibra);
        }
        if (fibra) {
          // fallbacks — o log 🔎 [FIBRA] mostra os nomes reais; ajusto depois.
          osIXC.caixa_ftth = fibra.caixa_ftth || fibra.id_caixa_ftth ||
              fibra.caixa || fibra.caixa_hermetica || fibra.nome_caixa || '';
          osIXC.porta_ftth = fibra.porta_ftth || fibra.porta ||
              fibra.porta_ser || fibra.numero_porta || '';
        }
      }

      const dadosOS = {
        numero_os: osIXC.protocolo || `IXC-${osIXC.id}`,
        origem: 'IXC',
        id_externo: osIXC.id.toString(),
        tenant_id: tenantId,
        tecnico_id: tecnicoId,
        cliente_nome: clienteNome,
        cliente_endereco: clienteEndereco,
        cliente_numero: clienteNumero,
        cliente_bairro: clienteBairro,
        cliente_telefone: clienteTelefone,
        cliente_id_externo: osIXC.id_cliente?.toString(),
        tipo_servico: await this._resolverNomeAssunto(osIXC.id_assunto, ixcService) || this.obterTipoServico(osIXC.tipo),
        prioridade,
        status,
        observacoes: osIXC.observacao || osIXC.mensagem || null,
        data_abertura: this.parseDataIXC(osIXC.data_abertura),
        data_agendamento: this.parseDataIXC(osIXC.data_agenda),
        data_inicio: this.parseDataIXC(osIXC.data_inicio),
        data_conclusao: this.parseDataIXC(osIXC.data_final),
        dados_ixc: JSON.stringify(osIXC),
        tipo_os: osIXC.tipo || 'C',
        id_estrutura: (osIXC.id_estrutura && osIXC.id_estrutura !== '0') ? osIXC.id_estrutura : null,
        nome_estrutura: nomeEstrutura,
        id_contrato_ixc: osIXC.id_contrato_kit?.toString() || osIXC.id_contrato?.toString() || ''
      };

      if (osExistente) {
        const statusProtegidos = ['concluida', 'em_execucao', 'em_deslocamento'];

        // Admin mexeu direto no IXC → o app precisa RESPONDER:
        // (a) ENCAMINHADA: o técnico do IXC agora é OUTRO → a troca de dono vence
        //     a proteção (some pra quem tinha, aparece pro novo dono).
        const reatribuido = String(osExistente.tecnico_id) !== String(tecnicoId);
        // (b) REABERTA: estava 'concluida' aqui mas voltou a status ABERTO no IXC
        //     (admin usou "Reabrir") → reativa como 'reaberta' pro técnico.
        const reaberta = osExistente.status === 'concluida' &&
          ['pendente', 'em_execucao'].includes(dadosOS.status);

        const novoStatus = reaberta ? 'reaberta' : dadosOS.status;
        const deveAtualizar =
          !statusProtegidos.includes(osExistente.status) || reatribuido || reaberta;

        if (deveAtualizar) {
          await trx('ordem_servico')
            .where('id', osExistente.id)
            .update({
              tecnico_id: tecnicoId,
              status: novoStatus,
              tipo_servico: dadosOS.tipo_servico,
              prioridade: dadosOS.prioridade,
              observacoes: dadosOS.observacoes,
              data_abertura: dadosOS.data_abertura,
              data_agendamento: dadosOS.data_agendamento,
              dados_ixc: dadosOS.dados_ixc,
              id_contrato_ixc: dadosOS.id_contrato_ixc,
              tipo_os: dadosOS.tipo_os,
              id_estrutura: dadosOS.id_estrutura,
              nome_estrutura: dadosOS.nome_estrutura,
              data_atualizacao: db.fn.now()
            });

          if (reatribuido) {
            console.log(`   🔀 OS ${dadosOS.numero_os} reatribuída no IXC → técnico ${tecnicoId}`);
            try {
              await notificationService.notificarNovaOS(db, tecnicoId, dadosOS.numero_os, clienteNome);
            } catch (_) {}
          }
          if (reaberta) console.log(`   🔓 OS ${dadosOS.numero_os} REABERTA no IXC`);
        }
      } else {
        await trx('ordem_servico').insert(dadosOS);
        console.log(`   ✨ Nova OS ${dadosOS.numero_os} criada`);

        try {
          await notificationService.notificarNovaOS(db, tecnicoId, dadosOS.numero_os, clienteNome);
        } catch (notifErr) {
          console.warn('⚠️ Falha ao notificar técnico de nova OS:', notifErr.message);
        }
      }
    } catch (error) {
      console.error(`   ❌ Erro ao sincronizar OS ${osIXC.id}:`, error.message);
    }
  }

  async _resolverNomeAssunto(idAssunto, ixcService) {
    if (!idAssunto) return null;
    const idStr = idAssunto.toString();

    if (this.cacheAssuntos.has(idStr)) return this.cacheAssuntos.get(idStr);

    try {
      const nomeAssunto = await ixcService.buscarAssunto(idStr);
      console.log(`   🔎 Resposta assunto ${idStr}: "${nomeAssunto}"`);
      console.log(`   📌 Assunto ${idStr} → "${nomeAssunto}"`);
      if (nomeAssunto) this.cacheAssuntos.set(idStr, nomeAssunto);
      return nomeAssunto;
    } catch (e) {
      return null;
    }
  }

  parseDataIXC(dataString) {
    if (!dataString || dataString === '0000-00-00 00:00:00' || dataString === '0000-00-00') return null;
    try {
      const data = new Date(dataString);
      return isNaN(data.getTime()) ? null : data;
    } catch {
      return null;
    }
  }

  obterTipoServico(tipoIXC) {
    const tiposMap = { 'I': 'Instalação', 'M': 'Manutenção', 'R': 'Reparo', 'C': 'Comercial', 'V': 'Visita Técnica' };
    return tiposMap[tipoIXC] || 'Manutenção';
  }
}

module.exports = SincronizadorIXC;