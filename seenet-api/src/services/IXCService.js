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
    console.log('🔍 DEBUG IXC - Filtros recebidos:', filtros);
    console.log('🔍 DEBUG IXC - URL Base:', this.client.defaults.baseURL);

    // ✅ TESTE 1: Buscar SEM filtros para ver se endpoint existe
    console.log('🧪 TESTE 1: Chamando endpoint sem filtros...');
    try {
      const testResponse = await this.client.get('/su_oss_chamado');
      console.log('✅ TESTE 1 OK - Response type:', testResponse.data?.type);
      console.log('✅ TESTE 1 OK - Total registros:', testResponse.data?.total || 0);
    } catch (testError) {
      console.error('❌ TESTE 1 FALHOU:', testError.response?.data || testError.message);
    }

    // ✅ TESTE 2: Tentar com qtype tradicional (sem grid_param)
    console.log('🧪 TESTE 2: Chamando com qtype tradicional...');
    try {
      const test2Response = await this.client.get('/su_oss_chamado', {
        params: {
          qtype: 'su_oss_chamado.id_tecnico',
          query: filtros.tecnicoId?.toString() || '31',
          oper: 'igual'
        }
      });
      console.log('✅ TESTE 2 OK - Response type:', test2Response.data?.type);
      console.log('✅ TESTE 2 OK - Total registros:', test2Response.data?.total || 0);

      // Se funcionou, retornar esses registros
      if (test2Response.data?.type === 'success' || test2Response.data?.registros) {
        const registros = test2Response.data?.registros || [];
        console.log(`✅ ${registros.length} OSs encontradas no IXC`);
        return registros;
      }
    } catch (test2Error) {
      console.error('❌ TESTE 2 FALHOU:', test2Error.response?.data || test2Error.message);
    }

    // ✅ TESTE 3: Tentar com grid_param mas SEM status
    console.log('🧪 TESTE 3: Chamando com grid_param só técnico...');
    try {
      const test3Response = await this.client.get('/su_oss_chamado', {
        params: {
          grid_param: JSON.stringify([
            {
              TB: 'su_oss_chamado.id_tecnico',
              OP: '=',
              P: filtros.tecnicoId?.toString() || '31'
            }
          ])
        }
      });
      console.log('✅ TESTE 3 OK - Response type:', test3Response.data?.type);
      console.log('✅ TESTE 3 OK - Total registros:', test3Response.data?.total || 0);

      if (test3Response.data?.type === 'success' || test3Response.data?.registros) {
        const registros = test3Response.data?.registros || [];
        console.log(`✅ ${registros.length} OSs encontradas no IXC`);
        return registros;
      }
    } catch (test3Error) {
      console.error('❌ TESTE 3 FALHOU:', test3Error.response?.data || test3Error.message);
    }

    // ✅ TESTE 4: Listar todos os endpoints disponíveis
    console.log('🧪 TESTE 4: Verificando endpoints disponíveis...');
    try {
      const test4Response = await this.client.get('/');
      console.log('✅ TESTE 4 - Root response:', JSON.stringify(test4Response.data, null, 2));
    } catch (test4Error) {
      console.error('❌ TESTE 4 FALHOU:', test4Error.response?.data || test4Error.message);
    }

    console.log('❌ Todos os testes falharam!');
    return [];
  } catch (error) {
    console.error('❌ Erro geral ao buscar OSs do IXC:', error.message);
    return [];
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