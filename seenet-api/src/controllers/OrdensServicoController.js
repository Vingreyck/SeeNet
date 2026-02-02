const { db } = require('../config/database');
const IXCService = require('../services/IXCService');

class OrdensServicoController {
  /**
   * Buscar OSs do técnico logado (pendentes e em execução)
   * GET /api/ordens-servico/minhas
   */
  async buscarMinhasOSs(req, res) {
    try {
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`📋 Buscando OSs do técnico ${userId} (tenant: ${tenantId})`);

      const rows = await db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.tecnico_id', userId)
        .where('os.tenant_id', tenantId)
        .whereIn('os.status', ['pendente', 'em_execucao'])
        .select(
          'os.*',
          'u.nome as tecnico_nome'
        )
        .orderByRaw(`
          CASE os.prioridade
            WHEN 'urgente' THEN 1
            WHEN 'alta' THEN 2
            WHEN 'media' THEN 3
            WHEN 'baixa' THEN 4
          END
        `)
        .orderBy('os.data_criacao', 'desc');

      console.log(`✅ ${rows.length} OS(s) encontrada(s)`);

      return res.json(rows);
    } catch (error) {
      console.error('❌ Erro ao buscar OSs:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar ordens de serviço',
        details: error.message
      });
    }
  }

  /**
   * ✅ NOVO: Buscar OSs concluídas do técnico
   * GET /api/ordens-servico/concluidas
   */
  async buscarOSsConcluidas(req, res) {
    try {
      const userId = req.user.id;
      const tenantId = req.tenantId;
      const { limite = 50, pagina = 1, busca = '' } = req.query;

      console.log(`📋 Buscando OSs concluídas do técnico ${userId}`);

      let query = db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.tecnico_id', userId)
        .where('os.tenant_id', tenantId)
        .where('os.status', 'concluida')
        .select(
          'os.*',
          'u.nome as tecnico_nome'
        );

      // Filtro de busca por nome do cliente
      if (busca && busca.trim() !== '') {
        query = query.whereRaw('LOWER(os.cliente_nome) LIKE ?', [`%${busca.toLowerCase()}%`]);
      }

      // Ordenar por data de conclusão (mais recentes primeiro)
      query = query.orderBy('os.data_conclusao', 'desc');

      // Paginação
      const offset = (parseInt(pagina) - 1) * parseInt(limite);
      query = query.limit(parseInt(limite)).offset(offset);

      const rows = await query;

      console.log(`✅ ${rows.length} OS(s) concluída(s) encontrada(s)`);

      return res.json(rows);
    } catch (error) {
      console.error('❌ Erro ao buscar OSs concluídas:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar ordens de serviço concluídas',
        details: error.message
      });
    }
  }

  /**
   * Buscar detalhes de uma OS específica
   * GET /api/ordens-servico/:id/detalhes
   */
  async buscarDetalhesOS(req, res) {
    try {
      const { id } = req.params;
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`🔍 Buscando detalhes da OS ${id}`);

      const os = await db('ordem_servico as os')
        .join('usuarios as u', 'u.id', 'os.tecnico_id')
        .where('os.id', id)
        .where('os.tenant_id', tenantId)
        .where('os.tecnico_id', userId)
        .select(
          'os.*',
          'u.nome as tecnico_nome',
          'u.email as tecnico_email'
        )
        .first();

      if (!os) {
        return res.status(404).json({
          success: false,
          error: 'OS não encontrada ou você não tem permissão para acessá-la'
        });
      }

      // Buscar anexos
      const anexos = await db('os_anexos')
        .where('ordem_servico_id', id)
        .select('id', 'tipo', 'url_arquivo', 'nome_arquivo', 'data_upload');

      os.anexos = anexos;

      console.log(`✅ Detalhes da OS ${id} obtidos`);

      return res.json(os);
    } catch (error) {
      console.error('❌ Erro ao buscar detalhes da OS:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao buscar detalhes da OS'
      });
    }
  }

