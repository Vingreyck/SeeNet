const axios = require('axios');
const crypto = require('crypto');

class IXCService {
  constructor(urlApi, tokenApi) {
    this.baseUrl = urlApi;
    this.token = tokenApi;
    
    // Criar cliente axios com configuração base
    this.client = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Basic ${Buffer.from(this.token).toString('base64')}`,
        'Content-Type': 'application/json',
      },
      timeout: 30000, // 30 segundos
    });
  }

  /**
   * Buscar OSs (chamados) do IXC
   * @param {Object} filtros - Filtros para busca
   * @returns {Array} Lista de OSs
   */
  async buscarOSs(filtros = {}) {
    try {
      console.log('🔍 Buscando OSs no IXC...', filtros);

      const params = {
        qtype: 'su_oss_chamado.id',
        query: filtros.id || '',
        oper: 'like',
        page: 1,
        rp: 1000, // Buscar até 1000 registros
        sortname: 'su_oss_chamado.id',
        sortorder: 'desc',
      };

      // Adicionar filtros opcionais
      if (filtros.tecnicoId) {
        params.grid_param = JSON.stringify([{
          TB: 'su_oss_chamado.id_tecnico',
          OP: '=',
          P: filtros.tecnicoId.toString()
        }]);
      }

      if (filtros.status) {
        params.grid_param = JSON.stringify([{
          TB: 'su_oss_chamado.status',
          OP: '=',
          P: filtros.status
        }]);
      }

      if (filtros.dataInicio) {
        params.grid_param = JSON.stringify([{
          TB: 'su_oss_chamado.data_abertura',
          OP: '>=',
          P: filtros.dataInicio
        }]);
      }

      const response = await this.client.get('/su_oss_chamado', { params });

      console.log(`✅ ${response.data.total || 0} OSs encontradas no IXC`);
      
      return response.data.registros || [];
    } catch (error) {
      console.error('❌ Erro ao buscar OSs no IXC:', error.message);
      throw error;
    }
  }

  /**
   * Buscar detalhes de uma OS específica
   * @param {number} osId - ID da OS no IXC
   * @returns {Object} Dados da OS
   */
  async buscarDetalhesOS(osId) {
    try {
      console.log(`🔍 Buscando detalhes da OS ${osId} no IXC...`);

      const response = await this.client.get(`/su_oss_chamado/${osId}`);

      console.log(`✅ Detalhes da OS ${osId} obtidos`);
      
      return response.data.registros?.[0] || response.data;
    } catch (error) {
      console.error(`❌ Erro ao buscar OS ${osId}:`, error.message);
      throw error;
    }
  }

  /**
   * Buscar dados do cliente
   * @param {number} clienteId - ID do cliente no IXC
   * @returns {Object} Dados do cliente
   */
  async buscarCliente(clienteId) {
    try {
      console.log(`👤 Buscando cliente ${clienteId} no IXC...`);

      const response = await this.client.get(`/cliente/${clienteId}`);

      console.log(`✅ Dados do cliente ${clienteId} obtidos`);
      
      return response.data.registros?.[0] || response.data;
    } catch (error) {
      console.error(`❌ Erro ao buscar cliente ${clienteId}:`, error.message);
      return null; // Não quebrar se não encontrar cliente
    }
  }

  /**
   * Listar técnicos do IXC
   * @returns {Array} Lista de técnicos
   */
  async listarTecnicos() {
    try {
      console.log('👷 Buscando técnicos no IXC...');

      const response = await this.client.get('/colaborador', {
        params: {
          qtype: 'colaborador.id',
          query: '',
          oper: 'like',
          page: 1,
          rp: 100,
        }
      });

      console.log(`✅ ${response.data.total || 0} técnicos encontrados`);
      
      return response.data.registros || [];
    } catch (error) {
      console.error('❌ Erro ao buscar técnicos:', error.message);
      throw error;
    }
  }

  /**
   * Atualizar/Finalizar OS no IXC
   * @param {number} osId - ID da OS no IXC
   * @param {Object} dados - Dados para atualizar
   * @returns {Object} Resposta do IXC
   */
  async atualizarOS(osId, dados) {
    try {
      console.log(`📝 Atualizando OS ${osId} no IXC...`);

      const payload = {
        id: osId,
        ...dados
      };

      const response = await this.client.post(`/su_oss_chamado`, payload);

      console.log(`✅ OS ${osId} atualizada com sucesso no IXC`);
      
      return response.data;
    } catch (error) {
      console.error(`❌ Erro ao atualizar OS ${osId}:`, error.message);
      throw error;
    }
  }

  /**
   * Finalizar OS no IXC
   * @param {number} osId - ID da OS no IXC
   * @param {Object} dados - Dados da finalização
   * @returns {Object} Resposta do IXC
   */
  async finalizarOS(osId, dados) {
    try {
      console.log(`✅ Finalizando OS ${osId} no IXC...`);

      const payload = {
        id: osId,
        status: 'F', // F = Finalizada
        data_finalizacao: new Date().toISOString().split('T')[0],
        observacao: dados.observacoes || '',
        tecnico_executante: dados.tecnicoId,
      };

      // Adicionar informações extras se disponíveis
      if (dados.relatoProblema) {
        payload.diagnostico = dados.relatoProblema;
      }

      if (dados.relatoSolucao) {
        payload.solucao = dados.relatoSolucao;
      }

      if (dados.materiaisUtilizados) {
        payload.materiais = dados.materiaisUtilizados;
      }

      const response = await this.client.post(`/su_oss_chamado`, payload);

      console.log(`✅ OS ${osId} finalizada com sucesso no IXC`);
      
      return response.data;
    } catch (error) {
      console.error(`❌ Erro ao finalizar OS ${osId}:`, error.message);
      throw error;
    }
  }

  /**
   * Testar conexão com IXC
   * @returns {boolean} true se conectou com sucesso
   */
  async testarConexao() {
    try {
      console.log('🧪 Testando conexão com IXC...');
      
      await this.client.get('/su_oss_chamado', {
        params: { page: 1, rp: 1 }
      });

      console.log('✅ Conexão com IXC OK');
      return true;
    } catch (error) {
      console.error('❌ Falha na conexão com IXC:', error.message);
      return false;
    }
  }
}

module.exports = IXCService;