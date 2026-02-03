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
      timeout: 120000,
    });

    // Cliente para requisições de ALTERAÇÃO (PUT com JSON)
    this.clientAlterar = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `Basic ${Buffer.from(this.token).toString('base64')}`,
        'Content-Type': 'application/json'
      },
      timeout: 120000,
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

        // id_evento - testando VAZIO primeiro
        id_evento: dados.id_evento || '',

        // Outros campos que podem ser obrigatórios
        prioridade: osDetalhes.prioridade || 'N',
        origem_endereco: osDetalhes.origem_endereco || 'C',
        setor: osDetalhes.setor || osDetalhes.id_setor || ''
      };

      console.log('📤 PUT /su_oss_chamado/' + osId + ' - Status: ' + dados.status);
      console.log('📦 Payload enviado:', JSON.stringify(payload, null, 2));

      // Fazer PUT no endpoint correto
      const response = await this.clientAlterar.put(`/su_oss_chamado/${osId}`, payload);

      // ✅ LOG DETALHADO DA RESPOSTA
      console.log('📥 Resposta completa do IXC:');
      console.log('   Status HTTP:', response.status);
      console.log('   Headers:', JSON.stringify(response.headers, null, 2));
      console.log('   Body:', JSON.stringify(response.data, null, 2));

      // Verificar resposta
      if (response.data?.type === 'error') {
        console.error(`❌ Erro IXC:`, response.data.message);
        throw new Error(response.data.message || 'Erro ao atualizar OS no IXC');
      }

      // Verificar se tem mensagem de sucesso
      if (response.data?.type === 'success') {
        console.log(`✅ OS ${osId} atualizada com sucesso - Status: ${dados.status}`);
      } else {
        console.log(`⚠️ OS ${osId} - Resposta sem confirmação explícita`);
      }

      return response.data;

    } catch (error) {
      console.error(`❌ Erro ao atualizar OS ${osId}:`, error.message);
      if (error.response) {
        console.error('   Response status:', error.response.status);
        console.error('   Response data:', JSON.stringify(error.response.data, null, 2));
      }
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
 * ✅ Adicionar mensagem/interação em uma OS
 * POST /su_oss_chamado_mensagem
 *
 * IMPORTANTE: Este endpoint NÃO muda o status, apenas adiciona uma mensagem
 * ao histórico da OS. Útil para registrar eventos que a API não suporta.
 */
async adicionarMensagemOS(osId, dados) {
  try {
    console.log(`💬 Adicionando mensagem na OS ${osId}...`);

    const payload = {
      id_chamado: osId.toString(),
      mensagem: dados.mensagem || 'Atualização via API',
      id_tecnico: dados.id_tecnico || '',
      id_evento: dados.id_evento || '2', // 2 = Alteração

      // GPS (opcional)
      latitude: dados.latitude?.toString() || '',
      longitude: dados.longitude?.toString() || '',
      gps_time: (dados.latitude && dados.longitude)
        ? this.formatarDataIXC(new Date())
        : ''
    };

    console.log('📤 POST /su_oss_chamado_mensagem (apenas mensagem)');

    const response = await this.clientAlterar.post('/su_oss_chamado_mensagem', payload);

    if (response.data?.type === 'error') {
      throw new Error(response.data.message || 'Erro ao adicionar mensagem');
    }

    console.log(`✅ Mensagem adicionada na OS ${osId}`);
    return response.data;

  } catch (error) {
    console.error(`❌ Erro ao adicionar mensagem na OS ${osId}:`, error.message);
    throw error;
  }
}

/**
 * ⚠️ DESCONTINUADO: Iniciar deslocamento para OS (status DS)
 *
 * LIMITAÇÃO DA API IXC:
 * O status "DS" (Deslocamento) só pode ser alterado pelo aplicativo "Inmap Service".
 * A API REST pública NÃO tem endpoint para mudar para este status.
 *
 * SOLUÇÃO ADOTADA:
 * Usamos adicionarMensagemOS() para registrar o deslocamento como mensagem/interação.
 * O status continua "Aberta" no IXC, mas fica registrado no histórico.
 */
async deslocarParaOS(osId, dados) {
  try {
    console.log(`🚗 Registrando deslocamento para OS ${osId}...`);

    // ⚠️ Não é possível mudar status para DS via API
    // Registramos como mensagem no histórico
    return await this.adicionarMensagemOS(osId, {
      mensagem: dados.mensagem || 'Técnico a caminho do local',
      id_tecnico: dados.id_tecnico_ixc?.toString() || '',
      latitude: dados.latitude || '',
      longitude: dados.longitude || '',
      id_evento: '2' // Alteração
    });

  } catch (error) {
    console.error(`❌ Erro ao registrar deslocamento para OS ${osId}:`, error.message);
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
   * ✅ Listar arquivos de uma OS
   * GET /su_oss_chamado_arquivos
   */
  async listarArquivosOS(osId) {
    try {
      console.log(`📂 Listando arquivos da OS ${osId}...`);

      const payload = {
        qtype: 'su_oss_chamado_arquivos.id_oss_chamado',
        query: osId.toString(),
        oper: '=',
        page: '1',
        rp: '1000',
        sortname: 'su_oss_chamado_arquivos.id',
        sortorder: 'desc'
      };

      const response = await this.clientListar.post(
        '/su_oss_chamado_arquivos',
        JSON.stringify(payload)
      );

      if (response.data?.type === 'error') {
        throw new Error(response.data.message || 'Erro ao listar arquivos');
      }

      const arquivos = response.data?.registros || [];
      console.log(`✅ ${arquivos.length} arquivo(s) encontrado(s) na OS ${osId}`);

      return arquivos;
    } catch (error) {
      console.error(`❌ Erro ao listar arquivos da OS ${osId}:`, error.message);
      throw error;
    }
  }

  /**
   * ✅ Baixar/Visualizar arquivo específico
   * GET /visualizar_arquivo_os
   *
   * IMPORTANTE: Retorna o arquivo em BINÁRIO (não base64)
   */
  async baixarArquivo(arquivoId) {
    try {
      console.log(`📥 Baixando arquivo ID ${arquivoId}...`);

      const payload = {
        id: arquivoId.toString()
      };

      // IMPORTANTE: responseType 'arraybuffer' para receber binário
      const response = await this.clientListar.post(
        '/visualizar_arquivo_os',
        JSON.stringify(payload),
        {
          responseType: 'arraybuffer'
        }
      );

      console.log(`✅ Arquivo ${arquivoId} baixado (${response.data.byteLength} bytes)`);

      return Buffer.from(response.data);
    } catch (error) {
      console.error(`❌ Erro ao baixar arquivo ${arquivoId}:`, error.message);
      throw error;
    }
  }

  /**
   * ✅ Buscar e baixar relatório de uma OS
   * Combina listarArquivosOS + baixarArquivo
   */
  async buscarRelatorioPDF(osId) {
    try {
      console.log(`📄 Buscando relatório da OS ${osId}...`);

      // 1️⃣ Listar todos arquivos da OS
      const arquivos = await this.listarArquivosOS(osId);

      if (arquivos.length === 0) {
        throw new Error('Nenhum arquivo encontrado para esta OS');
      }

      // 2️⃣ Procurar o relatório
      const relatorio = arquivos.find(arquivo => {
        const desc = (arquivo.descricao || '').toLowerCase();
        const nome = (arquivo.nome_arquivo || '').toLowerCase();

        return desc.includes('relatorio') ||
               desc.includes('relatório') ||
               nome.includes('relatorio') ||
               nome.includes('relatório');
      });

      if (!relatorio) {
        console.log('⚠️ Relatório não encontrado. Arquivos disponíveis:');
        arquivos.forEach(a => console.log(`   - ID: ${a.id}, Desc: ${a.descricao}, Nome: ${a.nome_arquivo}`));
        throw new Error('Relatório não encontrado nos arquivos da OS');
      }

      console.log(`📄 Relatório encontrado: ${relatorio.descricao || relatorio.nome_arquivo} (ID: ${relatorio.id})`);

      // 3️⃣ Baixar o relatório
      const pdfBuffer = await this.baixarArquivo(relatorio.id);

      return {
        buffer: pdfBuffer,
        nome: relatorio.nome_arquivo || `relatorio_os_${osId}.pdf`,
        descricao: relatorio.descricao || 'Relatório de Atendimento'
      };
    } catch (error) {
      console.error(`❌ Erro ao buscar relatório da OS ${osId}:`, error.message);
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