/**
 * Técnico iniciou deslocamento para a OS
 * POST /api/ordens-servico/:id/deslocar
 */
async deslocarParaOS(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const userId = req.user.id;
    const tenantId = req.tenantId;

    console.log(`🚗 Técnico deslocando para OS ${id}`);

    // Buscar OS
    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    if (os.status !== 'pendente') {
      await trx.rollback();
      return res.status(400).json({ success: false, error: 'OS já foi iniciada' });
    }

    // Atualizar status para "em_deslocamento"
    await trx('ordem_servico')
      .where('id', id)
      .update({
        status: 'em_deslocamento',
        latitude_inicio: latitude,
        longitude_inicio: longitude,
        data_inicio_deslocamento: db.fn.now(),
        data_atualizacao: db.fn.now()
      });

    // ✅ Sincronizar deslocamento com IXC (apenas como mensagem)
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarDeslocamentoComIXC(trx, os, { latitude, longitude });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar com IXC:', error.message);
        // Não bloqueia o deslocamento local se IXC falhar
      }
    }

    await trx.commit();

    console.log(`✅ OS ${os.numero_os} - Técnico em deslocamento`);

    return res.json({
      success: true,
      message: 'Deslocamento iniciado com sucesso'
    });
  } catch (error) {
    await trx.rollback();
    console.error('❌ Erro ao iniciar deslocamento:', error);
    return res.status(500).json({ success: false, error: 'Erro ao iniciar deslocamento' });
  }
}


/**
 * Sincronizar deslocamento com IXC (apenas como mensagem)
 *
 * LIMITAÇÃO DA API IXC:
 * O status "DS" (Deslocamento) só pode ser alterado pelo app "Inmap Service".
 * Não há endpoint público da API REST para mudar para este status.
 *
 * SOLUÇÃO:
 * Registramos o deslocamento como mensagem/interação no histórico da OS.
 */
