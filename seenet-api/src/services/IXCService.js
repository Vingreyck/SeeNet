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
      // ✅ USAR POST COMO OS OUTROS MÉTODOS
      const params = new URLSearchParams({
        qtype: 'su_oss_chamado.id_tecnico',
        query: filtros.tecnicoId?.toString() || '',
        oper: '=',
        page: '1',
        rp: '50',
        sortname: 'su_oss_chamado.id',
        sortorder: 'desc'
      });

      const response = await this.client.post('/su_oss_chamado', params.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
        }
      });

      if (response.data?.type === 'error') {
        console.error('❌ Erro retornado pelo IXC:', response.data.message);
        return [];
      }

      const registros = response.data?.registros || [];

      // Filtrar apenas status A e EA
      const registrosFiltrados = registros.filter(os => {
        return os.status === 'A' || os.status === 'EA';
      });

      console.log(`✅ ${registrosFiltrados.length}/${registros.length} OSs abertas (técnico: ${filtros.tecnicoId})`);

      return registrosFiltrados;
    } catch (error) {
      console.error('❌ Erro ao buscar OSs do IXC:', error.message);
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

      console.log(`✅ OS ${osId} atualizada`);

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