const axios = require('axios');

class IXCService {
  constructor(urlApi, tokenApi) {
    this.baseUrl = urlApi;
    this.token = tokenApi;

    this.client = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Basic ${Buffer.from(this.token).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      timeout: 30000,
    });
  }

  /**
   * Buscar OSs (chamados) do IXC
   */
  async buscarOSs(filtros = {}) {
    try {
      const params = new URLSearchParams({
        qtype: 'id_tecnico',
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

      // Filtrar apenas status A (Aberta) e EA (Em Atendimento)
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
      return null;
    }
  }

  /**
   * Listar técnicos do IXC
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
   * ✅ NOVO: Iniciar OS no IXC (mudar status para EA - Em Atendimento)
   */
  async iniciarOS(osId, dados = {}) {
    try {
      console.log(`▶️ Iniciando OS ${osId} no IXC...`);

      // Formatar data atual no formato do IXC
      const agora = new Date();
      const dataInicio = agora.toISOString().slice(0, 19).replace('T', ' ');

      const payload = new URLSearchParams();
      payload.append('id', osId.toString());
      payload.append('status', 'EA'); // Em Atendimento
      payload.append('data_inicio', dataInicio);

      if (dados.latitude && dados.longitude) {
        payload.append('latitude', dados.latitude.toString());
        payload.append('longitude', dados.longitude.toString());
      }

      const response = await this.client.post('/su_oss_chamado', payload.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'alterar'
        }
      });

      // Verificar se deu erro
      if (response.data?.type === 'error') {
        throw new Error(response.data.message || 'Erro ao iniciar OS no IXC');
      }

      console.log(`✅ OS ${osId} iniciada no IXC (status: EA)`);

      return response.data;
    } catch (error) {
      console.error(`❌ Erro ao iniciar OS ${osId} no IXC:`, error.message);
      throw error;
    }
  }

  /**
   * Finalizar OS no IXC (mudar status para F - Finalizada)
   */
  async finalizarOS(osId, dados) {
    try {
      console.log(`✅ Finalizando OS ${osId} no IXC...`);

      // Formatar data atual no formato do IXC
      const agora = new Date();
      const dataFinal = agora.toISOString().slice(0, 19).replace('T', ' ');

      const payload = new URLSearchParams();
      payload.append('id', osId.toString());
      payload.append('status', 'F'); // Finalizada
      payload.append('data_final', dataFinal);
      payload.append('data_fechamento', dataFinal);

      if (dados.mensagem_resposta) {
        payload.append('mensagem_resposta', dados.mensagem_resposta);
      }

      if (dados.observacoes) {
        payload.append('observacao', dados.observacoes);
      }

      const response = await this.client.post('/su_oss_chamado', payload.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'alterar'
        }
      });

      // Verificar se deu erro
      if (response.data?.type === 'error') {
        throw new Error(response.data.message || 'Erro ao finalizar OS no IXC');
      }

      console.log(`✅ OS ${osId} finalizada no IXC (status: F)`);

      return response.data;
    } catch (error) {
      console.error(`❌ Erro ao finalizar OS ${osId} no IXC:`, error.message);
      throw error;
    }
  }

  /**
   * Testar conexão com IXC
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