async sincronizarDeslocamentoComIXC(trx, os, dados) {
  console.log(`🔄 Registrando deslocamento da OS ${os.numero_os} no IXC (como mensagem)...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', os.tecnico_id)
    .where('tenant_id', os.tenant_id)
    .first();

  const tecnico = await trx('usuarios')
    .where('id', os.tecnico_id)
    .first();

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  // Formatar data/hora
  const agora = new Date();
  const dataHora = agora.toLocaleString('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short'
  });

  // Montar mensagem completa
  const mensagem = `🚗 DESLOCAMENTO INICIADO

Técnico: ${tecnico.nome}
Data/Hora: ${dataHora}
${dados.latitude && dados.longitude ? `Coordenadas: ${dados.latitude}, ${dados.longitude}` : ''}

Status: Técnico a caminho do local de atendimento.

📱 Registrado via SeeNet`;

  // ⚠️ Não mudamos o status (IXC não permite via API)
  // Apenas registramos como mensagem no histórico
  await ixc.adicionarMensagemOS(parseInt(os.id_externo), {
    mensagem: mensagem,
    id_tecnico: mapeamento?.tecnico_ixc_id || '',
    latitude: dados.latitude || '',
    longitude: dados.longitude || ''
  });

  console.log(`✅ OS ${os.numero_os} - Deslocamento registrado como mensagem no IXC`);
}

/**
 * Técnico chegou ao local
 * POST /api/ordens-servico/:id/chegar-local
 */
async chegarAoLocal(req, res) {
  const trx = await db.transaction();

  try {
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const userId = req.user.id;
    const tenantId = req.tenantId;

    console.log(`📍 Técnico chegou ao local da OS ${id}`);

    const os = await trx('ordem_servico')
      .where('id', id)
      .where('tenant_id', tenantId)
      .where('tecnico_id', userId)
      .first();

    if (!os) {
      await trx.rollback();
      return res.status(404).json({ success: false, error: 'OS não encontrada' });
    }

    if (os.status !== 'em_deslocamento') {
      await trx.rollback();
      return res.status(400).json({ success: false, error: 'OS não está em deslocamento' });
    }

    // Atualizar para "em_execucao"
    await trx('ordem_servico')
      .where('id', id)
      .update({
        status: 'em_execucao',
        latitude_execucao: latitude,
        longitude_execucao: longitude,
        data_inicio: db.fn.now(),
        data_atualizacao: db.fn.now()
      });

    // Sincronizar com IXC
    if (os.origem === 'IXC' && os.id_externo) {
      try {
        await this.sincronizarExecucaoComIXC(trx, os, { latitude, longitude });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar execução com IXC:', error.message);
      }
    }

    await trx.commit();

    console.log(`✅ OS ${os.numero_os} em execução`);

    return res.json({
      success: true,
      message: 'Execução iniciada com sucesso'
    });
  } catch (error) {
    await trx.rollback();
    console.error('❌ Erro ao iniciar execução:', error);
    return res.status(500).json({ success: false, error: 'Erro ao iniciar execução' });
  }
}

/**
 * Sincronizar execução com IXC
 */
async sincronizarExecucaoComIXC(trx, os, dados) {
  console.log(`🔄 Sincronizando execução da OS ${os.numero_os} com IXC...`);

  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', os.tecnico_id)
    .where('tenant_id', os.tenant_id)
    .first();

  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  await ixc.executarOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamento?.tecnico_ixc_id,
    mensagem: 'Iniciando execução do serviço',
    data_inicio: os.data_inicio_deslocamento || new Date().toISOString(),
    latitude: dados.latitude,
    longitude: dados.longitude
  });

  console.log(`✅ OS ${os.numero_os} - Status "EX" (Execução) no IXC`);
}

  /**
   * Finalizar execução de uma OS
   * POST /api/ordens-servico/:id/finalizar
   */
  async finalizarOS(req, res) {
    const trx = await db.transaction();

    try {
      const { id } = req.params;
      const {
        latitude,
        longitude,
        onu_modelo,
        onu_serial,
        onu_status,
        onu_sinal_optico,
        relato_problema,
        relato_solucao,
        materiais_utilizados,
        observacoes,
        fotos,
        assinatura
      } = req.body;
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`🏁 Finalizando OS ${id}`);

      // Validações obrigatórias
      if (!relato_problema || !relato_solucao) {
        await trx.rollback();
        return res.status(400).json({
          success: false,
          error: 'Relato do problema e solução são obrigatórios'
        });
      }

      if (!assinatura) {
        await trx.rollback();
        return res.status(400).json({
          success: false,
          error: 'Assinatura do cliente é obrigatória'
        });
      }

      // Verificar se a OS existe e pertence ao técnico
      const os = await trx('ordem_servico')
        .where('id', id)
        .where('tenant_id', tenantId)
        .where('tecnico_id', userId)
        .first();

      if (!os) {
        await trx.rollback();
        return res.status(404).json({
          success: false,
          error: 'OS não encontrada'
        });
      }

      if (os.status !== 'em_execucao') {
            await trx.rollback();
            return res.status(400).json({
              success: false,
              error: `OS não pode ser finalizada no status "${os.status}". Primeiro inicie a execução.`
            });
          }

      if (os.status === 'concluida') {
        await trx.rollback();
        return res.status(400).json({
          success: false,
          error: 'OS já está concluída'
        });
      }

      // Atualizar OS no banco local
      await trx('ordem_servico')
        .where('id', id)
        .update({
          status: 'concluida',
          data_conclusao: db.fn.now(),
          latitude: latitude || os.latitude,
          longitude: longitude || os.longitude,
          onu_modelo,
          onu_serial,
          onu_status,
          onu_sinal_optico,
          relato_problema,
          relato_solucao,
          materiais_utilizados,
          observacoes,
          assinatura_cliente: assinatura,
          data_atualizacao: db.fn.now()
        });

      // Processar anexos (fotos)
    if (fotos && fotos.length > 0) {
      console.log(`📸 Processando ${fotos.length} foto(s)...`);

      for (const fotoData of fotos) {
        // Fotos agora vêm como objetos: { base64, tipo, descricao }
        await trx('os_anexos').insert({
          ordem_servico_id: id,
          tipo: fotoData.tipo || 'outro',
          descricao: fotoData.descricao || '',
          url_arquivo: '', // Base64 não é salvo no banco local
          nome_arquivo: `foto_${fotoData.tipo}_${Date.now()}.jpg`,
          data_upload: db.fn.now()
        });
      }

      console.log(`📸 ${fotos.length} foto(s) anexada(s)`);
    }

      // ✅ Sincronizar finalização com IXC
      if (os.origem === 'IXC' && os.id_externo) {
        try {
          await this.sincronizarFinalizacaoComIXC(trx, os, {
            onu_modelo,
            onu_serial,
            onu_status,
            onu_sinal_optico,
            relato_problema,
            relato_solucao,
            materiais_utilizados,
            observacoes,
            userId,
            fotos
          });
        } catch (error) {
          console.error('⚠️ Erro ao sincronizar finalização com IXC:', error.message);
          // Não bloqueia a finalização se IXC falhar
        }
      }

      await trx.commit();

      console.log(`✅ OS ${os.numero_os} finalizada com sucesso`);

      // ✅ Baixar relatório PDF do IXC (após commit)
      if (os.origem === 'IXC' && os.id_externo) {
        // Executar em background (não bloqueia resposta)
        this.baixarRelatorioPDFBackground(id, os.id_externo, tenantId).catch(error => {
          console.error('⚠️ Erro ao baixar relatório em background:', error.message);
        });
      }

      return res.json({
        success: true,
        message: 'OS finalizada com sucesso'
      });
    } catch (error) {
      await trx.rollback();
      console.error('❌ Erro ao finalizar OS:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao finalizar OS',
        details: error.message
      });
    }
  }

  /**
   * Sincronizar finalização com IXC
   */
async sincronizarFinalizacaoComIXC(trx, os, dados) {
  console.log(`🔄 Sincronizando finalização da OS ${os.numero_os} com IXC...`);

  // Buscar configuração IXC
  const integracao = await trx('integracao_ixc')
    .where('tenant_id', os.tenant_id)
    .where('ativo', true)
    .first();

  if (!integracao) {
    throw new Error('Integração IXC não configurada');
  }

  // Buscar mapeamento do técnico
  const mapeamento = await trx('mapeamento_tecnicos_ixc')
    .where('usuario_id', dados.userId)
    .where('tenant_id', os.tenant_id)
    .first();

  if (!mapeamento) {
    throw new Error('Técnico não mapeado no IXC');
  }

  // Montar mensagem completa
  let mensagemResposta = '';

  mensagemResposta += '═══════════════════════════════════\n';
  mensagemResposta += '  RELATÓRIO DE ATENDIMENTO TÉCNICO\n';
  mensagemResposta += '═══════════════════════════════════\n\n';

  if (dados.relato_problema) {
    mensagemResposta += '📋 PROBLEMA IDENTIFICADO:\n';
    mensagemResposta += `${dados.relato_problema}\n\n`;
  }

  if (dados.relato_solucao) {
    mensagemResposta += '✅ SOLUÇÃO APLICADA:\n';
    mensagemResposta += `${dados.relato_solucao}\n\n`;
  }

  if (dados.onu_modelo || dados.onu_serial || dados.onu_status) {
    mensagemResposta += '🔧 DADOS TÉCNICOS DA ONU:\n';
    if (dados.onu_modelo) mensagemResposta += `• Modelo: ${dados.onu_modelo}\n`;
    if (dados.onu_serial) mensagemResposta += `• Serial: ${dados.onu_serial}\n`;
    if (dados.onu_status) mensagemResposta += `• Status: ${dados.onu_status}\n`;
    if (dados.onu_sinal_optico) mensagemResposta += `• Sinal Óptico: ${dados.onu_sinal_optico} dBm\n`;
    mensagemResposta += '\n';
  }

  if (dados.materiais_utilizados) {
    mensagemResposta += '🛠️ MATERIAIS UTILIZADOS:\n';
    mensagemResposta += `${dados.materiais_utilizados}\n\n`;
  }

  if (dados.observacoes) {
    mensagemResposta += '💬 OBSERVAÇÕES ADICIONAIS:\n';
    mensagemResposta += `${dados.observacoes}\n\n`;
  }

  mensagemResposta += '═══════════════════════════════════\n';
  mensagemResposta += `📱 Atendimento via SeeNet\n`;
  mensagemResposta += '═══════════════════════════════════';

  // Criar cliente IXC
  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  // 1️⃣ Finalizar OS no IXC
  await ixc.finalizarOS(parseInt(os.id_externo), {
    id_tecnico_ixc: mapeamento.tecnico_ixc_id,
    mensagem_resposta: mensagemResposta,
    latitude: os.latitude || '',
    longitude: os.longitude || '',
    data_inicio: os.data_inicio,
    data_final: new Date().toISOString()
  });

  console.log(`✅ OS ${os.numero_os} sincronizada com IXC (Finalizada)`);

// 2️⃣ Enviar fotos para IXC (se houver)
if (dados.fotos && dados.fotos.length > 0) {
  console.log(`📸 Enviando ${dados.fotos.length} foto(s) para IXC...`);

  for (let i = 0; i < dados.fotos.length; i++) {
    const fotoData = dados.fotos[i];

    try {
      // Montar descrição completa
      const labelTipo = {
        'roteador': '📡 Roteador',
        'onu': '📦 ONU',
        'local': '🏠 Local',
        'antes': '📷 Antes',
        'depois': '✅ Depois',
        'problema': '⚠️ Problema',
        'outro': '📎 Outro'
      };

      const descricaoCompleta = fotoData.descricao
        ? `Foto ${i + 1} - ${labelTipo[fotoData.tipo] || fotoData.tipo}: ${fotoData.descricao}`
        : `Foto ${i + 1} - ${labelTipo[fotoData.tipo] || fotoData.tipo}`;

      await ixc.uploadFotoOS(
        parseInt(os.id_externo),
        parseInt(os.cliente_id),
        {
          descricao: descricaoCompleta,
          base64: fotoData.base64
        }
      );

      console.log(`✅ Foto ${i + 1}/${dados.fotos.length} enviada: ${descricaoCompleta}`);
    } catch (fotoError) {
      console.error(`❌ Erro ao enviar foto ${i + 1}:`, fotoError.message);
    }
  }
}
}
}

  /**
   * ✅ Baixar relatório PDF do IXC em background
   * Executa após finalizar a OS sem bloquear a resposta
   */
  async baixarRelatorioPDFBackground(osId, osIdExterno, tenantId) {
    try {
      console.log(`📄 Iniciando download do relatório da OS ${osIdExterno} em background...`);

      // Aguardar 5 segundos para IXC processar/gerar o relatório
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Buscar integração IXC
      const integracao = await db('integracao_ixc')
        .where('tenant_id', tenantId)
        .where('ativo', true)
        .first();

      if (!integracao) {
        throw new Error('Integração IXC não configurada');
      }

      const ixc = new IXCService(integracao.url_api, integracao.token_api);

      // Buscar e baixar relatório
      const relatorio = await ixc.buscarRelatorioPDF(osIdExterno);

      // Salvar no banco
      await db('os_anexos').insert({
        ordem_servico_id: osId,
        tipo: 'relatorio',
        descricao: relatorio.descricao,
        url_arquivo: relatorio.buffer.toString('base64'),
        nome_arquivo: relatorio.nome,
        data_upload: db.fn.now()
      });

      console.log(`✅ Relatório PDF baixado e salvo: ${relatorio.nome}`);
    } catch (error) {
      console.error(`❌ Erro ao baixar relatório da OS ${osIdExterno}:`, error.message);
      // Não propaga erro - execução em background
    }
  }
}

module.exports = new OrdensServicoController();