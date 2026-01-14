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
        'Content-Type': 'application/x-www-form-urlencoded',
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
    const params = new URLSearchParams({
      qtype: 'su_oss_chamado.id_tecnico',
      query: filtros.tecnicoId?.toString() || '',
      oper: 'igual',
      page: '1',
      rp: '50',
      sortname: 'su_oss_chamado.id',
      sortorder: 'desc',
    });

    // ✅ ADICIONAR LOGS AQUI
    console.log('🔍 DEBUG IXC - Filtros recebidos:', filtros);
    console.log('🔍 DEBUG IXC - Params montados:', params.toString());

    // Combinar filtros em array
    const gridParams = [];

    if (filtros.tecnicoId) {
      gridParams.push({
        TB: 'su_oss_chamado.id_tecnico',
        OP: '=',
        P: filtros.tecnicoId.toString()
      });
    }

    // ✅ BUSCAR STATUS A e EA
    gridParams.push({
      TB: 'su_oss_chamado.status',
      OP: 'IN',
      P: "('A','EA')"
    });

    if (gridParams.length > 0) {
      params.set('grid_param', JSON.stringify(gridParams));
    }

    // ✅ ADICIONAR LOG DA GRID_PARAM
    console.log('🔍 DEBUG IXC - Grid Params:', params.get('grid_param'));

    const response = await this.client.get('/su_oss_chamado', { params });

    // ✅ ADICIONAR LOG DA RESPOSTA COMPLETA
    console.log('🔍 DEBUG IXC - Response status:', response.status);
    console.log('🔍 DEBUG IXC - Response data:', JSON.stringify(response.data, null, 2));

    const registros = response.data?.registros || [];

    console.log(`✅ ${registros.length} OSs encontradas no IXC`);

    return registros;
  } catch (error) {
    console.error('❌ Erro ao buscar OSs do IXC:', error.message);
    if (error.response) {
      console.error('❌ Response status:', error.response.status);
      console.error('❌ Response data:', error.response.data);
    }
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

      const params = new URLSearchParams({
        qtype: 'id',
        query: osId.toString(),
        oper: '=',
        page: '1',
        rp: '1'
      });

      const response = await this.client.post('/su_oss_chamado', params.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
        }
      });

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

      const params = new URLSearchParams({
        qtype: 'id',
        query: clienteId.toString(),
        oper: '=',
        page: '1',
        rp: '1'
      });

      const response = await this.client.post('/cliente', params.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
        }
      });

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

      const params = new URLSearchParams({
        qtype: 'id',
        query: '',
        oper: '!=',
        page: '1',
        rp: '100'
      });

      const response = await this.client.post('/colaborador', params.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
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

      const payload = new URLSearchParams({
        id: osId.toString(),
        ...dados
      });

      const response = await this.client.post('/su_oss_chamado', payload.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
        }
      });

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

    const payload = new URLSearchParams({
      id: osId.toString(),
      status: 'F', // Finalizada
      mensagem_resposta: dados.mensagem_resposta || '',
      observacao: dados.observacoes || ''
    });

    const response = await this.client.post('/su_oss_chamado', payload.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'ixcsoft': 'alterar'  // ✅ Importante: usar 'alterar' para update
      }
    });

    console.log(`✅ OS ${osId} finalizada no IXC`);
    
    return response.data;
  } catch (error) {
    console.error(`❌ Erro ao finalizar OS ${osId} no IXC:`, error.message);
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
      
      const params = new URLSearchParams({
        qtype: 'id',
        query: '',
        oper: '!=',
        page: '1',
        rp: '1'
      });

      await this.client.post('/su_oss_chamado', params.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
        }
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