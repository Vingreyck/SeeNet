const axios = require('axios');

class IXCService {
  constructor(urlApi, tokenApi) {
    this.baseUrl = urlApi;
    this.token = tokenApi;

    // Cliente para requisições de LISTAGEM (POST com header ixcsoft: listar)
    this.clientListar = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Basic ${Buffer.from(this.token).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        'ixcsoft': 'listar'
      },
      timeout: 30000,
    });

    // Cliente para requisições de ALTERAÇÃO (PUT com JSON)
    this.clientAlterar = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Basic ${Buffer.from(this.token).toString('base64')}`,
        'Content-Type': 'application/json'
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

      const response = await this.clientListar.post('/su_oss_chamado', params.toString());

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
   * Buscar detalhes de uma OS específica (para pegar campos obrigatórios)
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

      const response = await this.clientListar.post('/su_oss_chamado', params.toString());

      const os = response.data.registros?.[0] || null;

      if (!os) {
        console.error(`❌ OS ${osId} não encontrada no IXC`);
        return null;
      }

      console.log(`📋 OS ${osId} encontrada - Status: ${os.status}, Filial: ${os.id_filial}, Assunto: ${os.id_assunto}`);

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

      const response = await this.clientListar.post('/cliente', params.toString());

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

      const response = await this.clientListar.post('/colaborador', params.toString());

      console.log(`✅ ${response.data.total || 0} técnicos encontrados`);

      return response.data.registros || [];
    } catch (error) {
      console.error('❌ Erro ao buscar técnicos:', error.message);
      throw error;
    }
  }

/**
 * ✅ Finalizar OS no IXC usando endpoint correto
 * POST /su_oss_chamado_fechar
 */
async finalizarOS(osId, dados) {
  try {
    console.log(`🏁 Finalizando OS ${osId} no IXC...`);

    // Validações
    if (!dados.id_tecnico_ixc) {
      throw new Error('ID do técnico no IXC é obrigatório');
    }

    // Preparar datas
    const agora = new Date();
    const dataInicio = dados.data_inicio
      ? new Date(dados.data_inicio)
      : new Date(agora.getTime() - 60 * 60 * 1000); // 1 hora atrás

    const dataFinal = dados.data_final
      ? new Date(dados.data_final)
      : agora;

    // Montar payload para endpoint /fechar
    const payload = {
      id_chamado: osId.toString(),
      id_tecnico: dados.id_tecnico_ixc.toString(),
      data_inicio: this.formatarDataIXC(dataInicio),
      data_final: this.formatarDataIXC(dataFinal),
      mensagem: dados.mensagem_resposta || 'Finalizado via SeeNet',
      status: 'F',

      // GPS (opcional)
      latitude: dados.latitude || '',
      longitude: dados.longitude || '',
      gps_time: (dados.latitude && dados.longitude)
        ? this.formatarDataIXC(agora)
        : ''
    };

    console.log(`📤 POST /su_oss_chamado_fechar - OS ${osId}`);

    // Fazer POST no endpoint correto
    const response = await this.clientAlterar.post('/su_oss_chamado_fechar', payload);

    // Verificar resposta
    if (response.data?.type === 'error') {
      console.error(`❌ Erro IXC:`, response.data.message);
      throw new Error(response.data.message || 'Erro ao finalizar OS no IXC');
    }

    if (response.data?.type === 'success') {
      console.log(`✅ OS ${osId} finalizada no IXC (status: F)`);
    }

    return response.data;
  } catch (error) {
    console.error(`❌ Erro ao finalizar OS ${osId}:`, error.message);
    throw error;
  }
}
/**
 * ✅ NOVO: Método genérico para atualizar status da OS
 * PUT /su_oss_chamado/:id
 */
async atualizarStatusOS(osId, dados) {
  try {
    console.log(`🔄 Atualizando OS ${osId} para status "${dados.status}"...`);

    // Buscar dados completos da OS primeiro (campos obrigatórios)
    const osDetalhes = await this.buscarDetalhesOS(osId);

    if (!osDetalhes) {
      throw new Error(`OS ${osId} não encontrada no IXC`);
    }

    // Preparar payload com TODOS os campos obrigatórios
    const payload = {
      // Campos obrigatórios da OS (preservar valores)
      tipo: osDetalhes.tipo || 'C',
      id_cliente: osDetalhes.id_cliente || '',
      id_filial: osDetalhes.id_filial || '',
      id_assunto: osDetalhes.id_assunto || '',

      // Status e técnico (o que queremos atualizar)
      status: dados.status,
      id_tecnico: dados.id_tecnico || osDetalhes.id_tecnico || '',

      // Data/hora do evento
      data_hora_execucao: dados.data_hora_execucao || this.formatarDataIXC(new Date()),

      // GPS (se disponível)
      latitude: dados.latitude || '',
      longitude: dados.longitude || '',
      gps_time: (dados.latitude && dados.longitude)
        ? this.formatarDataIXC(new Date())
        : '',

      // Mensagem (opcional)
      mensagem: dados.mensagem || '',

      // id_evento - vamos testar VAZIO primeiro
      id_evento: dados.id_evento || '',

      // Outros campos que podem ser obrigatórios
      prioridade: osDetalhes.prioridade || 'N',
      origem_endereco: osDetalhes.origem_endereco || 'C',
      setor: osDetalhes.setor || osDetalhes.id_setor || ''
    };

    console.log(`📤 PUT /su_oss_chamado/${osId} - Status: ${dados.status}`);

    // Fazer PUT no endpoint correto
    const response = await this.clientAlterar.put(`/su_oss_chamado/${osId}`, payload);

    // Verificar resposta
    if (response.data?.type === 'error') {
      console.error(`❌ Erro IXC:`, response.data.message);
      throw new Error(response.data.message || 'Erro ao atualizar OS no IXC');
    }

    console.log(`✅ OS ${osId} atualizada - Status: ${dados.status}`);
    return response.data;

  } catch (error) {
    console.error(`❌ Erro ao atualizar OS ${osId}:`, error.message);
    throw error;
  }
}
/**
 * Iniciar deslocamento para OS (status DS)
 * PUT /su_oss_chamado/:id
 */
async deslocarParaOS(osId, dados) {
  try {
    console.log(`🚗 Técnico deslocando para OS ${osId}...`);

    return await this.atualizarStatusOS(osId, {
      status: 'DS', // ← Correto: DS (não D)
      id_tecnico: dados.id_tecnico_ixc?.toString() || '',
      mensagem: dados.mensagem || 'Técnico a caminho do local',
      latitude: dados.latitude || '',
      longitude: dados.longitude || '',
      id_evento: dados.id_evento || '' // Vazio por enquanto
    });

  } catch (error) {
    console.error(`❌ Erro ao iniciar deslocamento para OS ${osId}:`, error.message);
    throw error;
  }
}

/**
 * Iniciar execução da OS (status EX - técnico chegou ao local)
 * POST /su_oss_chamado_executar
 */
async executarOS(osId, dados) {
  try {
    console.log(`🔧 Iniciando execução da OS ${osId}...`);

    const dataInicio = dados.data_inicio
      ? new Date(dados.data_inicio)
      : new Date();

    const payload = {
      id_chamado: osId.toString(),
      mensagem: dados.mensagem || 'Iniciando execução do serviço',
      status: 'EX', // Execução
      id_tecnico: dados.id_tecnico_ixc?.toString() || '',
      data_inicio: this.formatarDataIXC(dataInicio),
      latitude: dados.latitude || '',
      longitude: dados.longitude || '',
      gps_time: (dados.latitude && dados.longitude)
        ? this.formatarDataIXC(new Date())
        : '',

      // Campos vazios obrigatórios
      id_tarefa_atual: '',
      eh_tarefa_decisao: '',
      sequencia_atual: '',
      proxima_sequencia_forcada: '',
      finaliza_processo_aux: '',
      gera_comissao_aux: '',
      id_processo: '',
      data_final: '',
      id_resposta: '',
      id_equipe: '',
      gera_comissao: '',
      data: '',
      id_evento: '',
      id_su_diagnostico: '',
      justificativa_sla_atrasado: '',
      id_evento_status: '',
      id_proxima_tarefa: ''
    };

    const response = await this.clientAlterar.post('/su_oss_chamado_executar', payload);

    if (response.data?.type === 'error') {
      throw new Error(response.data.message || 'Erro ao executar OS');
    }

    console.log(`✅ OS ${osId} em execução (status: EX)`);
    return response.data;
  } catch (error) {
    console.error(`❌ Erro ao executar OS ${osId}:`, error.message);
    throw error;
  }
}

/**
 * Upload de foto para a OS
 * POST /su_oss_chamado_arquivos
 */
async uploadFotoOS(osId, clienteId, fotoData) {
  try {
    console.log(`📸 Enviando foto para OS ${osId}...`);

    const payload = {
      descricao: fotoData.descricao || 'Foto do atendimento',
      local_arquivo: fotoData.base64, // Base64 da imagem
      id_cliente: clienteId.toString(),
      id_oss_chamado: osId.toString(),
      classificacao_arquivo: 'P' // P = Privado
    };

    // ✅ ENDPOINT CORRETO
    const response = await this.clientAlterar.post('/su_oss_chamado_arquivos', payload);

    if (response.data?.type === 'error') {
      console.error(`❌ Erro IXC ao enviar foto:`, response.data.message);
      throw new Error(response.data.message || 'Erro ao enviar foto');
    }

    console.log(`✅ Foto enviada para OS ${osId}`);
    return response.data;
  } catch (error) {
    console.error(`❌ Erro ao enviar foto para OS ${osId}:`, error.message);
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

      await this.clientListar.post('/su_oss_chamado', params.toString());

      console.log('✅ Conexão com IXC OK');
      return true;
    } catch (error) {
      console.error('❌ Falha na conexão com IXC:', error.message);
      return false;
    }
  }
}

module.exports = IXCService;