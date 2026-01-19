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
   * Formatar data para o padrão IXC (YYYY-MM-DD HH:MM:SS)
   */
  formatarDataIXC(data = new Date()) {
    const ano = data.getFullYear();
    const mes = String(data.getMonth() + 1).padStart(2, '0');
    const dia = String(data.getDate()).padStart(2, '0');
    const hora = String(data.getHours()).padStart(2, '0');
    const minuto = String(data.getMinutes()).padStart(2, '0');
    const segundo = String(data.getSeconds()).padStart(2, '0');
    return `${ano}-${mes}-${dia} ${hora}:${minuto}:${segundo}`;
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

      const os = response.data.registros?.[0] || null;

      if (!os) {
        console.error(`❌ OS ${osId} não encontrada no IXC`);
      }

      return os;
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
   * Iniciar OS no IXC (mudar status para EA - Em Atendimento)
   */
  async iniciarOS(osId, dados = {}) {
    try {
      console.log(`▶️ Iniciando OS ${osId} no IXC...`);

      // 1. Buscar dados atuais da OS para pegar campos obrigatórios
      const osAtual = await this.buscarDetalhesOS(osId);

      if (!osAtual) {
        throw new Error(`OS ${osId} não encontrada no IXC`);
      }

      console.log(`📋 OS ${osId} encontrada - Filial: ${osAtual.id_filial}, Assunto: ${osAtual.id_assunto}, Cliente: ${osAtual.id_cliente}`);

      const dataInicio = this.formatarDataIXC();

      // 2. Montar payload com campos obrigatórios + alterações
      const payload = new URLSearchParams();
      payload.append('id', osId.toString());

      // Campos obrigatórios (pegar da OS atual)
      payload.append('id_filial', osAtual.id_filial || '1');
      payload.append('id_assunto', osAtual.id_assunto || '');
      payload.append('setor', osAtual.setor || '1');
      payload.append('prioridade', osAtual.prioridade || 'N');
      payload.append('origem_endereco', osAtual.origem_endereco || 'C');
      payload.append('id_cliente', osAtual.id_cliente || '');

      // Campos que estamos alterando
      payload.append('status', 'EA'); // Em Atendimento
      payload.append('data_inicio', dataInicio);

      if (dados.latitude && dados.longitude) {
        payload.append('latitude', dados.latitude.toString());
        payload.append('longitude', dados.longitude.toString());
      }

      console.log(`📤 Enviando para IXC: status=EA, data_inicio=${dataInicio}`);

      const response = await this.client.post('/su_oss_chamado', payload.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'alterar'
        }
      });

      // Verificar resposta
      if (response.data?.type === 'error') {
        console.error(`❌ Erro IXC:`, response.data.message);
        throw new Error(response.data.message || 'Erro ao iniciar OS no IXC');
      }

      if (response.data?.type === 'success') {
        console.log(`✅ OS ${osId} iniciada no IXC (status: EA)`);
      } else {
        console.log(`⚠️ Resposta IXC:`, JSON.stringify(response.data).substring(0, 200));
      }

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
      console.log(`🏁 Finalizando OS ${osId} no IXC...`);

      // 1. Buscar dados atuais da OS para pegar campos obrigatórios
      const osAtual = await this.buscarDetalhesOS(osId);

      if (!osAtual) {
        throw new Error(`OS ${osId} não encontrada no IXC`);
      }

      console.log(`📋 OS ${osId} encontrada - Filial: ${osAtual.id_filial}, Assunto: ${osAtual.id_assunto}, Cliente: ${osAtual.id_cliente}`);

      const dataFinal = this.formatarDataIXC();

      // 2. Montar payload com campos obrigatórios + alterações
      const payload = new URLSearchParams();
      payload.append('id', osId.toString());

      // Campos obrigatórios (pegar da OS atual)
      payload.append('id_filial', osAtual.id_filial || '1');
      payload.append('id_assunto', osAtual.id_assunto || '');
      payload.append('setor', osAtual.setor || '1');
      payload.append('prioridade', osAtual.prioridade || 'N');
      payload.append('origem_endereco', osAtual.origem_endereco || 'C');
      payload.append('id_cliente', osAtual.id_cliente || '');

      // Campos que estamos alterando
      payload.append('status', 'F'); // Finalizada
      payload.append('data_final', dataFinal);
      payload.append('data_fechamento', dataFinal);

      // Se não tinha data_inicio, usar a atual
      if (!osAtual.data_inicio || osAtual.data_inicio === '0000-00-00 00:00:00') {
        payload.append('data_inicio', dataFinal);
      }

      if (dados.mensagem_resposta) {
        payload.append('mensagem_resposta', dados.mensagem_resposta);
      }

      if (dados.observacoes) {
        payload.append('observacao', dados.observacoes);
      }

      console.log(`📤 Enviando para IXC: status=F, data_final=${dataFinal}`);

      const response = await this.client.post('/su_oss_chamado', payload.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'alterar'
        }
      });

      // Verificar resposta
      if (response.data?.type === 'error') {
        console.error(`❌ Erro IXC:`, response.data.message);
        throw new Error(response.data.message || 'Erro ao finalizar OS no IXC');
      }

      if (response.data?.type === 'success') {
        console.log(`✅ OS ${osId} finalizada no IXC (status: F)`);
      } else {
        // Pode vir HTML de erro
        const respStr = typeof response.data === 'string' ? response.data : JSON.stringify(response.data);
        if (respStr.includes('erro') || respStr.includes('Preencha')) {
          const msgLimpa = respStr.replace(/<[^>]*>/g, ' ').trim();
          console.error(`❌ Erro HTML:`, msgLimpa.substring(0, 200));
          throw new Error(msgLimpa);
        }
        console.log(`⚠️ Resposta IXC:`, respStr.substring(0, 200));
      }

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