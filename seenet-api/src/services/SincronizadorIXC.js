const { Pool } = require('pg');
const IXCService = require('./IXCService');

class SincronizadorIXC {
  constructor() {
    this.pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false }
    });
    
    this.intervalo = 60000; // 60 segundos (1 minuto)
    this.sincronizacaoAtiva = false;
    this.intervalId = null;
  }

  /**
   * Iniciar sincronização automática
   */
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

  /**
   * Parar sincronização automática
   */
  parar() {
    if (!this.sincronizacaoAtiva) {
      console.log('⚠️ Sincronização não está ativa');
      return;
    }

    console.log('🛑 Parando sincronização automática...');
    
    clearInterval(this.intervalId);
    this.sincronizacaoAtiva = false;
  }

  /**
   * Sincronizar todas as empresas que têm integração IXC ativa
   */
  async sincronizarTodasEmpresas() {
    try {
      console.log('\n🔄 === INICIANDO CICLO DE SINCRONIZAÇÃO ===');
      console.log(`⏰ ${new Date().toLocaleString('pt-BR')}`);

      // Buscar empresas com integração IXC ativa
      const { rows: integracoes } = await this.pool.query(`
        SELECT 
          i.id,
          i.empresa_id,
          i.url_api,
          i.token_api,
          i.ultima_sincronizacao,
          e.nome as empresa_nome,
          e.codigo_empresa
        FROM integracao_ixc i
        JOIN empresas e ON e.id = i.empresa_id
        WHERE i.ativo = true
      `);

      console.log(`📋 ${integracoes.length} empresa(s) com integração ativa`);

      for (const integracao of integracoes) {
        await this.sincronizarEmpresa(integracao);
      }

      console.log('✅ Ciclo de sincronização concluído\n');
    } catch (error) {
      console.error('❌ Erro no ciclo de sincronização:', error);
    }
  }

  /**
   * Sincronizar OSs de uma empresa específica
   */
  async sincronizarEmpresa(integracao) {
    const client = await this.pool.connect();
    
    try {
      console.log(`\n📡 Sincronizando: ${integracao.empresa_nome}`);

      // Criar cliente IXC
      const ixc = new IXCService(integracao.url_api, integracao.token_api);

      // 1. Buscar mapeamento de técnicos
      const { rows: mapeamentos } = await client.query(`
        SELECT 
          m.tecnico_seenet_id,
          m.tecnico_ixc_id,
          m.tecnico_ixc_nome,
          u.nome as tecnico_seenet_nome
        FROM mapeamento_tecnicos_ixc m
        JOIN usuarios u ON u.id = m.tecnico_seenet_id
        WHERE m.empresa_id = $1
      `, [integracao.empresa_id]);

      console.log(`👷 ${mapeamentos.length} técnico(s) mapeado(s)`);

      if (mapeamentos.length === 0) {
        console.log('⚠️ Nenhum técnico mapeado, pulando sincronização');
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
            // Você pode adicionar filtros de data, ex: últimos 30 dias
          });

          console.log(`   📋 ${ossIXC.length} OS(s) encontrada(s) no IXC`);

          // 3. Sincronizar cada OS
          for (const osIXC of ossIXC) {
            await this.sincronizarOS(client, integracao.empresa_id, mapeamento.tecnico_seenet_id, osIXC, ixc);
            totalOSsSincronizadas++;
          }
        } catch (error) {
          console.error(`   ❌ Erro ao sincronizar técnico ${mapeamento.tecnico_seenet_nome}:`, error.message);
        }
      }

      // 4. Atualizar timestamp da última sincronização
      await client.query(`
        UPDATE integracao_ixc 
        SET ultima_sincronizacao = NOW()
        WHERE id = $1
      `, [integracao.id]);

      console.log(`✅ Total: ${totalOSsSincronizadas} OS(s) sincronizada(s)`);
    } catch (error) {
      console.error(`❌ Erro ao sincronizar empresa ${integracao.empresa_nome}:`, error);
    } finally {
      client.release();
    }
  }

  /**
   * Sincronizar uma OS específica do IXC para o banco SeeNet
   */
  async sincronizarOS(client, empresaId, tecnicoId, osIXC, ixcService) {
    try {
      // Verificar se a OS já existe no banco
      const { rows: osExistente } = await client.query(`
        SELECT id, status, updated_at
        FROM ordem_servico
        WHERE empresa_id = $1 AND id_externo = $2
      `, [empresaId, osIXC.id.toString()]);

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
        empresa_id: empresaId,
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

      if (osExistente.length > 0) {
        // Atualizar OS existente (apenas se não estiver concluída no SeeNet)
        if (osExistente[0].status !== 'concluida') {
          await client.query(`
            UPDATE ordem_servico
            SET 
              status = $1,
              prioridade = $2,
              observacoes = $3,
              dados_ixc = $4,
              updated_at = NOW()
            WHERE id = $5
          `, [
            dadosOS.status,
            dadosOS.prioridade,
            dadosOS.observacoes,
            dadosOS.dados_ixc,
            osExistente[0].id
          ]);

          console.log(`   ♻️ OS ${dadosOS.numero_os} atualizada`);
        }
      } else {
        // Inserir nova OS
        await client.query(`
          INSERT INTO ordem_servico (
            numero_os, origem, id_externo, empresa_id, tecnico_id,
            cliente_nome, cliente_endereco, cliente_telefone, cliente_id_externo,
            tipo_servico, prioridade, status, observacoes, dados_ixc
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        `, [
          dadosOS.numero_os,
          dadosOS.origem,
          dadosOS.id_externo,
          dadosOS.empresa_id,
          dadosOS.tecnico_id,
          dadosOS.cliente_nome,
          dadosOS.cliente_endereco,
          dadosOS.cliente_telefone,
          dadosOS.cliente_id_externo,
          dadosOS.tipo_servico,
          dadosOS.prioridade,
          dadosOS.status,
          dadosOS.observacoes,
          dadosOS.dados_ixc
        ]);

        console.log(`   ✨ Nova OS ${dadosOS.numero_os} criada`);
      }
    } catch (error) {
      console.error(`   ❌ Erro ao sincronizar OS ${osIXC.id}:`, error.message);
    }
  }
}

module.exports = SincronizadorIXC;