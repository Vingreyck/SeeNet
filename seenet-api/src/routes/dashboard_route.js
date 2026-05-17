// Adicione este handler no arquivo src/routes/ordens_servico.js
// Rota: GET /api/ordens-servico/dashboard

router.get('/dashboard', autenticar, async (req, res) => {
  const tenantId = req.usuario.tenant_id;

  try {
    // ── 1. Mês de referência ─────────────────────────────────
    const agora = new Date();
    const meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    const mesReferencia = `${meses[agora.getMonth()]} ${agora.getFullYear()}`;

    // ── 2. Totais por status (todos os tempos) ───────────────
    const { rows: porStatus } = await pool.query(`
      SELECT
        status,
        COUNT(*)::int AS total
      FROM ordem_servico
      WHERE tenant_id = $1
        AND status IS NOT NULL
      GROUP BY status
      ORDER BY status
    `, [tenantId]);

    // ── 3. Tempo médio de execução (OSs concluídas este mês) ─
    const { rows: tempoMedio } = await pool.query(`
      SELECT
        ROUND(
          AVG(
            EXTRACT(EPOCH FROM (data_conclusao - data_inicio)) / 3600
          )::numeric, 1
        ) AS media_horas
      FROM ordem_servico
      WHERE tenant_id = $1
        AND status = 'concluida'
        AND data_inicio IS NOT NULL
        AND data_conclusao IS NOT NULL
        AND data_conclusao >= date_trunc('month', NOW())
    `, [tenantId]);

    // ── 4. Taxa de conclusão (concluídas / total excl. canceladas) ──
    const { rows: taxaRows } = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status = 'concluida')::float AS concluidas,
        COUNT(*) FILTER (WHERE status != 'cancelada')::float AS total
      FROM ordem_servico
      WHERE tenant_id = $1
        AND data_criacao >= date_trunc('month', NOW())
    `, [tenantId]);

    const concluidas = taxaRows[0]?.concluidas || 0;
    const totalMes   = taxaRows[0]?.total || 0;
    const taxaConclusao = totalMes > 0
      ? Math.round((concluidas / totalMes) * 100)
      : 0;

    // ── 5. OSs por técnico (este mês) ────────────────────────
    const { rows: porTecnico } = await pool.query(`
      SELECT
        u.nome  AS tecnico,
        os.status,
        COUNT(*)::int AS total
      FROM ordem_servico os
      JOIN usuarios u ON u.id = os.tecnico_id
      WHERE os.tenant_id = $1
        AND os.data_criacao >= date_trunc('month', NOW())
      GROUP BY u.nome, os.status
      ORDER BY u.nome, os.status
    `, [tenantId]);

    // ── 6. OSs abertas vs concluídas por dia (últimos 7 dias) ─
    const { rows: porDia } = await pool.query(`
      SELECT
        TO_CHAR(data_criacao, 'DD/MM') AS dia,
        COUNT(*) FILTER (WHERE status = 'concluida')::int AS concluidas,
        COUNT(*)::int AS total
      FROM ordem_servico
      WHERE tenant_id = $1
        AND data_criacao >= NOW() - INTERVAL '7 days'
      GROUP BY TO_CHAR(data_criacao, 'DD/MM'),
               DATE_TRUNC('day', data_criacao)
      ORDER BY DATE_TRUNC('day', data_criacao)
    `, [tenantId]);

    // ── 7. Técnico mais produtivo do mês ─────────────────────
    const { rows: topTecnico } = await pool.query(`
      SELECT
        u.nome AS tecnico,
        COUNT(*)::int AS total_concluidas
      FROM ordem_servico os
      JOIN usuarios u ON u.id = os.tecnico_id
      WHERE os.tenant_id = $1
        AND os.status = 'concluida'
        AND os.data_criacao >= date_trunc('month', NOW())
      GROUP BY u.nome
      ORDER BY total_concluidas DESC
      LIMIT 1
    `, [tenantId]);

    res.json({
      success: true,
      data: {
        mes_referencia:     mesReferencia,
        tempo_medio_horas:  tempoMedio[0]?.media_horas || '0',
        taxa_conclusao_prazo: taxaConclusao,
        por_status:         porStatus,
        por_tecnico:        porTecnico,
        por_dia:            porDia,
        top_tecnico:        topTecnico[0] || null,
      }
    });

  } catch (error) {
    console.error('[Dashboard] Erro:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao gerar dashboard'
    });
  }
});