// src/controllers/AprController.js
const { db } = require('../config/database');

class AprController {

  // =====================================================
  // GET /api/apr/checklist
  // =====================================================
  static async getChecklist(req, res) {
    const tenantId = req.user?.tenant_id;

    try {
      const categoriasResult = await db.raw(`
        SELECT id, nome, ordem
        FROM checklist_categorias_apr
        WHERE (tenant_id = ? OR tenant_id IS NULL)
          AND ativo = true
        ORDER BY ordem ASC
      `, [tenantId]);

      const perguntasResult = await db.raw(`
        SELECT
          p.id, p.categoria_id, p.pergunta,
          p.tipo_resposta, p.obrigatorio,
          p.requer_justificativa_se, p.ordem
        FROM checklist_perguntas_apr p
        INNER JOIN checklist_categorias_apr c ON c.id = p.categoria_id
        WHERE (c.tenant_id = ? OR c.tenant_id IS NULL)
          AND p.ativo = true
        ORDER BY c.ordem ASC, p.ordem ASC
      `, [tenantId]);

      const opcoesResult = await db.raw(`
        SELECT o.id, o.pergunta_id, o.opcao, o.ordem
        FROM checklist_opcoes_apr o
        INNER JOIN checklist_perguntas_apr p ON p.id = o.pergunta_id
        INNER JOIN checklist_categorias_apr c ON c.id = p.categoria_id
        WHERE (c.tenant_id = ? OR c.tenant_id IS NULL)
        ORDER BY o.ordem ASC
      `, [tenantId]);

      const categorias = categoriasResult.rows.map(cat => ({
        ...cat,
        perguntas: perguntasResult.rows
          .filter(p => p.categoria_id === cat.id)
          .map(p => ({
            ...p,
            opcoes: opcoesResult.rows.filter(o => o.pergunta_id === p.id)
          }))
      }));

      return res.json({ success: true, data: categorias });

    } catch (error) {
      console.error('❌ Erro ao buscar checklist APR:', error);
      return res.status(500).json({ success: false, error: 'Erro interno ao buscar checklist' });
    }
  }

  // =====================================================
  // GET /api/apr/respostas/:osId
  // =====================================================
  static async getRespostas(req, res) {
    const { osId } = req.params;
    const tenantId = req.user?.tenant_id;

    try {
      const result = await db.raw(`
        SELECT r.id, r.pergunta_id, r.resposta, r.justificativa, r.data_resposta
        FROM respostas_apr r
        INNER JOIN ordem_servico os ON os.id = r.ordem_servico_id
        WHERE r.ordem_servico_id = ? AND os.tenant_id = ?
        ORDER BY r.pergunta_id ASC
      `, [osId, tenantId]);

      const episResult = await db.raw(`
        SELECT re.resposta_apr_id, re.opcao_id
        FROM respostas_apr_epis re
        INNER JOIN respostas_apr r ON r.id = re.resposta_apr_id
        INNER JOIN ordem_servico os ON os.id = r.ordem_servico_id
        WHERE r.ordem_servico_id = ? AND os.tenant_id = ?
      `, [osId, tenantId]);

      return res.json({
        success: true,
        data: {
          preenchido: result.rows.length > 0,
          respostas: result.rows,
          epis: episResult.rows
        }
      });

    } catch (error) {
      console.error('❌ Erro ao buscar respostas APR:', error);
      return res.status(500).json({ success: false, error: 'Erro interno' });
    }
  }

  // =====================================================
  // POST /api/apr/respostas
  // =====================================================
  static async salvarRespostas(req, res) {
    const tenantId = req.user?.tenant_id;
    const { os_id, respostas, epis_selecionados = [], latitude, longitude } = req.body;

    if (!os_id || !respostas || respostas.length === 0) {
      return res.status(400).json({ success: false, error: 'os_id e respostas são obrigatórios' });
    }

    try {
      await db.transaction(async (trx) => {

        // Verificar se OS pertence ao tenant
        const osCheck = await trx.raw(
          'SELECT id FROM ordem_servico WHERE id = ? AND tenant_id = ?',
          [os_id, tenantId]
        );
        if (osCheck.rows.length === 0) {
          throw new Error('OS_NOT_FOUND');
        }

        // Deletar respostas anteriores (permite re-preenchimento)
        const respostasAntigas = await trx.raw(
          'SELECT id FROM respostas_apr WHERE ordem_servico_id = ?',
          [os_id]
        );
        if (respostasAntigas.rows.length > 0) {
          const idsAntigos = respostasAntigas.rows.map(r => r.id);
          await trx.raw(
            `DELETE FROM respostas_apr_epis WHERE resposta_apr_id = ANY(?)`,
            [idsAntigos]
          );
          await trx.raw(
            'DELETE FROM respostas_apr WHERE ordem_servico_id = ?',
            [os_id]
          );
        }

        // Inserir novas respostas
        const idsInseridos = {};
        for (const resp of respostas) {
          const insert = await trx.raw(`
            INSERT INTO respostas_apr
              (ordem_servico_id, pergunta_id, resposta, justificativa, latitude, longitude)
            VALUES (?, ?, ?, ?, ?, ?)
            RETURNING id
          `, [
            os_id,
            resp.pergunta_id,
            resp.resposta,
            resp.justificativa || null,
            latitude || null,
            longitude || null
          ]);
          idsInseridos[resp.pergunta_id] = insert.rows[0].id;
        }

        // Inserir EPIs selecionados
        if (epis_selecionados.length > 0) {
          const perguntaEpisResult = await trx.raw(
            `SELECT id FROM checklist_perguntas_apr WHERE tipo_resposta = 'multipla_escolha' LIMIT 1`
          );

          if (perguntaEpisResult.rows.length > 0) {
            const perguntaEpisId = perguntaEpisResult.rows[0].id;
            const respostaEpisId = idsInseridos[perguntaEpisId];

            if (respostaEpisId) {
              for (const opcaoId of epis_selecionados) {
                await trx.raw(
                  'INSERT INTO respostas_apr_epis (resposta_apr_id, opcao_id) VALUES (?, ?)',
                  [respostaEpisId, opcaoId]
                );
              }
            }
          }
        }
      });

      console.log(`✅ APR salvo para OS ${os_id} (${respostas.length} respostas, ${epis_selecionados.length} EPIs)`);

      return res.json({
        success: true,
        message: 'APR salvo com sucesso',
        data: { os_id, total_respostas: respostas.length }
      });

    } catch (error) {
      if (error.message === 'OS_NOT_FOUND') {
        return res.status(404).json({ success: false, error: 'OS não encontrada' });
      }
      console.error('❌ Erro ao salvar APR:', error);
      return res.status(500).json({ success: false, error: 'Erro interno ao salvar APR' });
    }
  }

  // =====================================================
  // GET /api/apr/status/:osId
  // =====================================================
  static async getStatus(req, res) {
    const { osId } = req.params;
    const tenantId = req.user?.tenant_id;

    try {
      const result = await db.raw(`
        SELECT COUNT(r.id) as total
        FROM respostas_apr r
        INNER JOIN ordem_servico os ON os.id = r.ordem_servico_id
        WHERE r.ordem_servico_id = ? AND os.tenant_id = ?
      `, [osId, tenantId]);

      const preenchido = parseInt(result.rows[0].total) > 0;

      return res.json({ success: true, data: { preenchido } });

    } catch (error) {
      console.error('❌ Erro ao verificar status APR:', error);
      return res.status(500).json({ success: false, error: 'Erro interno' });
    }
  }
}

module.exports = AprController;