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
        .whereNot('os.status', 'cancelada')
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
        materiais_utilizados,
        observacoes,
        fotos
      } = req.body;
      const userId = req.user.id;
      const tenantId = req.tenantId;

      console.log(`✅ Finalizando OS ${id}`);

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
          materiais_utilizados,
          observacoes,
          data_atualizacao: db.fn.now()
        });

      // Processar anexos (fotos)
      if (fotos && fotos.length > 0) {
        for (const fotoPath of fotos) {
          await trx('os_anexos').insert({
            ordem_servico_id: id,
            tipo: 'local',
            url_arquivo: fotoPath,
            nome_arquivo: fotoPath.split('/').pop()
          });
        }
        console.log(`📸 ${fotos.length} foto(s) anexada(s)`);
      }

      // Se a OS veio do IXC, tentar sincronizar de volta
      if (os.origem === 'IXC' && os.id_externo) {
        try {
          await this.sincronizarFinalizacaoComIXC(trx, os, {
            observacoes,
            materiais_utilizados,
            userId
          });
        } catch (error) {
          console.error('⚠️ Erro ao sincronizar com IXC:', error.message);
          await trx('ordem_servico')
            .where('id', id)
            .update({
              sincronizado_ixc: false,
              erro_sincronizacao: error.message,
              tentativas_sincronizacao: db.raw('tentativas_sincronizacao + 1')
            });
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
        error: 'Erro ao finalizar OS'
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
      .where('tecnico_seenet_id', dados.userId)
      .where('tenant_id', os.tenant_id)
      .first();

    if (!mapeamento) {
      throw new Error('Técnico não mapeado no IXC');
    }

    // Criar cliente IXC e finalizar
    const ixc = new IXCService(integracao.url_api, integracao.token_api);
    
    await ixc.finalizarOS(parseInt(os.id_externo), {
      observacoes: dados.observacoes,
      materiaisUtilizados: dados.materiais_utilizados,
      tecnicoId: mapeamento.tecnico_ixc_id
    });

    // Marcar como sincronizada
    await trx('ordem_servico')
      .where('id', os.id)
      .update({
        sincronizado_ixc: true,
        erro_sincronizacao: null
      });

    console.log(`✅ OS ${os.numero_os} sincronizada com IXC`);
  }
}

module.exports = new OrdensServicoController();