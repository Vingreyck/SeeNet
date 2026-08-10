// src/controllers/AprController.js
const { db } = require('../config/database');

/**
 * A coluna `respostas_apr.usuario_id` (quem respondeu a APR) existe?
 *
 * ⚠️ As migrations NÃO rodam sozinhas no deploy do Railway. Se este código
 * subir antes de `npm run migrate:prod`, usar a coluna direto quebraria o
 * INSERT — e o técnico ficaria SEM CONSEGUIR SALVAR A APR em campo. Com a
 * guarda, o app segue funcionando no comportamento antigo (APR por OS) até a
 * migration rodar, e só então passa a ser por técnico. Resultado cacheado:
 * é uma consulta de schema, não precisa repetir a cada requisição.
 */
let _temColunaUsuario = null;
async function temColunaUsuario() {
  if (_temColunaUsuario === null) {
    try {
      _temColunaUsuario = await db.schema.hasColumn('respostas_apr', 'usuario_id');
      if (!_temColunaUsuario) {
        console.warn('⚠️ respostas_apr.usuario_id não existe — APR segue por OS ' +
          '(rode a migration pra APR passar a ser por técnico)');
      }
    } catch (e) {
      console.warn('⚠️ Não consegui checar respostas_apr.usuario_id:', e.message);
      _temColunaUsuario = false;
    }
  }
  return _temColunaUsuario;
}

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
    const usuarioId = req.user?.id;
    const comUsuario = await temColunaUsuario();
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
          // `usuario_id` só entra se a coluna já existir (ver temColunaUsuario).
          const insert = comUsuario
            ? await trx.raw(`
                INSERT INTO respostas_apr
                  (ordem_servico_id, pergunta_id, resposta, justificativa, latitude, longitude, usuario_id)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                RETURNING id
              `, [
                os_id, resp.pergunta_id, resp.resposta,
                resp.justificativa || null, latitude || null, longitude || null,
                usuarioId || null
              ])
            : await trx.raw(`
                INSERT INTO respostas_apr
                  (ordem_servico_id, pergunta_id, resposta, justificativa, latitude, longitude)
                VALUES (?, ?, ?, ?, ?, ?)
                RETURNING id
              `, [
                os_id, resp.pergunta_id, resp.resposta,
                resp.justificativa || null, latitude || null, longitude || null
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
    const usuarioId = req.user?.id;

    try {
      // "Preenchido" é POR TÉCNICO, não por OS: numa OS ENCAMINHADA, o técnico
      // que recebeu precisa fazer a APR DELE — quem assina tem que ser quem
      // avaliou o risco no local. (Reabertura pelo MESMO técnico continua
      // pulando: as respostas dele seguem lá.)
      // `usuario_id IS NULL` conta como do próprio: são respostas anteriores à
      // migration; sem isso, um deploy sem a migration rodada obrigaria todo
      // mundo a refazer APR já feita.
      const comUsuario = await temColunaUsuario();
      const filtroUsuario = comUsuario
        ? 'AND (r.usuario_id = ? OR r.usuario_id IS NULL)'
        : '';
      const params = comUsuario
        ? [osId, tenantId, usuarioId]
        : [osId, tenantId];

      const result = await db.raw(`
        SELECT COUNT(r.id) as total
        FROM respostas_apr r
        INNER JOIN ordem_servico os ON os.id = r.ordem_servico_id
        WHERE r.ordem_servico_id = ? AND os.tenant_id = ? ${filtroUsuario}
      `, params);

      const preenchido = parseInt(result.rows[0].total) > 0;

      return res.json({ success: true, data: { preenchido } });

    } catch (error) {
      console.error('❌ Erro ao verificar status APR:', error);
      return res.status(500).json({ success: false, error: 'Erro interno' });
    }
  }

  // =====================================================
  // GET /api/apr/pdf/:osId
  // Gera PDF do APR
  // =====================================================
  static async gerarPdf(req, res) {
    const { osId } = req.params;
    const tenantId = req.user?.tenant_id;

    try {
      console.log(`📄 Gerando PDF APR para OS ${osId}`);

      const AprPdfService = require('../services/AprPdfService');
      const pdfBuffer = await AprPdfService.gerarPdfApr(osId, tenantId);

      console.log(`✅ PDF gerado com sucesso (${pdfBuffer.length} bytes)`);

      // Retornar como Base64 para o Flutter
      return res.json({
        success: true,
        data: {
          pdf_base64: pdfBuffer.toString('base64'),
          filename: `APR_OS_${osId}_${Date.now()}.pdf`
        }
      });

    } catch (error) {
      console.error('❌ Erro ao gerar PDF APR:', error);
      return res.status(500).json({
        success: false,
        error: error.message || 'Erro ao gerar PDF'
      });
    }
  }
}

module.exports = AprController;