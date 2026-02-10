// src/controllers/AprController.js
const { Pool } = require('pg');

class AprController {

  // =====================================================
  // GET /api/apr/checklist
  // Retorna todas as categorias + perguntas + opções
  // =====================================================
  static async getChecklist(req, res) {
    const pool = req.app.locals.db;
    const tenantId = req.user?.tenant_id;

    try {
      // Buscar categorias
      const categoriasResult = await pool.query(`
        SELECT id, nome, ordem
        FROM checklist_categorias_apr
        WHERE (tenant_id = $1 OR tenant_id IS NULL)
          AND ativo = true
        ORDER BY ordem ASC
      `, [tenantId]);

      // Buscar perguntas de todas as categorias
      const perguntasResult = await pool.query(`
        SELECT
          p.id,
          p.categoria_id,
          p.pergunta,
          p.tipo_resposta,
          p.obrigatorio,
          p.requer_justificativa_se,
          p.ordem
        FROM checklist_perguntas_apr p
        INNER JOIN checklist_categorias_apr c ON c.id = p.categoria_id
        WHERE (c.tenant_id = $1 OR c.tenant_id IS NULL)
          AND p.ativo = true
        ORDER BY c.ordem ASC, p.ordem ASC
      `, [tenantId]);

      // Buscar opções (EPIs)
      const opcoesResult = await pool.query(`
        SELECT
          o.id,
          o.pergunta_id,
          o.opcao,
          o.ordem
        FROM checklist_opcoes_apr o
        INNER JOIN checklist_perguntas_apr p ON p.id = o.pergunta_id
        INNER JOIN checklist_categorias_apr c ON c.id = p.categoria_id
        WHERE (c.tenant_id = $1 OR c.tenant_id IS NULL)
        ORDER BY o.ordem ASC
      `, [tenantId]);

      // Montar estrutura: categoria > perguntas > opções
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
  // Verifica se APR já foi preenchida para esta OS
  // =====================================================
  static async getRespostas(req, res) {
    const pool = req.app.locals.db;
    const { osId } = req.params;
    const tenantId = req.user?.tenant_id;

    try {
      // Verificar se já existe resposta para esta OS
      const result = await pool.query(`
        SELECT
          r.id,
          r.pergunta_id,
          r.resposta,
          r.justificativa,
          r.data_resposta
        FROM respostas_apr r
        INNER JOIN ordem_servico os ON os.id = r.ordem_servico_id
        WHERE r.ordem_servico_id = $1
          AND os.tenant_id = $2
        ORDER BY r.pergunta_id ASC
      `, [osId, tenantId]);

      // Buscar EPIs selecionados
      const episResult = await pool.query(`
        SELECT re.resposta_apr_id, re.opcao_id
        FROM respostas_apr_epis re
        INNER JOIN respostas_apr r ON r.id = re.resposta_apr_id
        INNER JOIN ordem_servico os ON os.id = r.ordem_servico_id
        WHERE r.ordem_servico_id = $1
          AND os.tenant_id = $2
      `, [osId, tenantId]);

      const preenchido = result.rows.length > 0;

      return res.json({
        success: true,
        data: {
          preenchido,
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
  // Salva respostas do APR
  // Body: { os_id, respostas: [{pergunta_id, resposta, justificativa}], epis_selecionados: [opcao_id], colaboradores: [...] }
  // =====================================================
  static async salvarRespostas(req, res) {
    const pool = req.app.locals.db;
    const tenantId = req.user?.tenant_id;
    const { os_id, respostas, epis_selecionados = [], latitude, longitude } = req.body;

    if (!os_id || !respostas || respostas.length === 0) {
      return res.status(400).json({ success: false, error: 'os_id e respostas são obrigatórios' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Verificar se OS pertence ao tenant
      const osCheck = await client.query(
        'SELECT id FROM ordem_servico WHERE id = $1 AND tenant_id = $2',
        [os_id, tenantId]
      );
      if (osCheck.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ success: false, error: 'OS não encontrada' });
      }

      // Deletar respostas anteriores (permite re-preenchimento)
      const respostasAntigas = await client.query(
        'SELECT id FROM respostas_apr WHERE ordem_servico_id = $1',
        [os_id]
      );
      if (respostasAntigas.rows.length > 0) {
        const idsAntigos = respostasAntigas.rows.map(r => r.id);
        await client.query(
          'DELETE FROM respostas_apr_epis WHERE resposta_apr_id = ANY($1)',
          [idsAntigos]
        );
        await client.query(
          'DELETE FROM respostas_apr WHERE ordem_servico_id = $1',
          [os_id]
        );
      }

      // Inserir novas respostas
      const idsInseridos = {};
      for (const resp of respostas) {
        const insert = await client.query(`
          INSERT INTO respostas_apr
            (ordem_servico_id, pergunta_id, resposta, justificativa, latitude, longitude)
          VALUES ($1, $2, $3, $4, $5, $6)
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
        // Encontrar o id da resposta da pergunta de EPIs
        const perguntaEpisResult = await client.query(`
          SELECT id FROM checklist_perguntas_apr WHERE tipo_resposta = 'multipla_escolha' LIMIT 1
        `);

        if (perguntaEpisResult.rows.length > 0) {
          const perguntaEpisId = perguntaEpisResult.rows[0].id;
          const respostaEpisId = idsInseridos[perguntaEpisId];

          if (respostaEpisId) {
            for (const opcaoId of epis_selecionados) {
              await client.query(
                'INSERT INTO respostas_apr_epis (resposta_apr_id, opcao_id) VALUES ($1, $2)',
                [respostaEpisId, opcaoId]
              );
            }
          }
        }
      }

      await client.query('COMMIT');

      console.log(`✅ APR salvo para OS ${os_id} (${respostas.length} respostas, ${epis_selecionados.length} EPIs)`);

      return res.json({
        success: true,
        message: 'APR salvo com sucesso',
        data: { os_id, total_respostas: respostas.length }
      });

    } catch (error) {
      await client.query('ROLLBACK');
      console.error('❌ Erro ao salvar APR:', error);
      return res.status(500).json({ success: false, error: 'Erro interno ao salvar APR' });
    } finally {
      client.release();
    }
  }

  // =====================================================
  // GET /api/apr/status/:osId
  // Retorna se APR foi preenchido (usado pelo wizard antes de avançar)
  // =====================================================
  static async getStatus(req, res) {
    const pool = req.app.locals.db;
    const { osId } = req.params;
    const tenantId = req.user?.tenant_id;

    try {
      const result = await pool.query(`
        SELECT COUNT(r.id) as total
        FROM respostas_apr r
        INNER JOIN ordem_servico os ON os.id = r.ordem_servico_id
        WHERE r.ordem_servico_id = $1 AND os.tenant_id = $2
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