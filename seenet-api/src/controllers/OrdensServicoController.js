const { Pool } = require('pg');
const IXCService = require('../services/IXCService');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

class OrdensServicoController {
  /**
   * Buscar OSs do técnico logado
   * GET /api/ordens-servico/minhas
   */
    async buscarMinhasOSs(req, res) {
    try {
        const userId = req.user.id; // ✅ CORRIGIDO
        const tenantId = req.tenantId;

        console.log(`📋 Buscando OSs do técnico ${userId} (tenant: ${tenantId})`);

        const { rows } = await pool.query(`
        SELECT 
            os.*,
            u.nome as tecnico_nome,
            (
            SELECT json_agg(json_build_object(
                'id', a.id,
                'tipo', a.tipo,
                'url_arquivo', a.url_arquivo,
                'created_at', a.created_at
            ))
            FROM os_anexos a
            WHERE a.os_id = os.id
            ) as anexos
        FROM ordem_servico os
        JOIN usuarios u ON u.id = os.tecnico_id
        WHERE os.tecnico_id = $1 
            AND os.tenant_id = $2
            AND os.status != 'cancelada'
        ORDER BY 
            CASE os.prioridade
            WHEN 'urgente' THEN 1
            WHEN 'alta' THEN 2
            WHEN 'media' THEN 3
            WHEN 'baixa' THEN 4
            END,
            os.created_at DESC
        `, [userId, tenantId]); // ✅ CORRIGIDO

        console.log(`✅ ${rows.length} OS(s) encontrada(s)`);

        return res.json(rows);
    } catch (error) {
        console.error('❌ Erro ao buscar OSs:', error);
        return res.status(500).json({
        success: false,
        error: 'Erro ao buscar ordens de serviço'
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
      const { userId, tenantId } = req.user;

      console.log(`🔍 Buscando detalhes da OS ${id}`);

      const { rows } = await pool.query(`
        SELECT 
          os.*,
          u.nome as tecnico_nome,
          u.email as tecnico_email,
          (
            SELECT json_agg(json_build_object(
              'id', a.id,
              'tipo', a.tipo,
              'url_arquivo', a.url_arquivo,
              'nome_arquivo', a.nome_arquivo,
              'created_at', a.created_at
            ))
            FROM os_anexos a
            WHERE a.os_id = os.id
          ) as anexos
        FROM ordem_servico os
        JOIN usuarios u ON u.id = os.tecnico_id
        WHERE os.id = $1 
          AND os.empresa_id = $2
          AND os.tecnico_id = $3
      `, [id, tenantId, userId]);

      if (rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'OS não encontrada ou você não tem permissão para acessá-la'
        });
      }

      console.log(`✅ Detalhes da OS ${id} obtidos`);

      return res.json(rows[0]);
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
    const client = await pool.connect();
    
    try {
      const { id } = req.params;
      const { latitude, longitude } = req.body;
      const { userId, tenantId } = req.user;

      console.log(`▶️ Iniciando OS ${id}`);

      await client.query('BEGIN');

      // Verificar se a OS existe e pertence ao técnico
      const { rows: osRows } = await client.query(`
        SELECT * FROM ordem_servico
        WHERE id = $1 AND empresa_id = $2 AND tecnico_id = $3
      `, [id, tenantId, userId]);

      if (osRows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({
          success: false,
          error: 'OS não encontrada'
        });
      }

      const os = osRows[0];

      if (os.status === 'concluida') {
        await client.query('ROLLBACK');
        return res.status(400).json({
          success: false,
          error: 'OS já está concluída'
        });
      }

      // Atualizar OS para "em_execucao"
      await client.query(`
        UPDATE ordem_servico
        SET 
          status = 'em_execucao',
          data_inicio = NOW(),
          latitude = $1,
          longitude = $2,
          updated_at = NOW()
        WHERE id = $3
      `, [latitude, longitude, id]);

      // Registrar log de auditoria
      await client.query(`
        INSERT INTO logs_auditoria (
          usuario_id, tenant_id, acao, tabela, registro_id, detalhes
        ) VALUES ($1, $2, 'INICIAR_OS', 'ordem_servico', $3, $4)
      `, [
        userId,
        tenantId,
        id,
        JSON.stringify({ latitude, longitude, numero_os: os.numero_os })
      ]);

      await client.query('COMMIT');

      console.log(`✅ OS ${os.numero_os} iniciada com sucesso`);

      return res.json({
        success: true,
        message: 'OS iniciada com sucesso'
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('❌ Erro ao iniciar OS:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao iniciar OS'
      });
    } finally {
      client.release();
    }
  }

  /**
   * Finalizar execução de uma OS
   * POST /api/ordens-servico/:id/finalizar
   */
  async finalizarOS(req, res) {
    const client = await pool.connect();
    
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
      const { userId, tenantId } = req.user;

      console.log(`✅ Finalizando OS ${id}`);

      await client.query('BEGIN');

      // Verificar se a OS existe e pertence ao técnico
      const { rows: osRows } = await client.query(`
        SELECT * FROM ordem_servico
        WHERE id = $1 AND empresa_id = $2 AND tecnico_id = $3
      `, [id, tenantId, userId]);

      if (osRows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({
          success: false,
          error: 'OS não encontrada'
        });
      }

      const os = osRows[0];

      if (os.status === 'concluida') {
        await client.query('ROLLBACK');
        return res.status(400).json({
          success: false,
          error: 'OS já está concluída'
        });
      }

      // Atualizar OS
      await client.query(`
        UPDATE ordem_servico
        SET 
          status = 'concluida',
          data_fim = NOW(),
          latitude = COALESCE($1, latitude),
          longitude = COALESCE($2, longitude),
          onu_modelo = $3,
          onu_serial = $4,
          onu_status = $5,
          onu_sinal_optico = $6,
          materiais_utilizados = $7,
          observacoes = $8,
          updated_at = NOW()
        WHERE id = $9
      `, [
        latitude,
        longitude,
        onu_modelo,
        onu_serial,
        onu_status,
        onu_sinal_optico,
        materiais_utilizados,
        observacoes,
        id
      ]);

      // Processar anexos (fotos) - se houver
      if (fotos && fotos.length > 0) {
        for (const fotoPath of fotos) {
          // Aqui você implementaria o upload real para um serviço de storage
          // Por enquanto, vamos apenas registrar o path
          await client.query(`
            INSERT INTO os_anexos (os_id, tipo, url_arquivo, nome_arquivo)
            VALUES ($1, 'local', $2, $3)
          `, [id, fotoPath, fotoPath.split('/').pop()]);
        }
        console.log(`📸 ${fotos.length} foto(s) anexada(s)`);
      }

      // Se a OS veio do IXC, tentar sincronizar de volta
      if (os.origem === 'IXC' && os.id_externo) {
        try {
          await this.sincronizarFinalizacaoComIXC(client, os, {
            observacoes,
            materiais_utilizados,
            userId
          });
        } catch (error) {
          console.error('⚠️ Erro ao sincronizar com IXC (OS finalizada localmente):', error.message);
          // Marcar para retry depois
          await client.query(`
            UPDATE ordem_servico
            SET 
              sincronizado_ixc = false,
              erro_sincronizacao = $1,
              tentativas_sincronizacao = tentativas_sincronizacao + 1
            WHERE id = $2
          `, [error.message, id]);
        }
      }

      // Registrar log de auditoria
      await client.query(`
        INSERT INTO logs_auditoria (
          usuario_id, tenant_id, acao, tabela, registro_id, detalhes
        ) VALUES ($1, $2, 'FINALIZAR_OS', 'ordem_servico', $3, $4)
      `, [
        userId,
        tenantId,
        id,
        JSON.stringify({ numero_os: os.numero_os, materiais: materiais_utilizados })
      ]);

      await client.query('COMMIT');

      console.log(`✅ OS ${os.numero_os} finalizada com sucesso`);

      return res.json({
        success: true,
        message: 'OS finalizada com sucesso'
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('❌ Erro ao finalizar OS:', error);
      return res.status(500).json({
        success: false,
        error: 'Erro ao finalizar OS'
      });
    } finally {
      client.release();
    }
  }

  /**
   * Sincronizar finalização com IXC
   */
  async sincronizarFinalizacaoComIXC(client, os, dados) {
    console.log(`🔄 Sincronizando finalização da OS ${os.numero_os} com IXC...`);

    // Buscar configuração IXC da empresa
    const { rows: integracoes } = await client.query(`
      SELECT url_api, token_api
      FROM integracao_ixc
      WHERE empresa_id = $1 AND ativo = true
    `, [os.empresa_id]);

    if (integracoes.length === 0) {
      throw new Error('Integração IXC não configurada para esta empresa');
    }

    const integracao = integracoes[0];

    // Buscar ID do técnico no IXC
    const { rows: mapeamentos } = await client.query(`
      SELECT tecnico_ixc_id
      FROM mapeamento_tecnicos_ixc
      WHERE tecnico_seenet_id = $1 AND empresa_id = $2
    `, [dados.userId, os.empresa_id]);

    if (mapeamentos.length === 0) {
      throw new Error('Técnico não mapeado no IXC');
    }

    // Criar cliente IXC e finalizar
    const ixc = new IXCService(integracao.url_api, integracao.token_api);
    
    await ixc.finalizarOS(parseInt(os.id_externo), {
      observacoes: dados.observacoes,
      materiaisUtilizados: dados.materiais_utilizados,
      tecnicoId: mapeamentos[0].tecnico_ixc_id
    });

    // Marcar como sincronizada
    await client.query(`
      UPDATE ordem_servico
      SET sincronizado_ixc = true, erro_sincronizacao = NULL
      WHERE id = $1
    `, [os.id]);

    console.log(`✅ OS ${os.numero_os} sincronizada com IXC`);
  }
}

module.exports = new OrdensServicoController();