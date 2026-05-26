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
    this.maxOSsPorSync = 10;

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
      console.log('🧹 Cache de clientes limpo');
      console.log('✅ Ciclo de sincronização concluído\n');
    } catch (error) {
      console.error('❌ Erro no ciclo de sincronização:', error.message);
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
          console.log(`   🔍 Buscando OSs do técnico: ${mapeamento.tecnico_seenet_nome}`);

          const ossIXC = await ixc.buscarOSs({ tecnicoId: mapeamento.tecnico_ixc_id });

          console.log(`✅ ${ossIXC.length}/${ossIXC.length} OSs ativas (técnico: ${mapeamento.tecnico_ixc_id})`);
          console.log(`   📋 ${ossIXC.length} OS(s) abertas no IXC`);

          const ossParaProcessar = ossIXC.slice(0, this.maxOSsPorSync);
          const idsExternosIXC = ossIXC.map(os => os.id.toString());

          for (const osIXC of ossParaProcessar) {
            await this.sincronizarOS(trx, integracao.tenant_id, mapeamento.usuario_id, osIXC, ixc);
            totalOSsSincronizadas++;
          }

          const ossCanceladas = await trx('ordem_servico')
            .where('tenant_id', integracao.tenant_id)
            .where('tecnico_id', mapeamento.usuario_id)
            .where('origem', 'IXC')
            .whereIn('status', ['pendente'])
            .where(function () {
              if (idsExternosIXC.length > 0) {
                this.whereNotIn('id_externo', idsExternosIXC);
              }
            })
            .update({ status: 'cancelada', data_atualizacao: db.fn.now() });

          if (ossCanceladas > 0) {
            console.log(`   🗑️ ${ossCanceladas} OS(s) cancelada(s)`);
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

      if (osIXC.id_cliente && (!clienteNome || clienteNome === 'Cliente não identificado')) {
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
        }
      }

      const prioridadeMap = { 'A': 'alta', 'M': 'media', 'B': 'baixa', 'U': 'urgente', 'N': 'media' };
      const prioridade = prioridadeMap[osIXC.prioridade] || 'media';

      const statusMap = {
        'A': 'pendente', 'AG': 'pendente', 'EA': 'em_execucao',
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

      const dadosOS = {
        numero_os: osIXC.protocolo || `IXC-${osIXC.id}`,
        origem: 'IXC',
        id_externo: osIXC.id.toString(),
        tenant_id: tenantId,
        tecnico_id: tecnicoId,
        cliente_nome: clienteNome,
        cliente_endereco: clienteEndereco,
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

        if (!statusProtegidos.includes(osExistente.status)) {
          await trx('ordem_servico')
            .where('id', osExistente.id)
            .update({
              tecnico_id: tecnicoId,
              status: dadosOS.status,
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