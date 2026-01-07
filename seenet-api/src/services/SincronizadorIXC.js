const { db } = require('../config/database');
const IXCService = require('./IXCService');

class SincronizadorIXC {
  constructor() {
    this.intervalo = 60000; // 60 segundos
    this.sincronizacaoAtiva = false;
    this.intervalId = null;
  }

  iniciar() {
    if (this.sincronizacaoAtiva) {
      console.log('⚠️ Sincronização já está ativa');
      return;
    }

    console.log('🚀 Iniciando sincronização automática com IXC...');
    console.log(`⏱️ Intervalo: ${this.intervalo / 1000} segundos`);

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

      console.log('✅ Ciclo de sincronização concluído\n');
    } catch (error) {
      console.error('❌ Erro no ciclo de sincronização:', error);
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
        .join('usuarios as u', 'u.id', 'm.tecnico_seenet_id')
        .where('m.tenant_id', integracao.tenant_id)
        .select(
          'm.tecnico_seenet_id',
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

          // Buscar OSs abertas (não finalizadas) do técnico no IXC
          const ossIXC = await ixc.buscarOSs({
            tecnicoId: mapeamento.tecnico_ixc_id,
          });

          console.log(`   📋 ${ossIXC.length} OS(s) encontrada(s) no IXC`);

          // 3. Sincronizar cada OS
          for (const osIXC of ossIXC) {
            await this.sincronizarOS(trx, integracao.tenant_id, mapeamento.tecnico_seenet_id, osIXC, ixc);
            totalOSsSincronizadas++;
          }
        } catch (error) {
          console.error(`   ❌ Erro ao sincronizar técnico ${mapeamento.tecnico_seenet_nome}:`, error.message);
        }
      }

      // 4. Atualizar timestamp da última sincronização
      await trx('integracao_ixc')
        .where('id', integracao.id)
        .update({ ultima_sincronizacao: db.fn.now() });

      await trx.commit();
      console.log(`✅ Total: ${totalOSsSincronizadas} OS(s) sincronizada(s)`);
    } catch (error) {
      await trx.rollback();
      console.error(`❌ Erro ao sincronizar empresa ${integracao.empresa_nome}:`, error);
    }
  }

  async sincronizarOS(trx, tenantId, tecnicoId, osIXC, ixcService) {
    try {
      // Verificar se a OS já existe no banco
      const osExistente = await trx('ordem_servico')
        .where('tenant_id', tenantId)
        .where('id_externo', osIXC.id.toString())
        .first();

      // Buscar dados do cliente se disponível
      let clienteNome = osIXC.cliente_nome || 'Cliente não identificado';
      let clienteEndereco = osIXC.endereco || null;
      let clienteTelefone = osIXC.telefone || null;

      if (osIXC.id_cliente) {
        try {
          const clienteIXC = await ixcService.buscarCliente(osIXC.id_cliente);
          if (clienteIXC) {
            clienteNome = clienteIXC.razao || clienteNome;
            clienteEndereco = clienteIXC.endereco || clienteEndereco;
            clienteTelefone = clienteIXC.telefone_celular || clienteIXC.telefone || clienteTelefone;
          }
        } catch (error) {
          console.log(`   ⚠️ Não foi possível buscar dados do cliente ${osIXC.id_cliente}`);
        }
      }

      // Mapear prioridade do IXC
      const prioridadeMap = {
        'A': 'alta',
        'M': 'media',
        'B': 'baixa',
        'U': 'urgente'
      };
      const prioridade = prioridadeMap[osIXC.prioridade] || 'media';

      // Mapear status do IXC
      const statusMap = {
        'A': 'pendente',      // Aberta
        'E': 'em_execucao',   // Em execução
        'F': 'concluida',     // Finalizada
        'C': 'cancelada'      // Cancelada
      };
      const status = statusMap[osIXC.status] || 'pendente';

      const dadosOS = {
        numero_os: osIXC.numero_os || `IXC-${osIXC.id}`,
        origem: 'IXC',
        id_externo: osIXC.id.toString(),
        tenant_id: tenantId,
        tecnico_id: tecnicoId,
        cliente_nome: clienteNome,
        cliente_endereco: clienteEndereco,
        cliente_telefone: clienteTelefone,
        cliente_id_externo: osIXC.id_cliente?.toString(),
        tipo_servico: osIXC.tipo_servico || 'Manutenção',
        prioridade: prioridade,
        status: status,
        observacoes: osIXC.observacao || null,
        dados_ixc: JSON.stringify(osIXC)
      };

      if (osExistente) {
        // Atualizar OS existente (apenas se não estiver concluída no SeeNet)
        if (osExistente.status !== 'concluida') {
          await trx('ordem_servico')
            .where('id', osExistente.id)
            .update({
              status: dadosOS.status,
              prioridade: dadosOS.prioridade,
              observacoes: dadosOS.observacoes,
              dados_ixc: dadosOS.dados_ixc,
              data_atualizacao: db.fn.now()
            });

          console.log(`   ♻️ OS ${dadosOS.numero_os} atualizada`);
        }
      } else {
        // Inserir nova OS
        await trx('ordem_servico').insert(dadosOS);
        console.log(`   ✨ Nova OS ${dadosOS.numero_os} criada`);
      }
    } catch (error) {
      console.error(`   ❌ Erro ao sincronizar OS ${osIXC.id}:`, error.message);
    }
  }
}

module.exports = SincronizadorIXC;