const { db } = require('../config/database'); // ✅ USAR KNEX
const IXCService = require('../services/IXCService');

class OrdensServicoController {
  /**
   * Buscar OSs do técnico logado
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
   * Iniciar execução de uma OS
   * POST /api/ordens-servico/:id/iniciar
   */
  async iniciarOS(req, res) {
    const trx = await db.transaction();
    
    try {
      const { id } = req.params;
      const { latitude, longitude } = req.body;
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`▶️ Iniciando OS ${id}`);

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

      if (os.status === 'concluida') {
        await trx.rollback();
        return res.status(400).json({
          success: false,
          error: 'OS já está concluída'
        });
      }

      // Atualizar OS para "em_execucao"
      await trx('ordem_servico')
        .where('id', id)
        .update({
          status: 'em_execucao',
          data_inicio: db.fn.now(),
          latitude: latitude,
          longitude: longitude,
          data_atualizacao: db.fn.now()
        });

      await trx.commit();

      console.log(`✅ OS ${os.numero_os} iniciada com sucesso`);

      return res.json({
        success: true,
        message: 'OS iniciada com sucesso'
      });
    } catch (error) {
      await trx.rollback();
      console.error('❌ Erro ao iniciar OS:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao iniciar OS'
      });
    }
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

    console.log(`✅ Finalizando OS ${id}`);

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

    if (os.status === 'concluida') {
      await trx.rollback();
      return res.status(400).json({
        success: false,
        error: 'OS já está concluída'
      });
    }

    // Atualizar OS
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
      for (const fotoPath of fotos) {
        await trx('os_anexos').insert({
          ordem_servico_id: id,
          tipo: 'local',
          url_arquivo: fotoPath,
          nome_arquivo: fotoPath.split('/').pop(),
          data_upload: db.fn.now()
        });
      }
      console.log(`📸 ${fotos.length} foto(s) anexada(s)`);
    }

    // Se a OS veio do IXC, sincronizar de volta
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
          userId
        });
      } catch (error) {
        console.error('⚠️ Erro ao sincronizar com IXC:', error.message);
        // Não bloqueia a finalização se IXC falhar
      }
    }

    await trx.commit();

    console.log(`✅ OS ${os.numero_os} finalizada com sucesso`);

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

  // Criar cliente IXC e finalizar
  const IXCService = require('../services/IXCService');
  const ixc = new IXCService(integracao.url_api, integracao.token_api);

  await ixc.finalizarOS(parseInt(os.id_externo), {
    mensagem_resposta: mensagemResposta,
    observacoes: dados.observacoes,
    tecnicoId: mapeamento.tecnico_ixc_id
  });

  console.log(`✅ OS ${os.numero_os} sincronizada com IXC`);
}
}

module.exports = new OrdensServicoController();