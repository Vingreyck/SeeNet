const { db } = require('../config/database');
const notificationService = require('./NotificationService');
const IXCService = require('./IXCService');

class SincronizadorIXC {
  constructor() {
    this.intervalo = 300000; // 5 minutos
    this.sincronizacaoAtiva = false;
    this.intervalId = null;
    this.cacheClientes = new Map();
    this.cacheAssuntos = new Map();
    this.maxOSsPorSync = 10;
  }

  iniciar() {
    if (this.sincronizacaoAtiva) {
      console.log('⚠️ Sincronização já está ativa');
      return;
    }

    console.log('🚀 Iniciando sincronização automática com IXC...');
    console.log(`⏱️ Intervalo: ${this.intervalo / 1000} segundos`);
    console.log(`📊 Máximo: ${this.maxOSsPorSync} OSs por ciclo`);

    this.sincronizacaoAtiva = true;

    // Sincronizar imediatamente ao iniciar
    this.sincronizarTodasEmpresas();

    // Depois sincronizar a cada intervalo
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
  }

  async sincronizarTodasEmpresas() {
    try {
      console.log('\n🔄 === INICIANDO CICLO DE SINCRONIZAÇÃO ===');
      console.log(`⏰ ${new Date().toLocaleString('pt-BR')}`);

      // Buscar empresas com integração IXC ativa
      const integracoes = await db('integracao_ixc as i')
        .join('tenants as t', 't.id', 'i.tenant_id')
        .where('i.ativo', true)
        .select(
          'i.id',
          'i.tenant_id',
          'i.url_api',
          'i.token_api',
          'i.ultima_sincronizacao',
          't.nome as empresa_nome',
          't.codigo as codigo_empresa'
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
  const trx = await db.transaction();

  try {
    console.log(`\n📡 Sincronizando: ${integracao.empresa_nome}`);

    // Criar cliente IXC
    const ixc = new IXCService(integracao.url_api, integracao.token_api);

    // 1. Buscar mapeamento de técnicos
    const mapeamentos = await trx('mapeamento_tecnicos_ixc as m')
      .join('usuarios as u', 'u.id', 'm.usuario_id')
      .where('m.tenant_id', integracao.tenant_id)
      .where('m.ativo', true)
      .select(
        'm.usuario_id',
        'm.tecnico_ixc_id',
        'm.tecnico_ixc_nome',
        'u.nome as tecnico_seenet_nome'
      );

    console.log(`👷 ${mapeamentos.length} técnico(s) mapeado(s)`);

    if (mapeamentos.length === 0) {
      console.log('⚠️ Nenhum técnico mapeado, pulando sincronização');
      await trx.commit();
      return;
    }

    let totalOSsSincronizadas = 0;

    // 2. Para cada técnico mapeado, buscar suas OSs no IXC
    for (const mapeamento of mapeamentos) {
      try {
        console.log(`   🔍 Buscando OSs do técnico: ${mapeamento.tecnico_seenet_nome}`);

        // Buscar OSs abertas (A) ou em atendimento (EA) do técnico no IXC
        const ossIXC = await ixc.buscarOSs({
          tecnicoId: mapeamento.tecnico_ixc_id,
        });

        console.log(`   📋 ${ossIXC.length} OS(s) abertas no IXC`);

        // Limitar OSs por ciclo
        const ossParaProcessar = ossIXC.slice(0, this.maxOSsPorSync);

        if (ossIXC.length > this.maxOSsPorSync) {
          console.log(`   ⚠️ Limitando a ${this.maxOSsPorSync} OSs`);
        }

        // Coletar IDs externos para verificar cancelamentos
        const idsExternosIXC = ossIXC.map(os => os.id.toString());

        // 3. Sincronizar cada OS
        for (const osIXC of ossParaProcessar) {
          await this.sincronizarOS(trx, integracao.tenant_id, mapeamento.usuario_id, osIXC, ixc);
          totalOSsSincronizadas++;
        }


        // 4. Marcar OSs que não existem mais no IXC como canceladas
        // (apenas as que ainda estão pendentes ou em execução no SeeNet)
        const ossCanceladas = await trx('ordem_servico')
          .where('tenant_id', integracao.tenant_id)
          .where('tecnico_id', mapeamento.usuario_id)
          .where('origem', 'IXC')
          .whereIn('status', ['pendente']) // Não cancelar as que estão em execução
          .where(function() {
            if (idsExternosIXC.length > 0) {
              this.whereNotIn('id_externo', idsExternosIXC);
            }
          })
          .update({
            status: 'cancelada',
            data_atualizacao: db.fn.now()
          });

        if (ossCanceladas > 0) {
          console.log(`   🗑️ ${ossCanceladas} OS(s) cancelada(s) (não encontradas no IXC)`);
        }

      } catch (error) {
        console.error(`   ❌ Erro ao sincronizar técnico ${mapeamento.tecnico_seenet_nome}:`, error.message);
      }
    }

    // 5. Atualizar timestamp da última sincronização
    await trx('integracao_ixc')
      .where('id', integracao.id)
      .update({ ultima_sincronizacao: db.fn.now() });

    await trx.commit();
    console.log(`✅ Total: ${totalOSsSincronizadas} OS(s) sincronizada(s)`);
  } catch (error) {
    await trx.rollback();
    console.error(`❌ Erro ao sincronizar empresa ${integracao.empresa_nome}:`, error.message);
  }
}

  async sincronizarOS(trx, tenantId, tecnicoId, osIXC, ixcService) {
      try {
        // ✅ Guard
        if (!osIXC || !osIXC.id) {
          console.log('   ⚠️ OS do IXC sem dados, pulando');
          return;
        }

        // Verificar se a OS já existe no banco
        const osExistente = await trx('ordem_servico')
        .where('tenant_id', tenantId)
        .where('id_externo', osIXC.id.toString())
        .first();

      // Buscar dados do cliente se disponível
      let clienteNome = osIXC.cliente_nome || 'Cliente não identificado';
      let clienteEndereco = osIXC.endereco || null;
      let clienteTelefone = osIXC.telefone || null;

      if (osIXC.id_cliente && (!clienteNome || clienteNome === 'Cliente não identificado')) {
        // Verificar cache primeiro
        let clienteIXC = this.cacheClientes.get(osIXC.id_cliente);

        if (!clienteIXC) {
          try {
            clienteIXC = await ixcService.buscarCliente(osIXC.id_cliente);
            if (clienteIXC) {
              this.cacheClientes.set(osIXC.id_cliente, clienteIXC);
            }
          } catch (error) {
            console.error(`   ❌ Erro ao sincronizar OS ${osIXC.id}:`, error.message);
            console.error(`   ❌ Stack:`, error.stack); // ← adicionar isso
            console.error(`   ❌ Detail:`, error.detail); // ← e isso (erro de DB)
          }
        }

        if (clienteIXC) {
          clienteNome = clienteIXC.razao || clienteNome;
          clienteEndereco = clienteIXC.endereco || clienteEndereco;
          clienteTelefone = clienteIXC.telefone_celular || clienteIXC.telefone || clienteTelefone;
        }
      }

      // Mapear prioridade do IXC
      const prioridadeMap = {
        'A': 'alta',
        'M': 'media',
        'B': 'baixa',
        'U': 'urgente',
        'N': 'media'
      };
      const prioridade = prioridadeMap[osIXC.prioridade] || 'media';

      // Mapear status do IXC
      const statusMap = {
        'A': 'pendente',
        'AG': 'pendente',
        'EA': 'em_execucao',
        'E': 'em_execucao',
        'EX': 'em_execucao',
        'F': 'concluida',
        'C': 'cancelada'
      };
      const status = statusMap[osIXC.status] || 'pendente';

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
        tipo_servico: await this._resolverNomeAssunto(osIXC.id_assunto, ixcService) || osIXC.tipo_servico || this.obterTipoServico(osIXC.tipo),
        prioridade: prioridade,
        status: status,
        observacoes: osIXC.observacao || osIXC.mensagem || null,
        data_abertura: this.parseDataIXC(osIXC.data_abertura),
        data_agendamento: this.parseDataIXC(osIXC.data_agenda),
        data_inicio: this.parseDataIXC(osIXC.data_inicio),
        data_conclusao: this.parseDataIXC(osIXC.data_final),
        dados_ixc: JSON.stringify(osIXC),
        id_contrato_ixc: osIXC.id_contrato_kit?.toString() || osIXC.id_contrato?.toString() || '' // ✅ NOVO
      };

      if (osExistente) {
        if (osExistente.status !== 'concluida' && osExistente.status !== 'em_execucao') {
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
              data_atualizacao: db.fn.now()
            });
        }
      } else {
        // Inserir nova OS
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
  if (!idAssunto) {
    console.log('   ⚠️ id_assunto vazio/nulo');
    return null;
  }
  const idStr = idAssunto.toString();

  if (this.cacheAssuntos.has(idStr)) {
    return this.cacheAssuntos.get(idStr);
  }

  try {
    const nomeAssunto = await ixcService.buscarAssunto(idStr);
    console.log(`   📌 Assunto ${idStr} → "${nomeAssunto}"`);
    if (nomeAssunto) {
      this.cacheAssuntos.set(idStr, nomeAssunto);
    }
    return nomeAssunto;
  } catch (e) {
    console.error(`   ❌ Erro ao buscar assunto ${idStr}:`, e.message);
    return null;
  }
}

  parseDataIXC(dataString) {
    if (!dataString || dataString === '0000-00-00 00:00:00' || dataString === '0000-00-00') {
      return null;
    }
    try {
      const data = new Date(dataString);
      if (isNaN(data.getTime())) {
        return null;
      }
      return data;
    } catch (error) {
      return null;
    }
  }

  obterTipoServico(tipoIXC) {
    const tiposMap = {
      'I': 'Instalação',
      'M': 'Manutenção',
      'R': 'Reparo',
      'C': 'Comercial',
      'V': 'Visita Técnica'
    };
    return tiposMap[tipoIXC] || 'Manutenção';
  }
}

module.exports = SincronizadorIXC;