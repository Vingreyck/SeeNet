const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

// ========== REGISTRAR LOG DE AUDITORIA ==========
router.post('/logs', authenticateToken, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const {
      usuario_id,
      acao,
      nivel,
      tabela_afetada,
      registro_id,
      dados_anteriores,
      dados_novos,
      detalhes,
      ip_address,
      user_agent
    } = req.body;
    
    // Inserir log
    await connection.query(
      `INSERT INTO logs_sistema (
        usuario_id, acao, nivel, tabela_afetada, registro_id,
        dados_anteriores, dados_novos, detalhes, ip_address, user_agent,
        tenant_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        usuario_id || req.user.id,
        acao,
        nivel || 'info',
        tabela_afetada,
        registro_id,
        dados_anteriores ? JSON.stringify(dados_anteriores) : null,
        dados_novos ? JSON.stringify(dados_novos) : null,
        detalhes,
        ip_address || req.ip,
        user_agent || req.get('User-Agent'),
        req.user.tenant_id
      ]
    );
    
    res.json({
      success: true,
      message: 'Log registrado com sucesso'
    });
    
  } catch (error) {
    console.error('❌ Erro ao registrar log:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao registrar log de auditoria'
    });
  } finally {
    connection.release();
  }
});

// ========== BUSCAR LOGS COM FILTROS ==========
router.get('/logs', authenticateToken, requireAdmin, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const {
      usuario_id,
      acao,
      nivel,
      data_inicio,
      data_fim,
      limite = 100,
      offset = 0
    } = req.query;
    
    let query = `
      SELECT l.*, u.nome as usuario_nome, u.email as usuario_email
      FROM logs_sistema l
      LEFT JOIN usuarios u ON l.usuario_id = u.id
      WHERE l.tenant_id = ?
    `;
    
    const params = [req.user.tenant_id];
    
    if (usuario_id) {
      query += ' AND l.usuario_id = ?';
      params.push(usuario_id);
    }
    
    if (acao) {
      query += ' AND l.acao = ?';
      params.push(acao);
    }
    
    if (nivel) {
      query += ' AND l.nivel = ?';
      params.push(nivel);
    }
    
    if (data_inicio) {
      query += ' AND l.data_acao >= ?';
      params.push(data_inicio);
    }
    
    if (data_fim) {
      query += ' AND l.data_acao <= ?';
      params.push(data_fim);
    }
    
    query += ' ORDER BY l.data_acao DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limite), parseInt(offset));
    
    const [logs] = await connection.query(query, params);
    
    res.json({
      success: true,
      data: {
        logs,
        total: logs.length
      }
    });
    
  } catch (error) {
    console.error('❌ Erro ao buscar logs:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao buscar logs'
    });
  } finally {
    connection.release();
  }
});

// ========== ESTATÍSTICAS GERAIS ==========
router.get('/stats', authenticateToken, requireAdmin, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const { data_inicio, data_fim } = req.query;
    
    let whereClause = 'WHERE tenant_id = ?';
    const params = [req.user.tenant_id];
    
    if (data_inicio && data_fim) {
      whereClause += ' AND data_acao BETWEEN ? AND ?';
      params.push(data_inicio, data_fim);
    }
    
    // Total por ação
    const [totalPorAcao] = await connection.query(
      `SELECT acao, COUNT(*) as total 
       FROM logs_sistema 
       ${whereClause}
       GROUP BY acao 
       ORDER BY total DESC`,
      params
    );
    
    // Total por nível
    const [totalPorNivel] = await connection.query(
      `SELECT nivel, COUNT(*) as total 
       FROM logs_sistema 
       ${whereClause}
       GROUP BY nivel`,
      params
    );
    
    // Usuários mais ativos
    const [usuariosMaisAtivos] = await connection.query(
      `SELECT u.nome, u.email, COUNT(l.id) as total_acoes
       FROM logs_sistema l
       JOIN usuarios u ON l.usuario_id = u.id
       ${whereClause}
       GROUP BY l.usuario_id
       ORDER BY total_acoes DESC
       LIMIT 10`,
      params
    );
    
    // Ações suspeitas
    const [acoesSuspeitas] = await connection.query(
      `SELECT * FROM logs_sistema 
       WHERE nivel IN ('warning', 'error')
       AND tenant_id = ?
       ${data_inicio && data_fim ? 'AND data_acao BETWEEN ? AND ?' : ''}
       ORDER BY data_acao DESC
       LIMIT 50`,
      data_inicio && data_fim ? [req.user.tenant_id, data_inicio, data_fim] : [req.user.tenant_id]
    );
    
    res.json({
      success: true,
      data: {
        periodo: {
          inicio: data_inicio || 'Início',
          fim: data_fim || 'Agora'
        },
        resumo: {
          total_logs: totalPorAcao.reduce((sum, item) => sum + item.total, 0),
          por_acao: totalPorAcao,
          por_nivel: totalPorNivel
        },
        usuarios_ativos: usuariosMaisAtivos,
        acoes_suspeitas: acoesSuspeitas
      }
    });
    
  } catch (error) {
    console.error('❌ Erro ao gerar estatísticas:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao gerar estatísticas'
    });
  } finally {
    connection.release();
  }
});

// ========== ESTATÍSTICAS RÁPIDAS ==========
router.get('/stats/quick', authenticateToken, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    // Logs das últimas 24h
    const [logs24h] = await connection.query(
      `SELECT COUNT(*) as total 
       FROM logs_sistema 
       WHERE tenant_id = ? 
       AND data_acao > DATE_SUB(NOW(), INTERVAL 24 HOUR)`,
      [req.user.tenant_id]
    );
    
    // Ações críticas hoje
    const [acoesCriticas] = await connection.query(
      `SELECT COUNT(*) as total 
       FROM logs_sistema 
       WHERE tenant_id = ?
       AND nivel IN ('warning', 'error')
       AND data_acao > DATE_SUB(NOW(), INTERVAL 24 HOUR)`,
      [req.user.tenant_id]
    );
    
    res.json({
      success: true,
      data: {
        logs_24h: logs24h[0].total,
        acoes_criticas: acoesCriticas[0].total
      }
    });
    
  } catch (error) {
    console.error('❌ Erro ao obter estatísticas rápidas:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao obter estatísticas'
    });
  } finally {
    connection.release();
  }
});

// ========== EXPORTAR LOGS ==========
router.get('/logs/export', authenticateToken, requireAdmin, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const { data_inicio, data_fim, formato = 'json' } = req.query;
    
    let query = 'SELECT * FROM logs_sistema WHERE tenant_id = ?';
    const params = [req.user.tenant_id];
    
    if (data_inicio && data_fim) {
      query += ' AND data_acao BETWEEN ? AND ?';
      params.push(data_inicio, data_fim);
    }
    
    query += ' ORDER BY data_acao DESC';
    
    const [logs] = await connection.query(query, params);
    
    if (formato === 'csv') {
      // Converter para CSV
      const csv = [
        'ID,Usuario ID,Acao,Nivel,Tabela,Registro ID,Detalhes,IP,Data',
        ...logs.map(log => 
          `${log.id},${log.usuario_id || ''},"${log.acao}","${log.nivel || ''}","${log.tabela_afetada || ''}",${log.registro_id || ''},"${log.detalhes || ''}","${log.ip_address || ''}","${log.data_acao}"`
        )
      ].join('\n');
      
      res.json({
        success: true,
        data: { export: csv }
      });
    } else {
      // JSON
      res.json({
        success: true,
        data: { export: JSON.stringify(logs, null, 2) }
      });
    }
    
  } catch (error) {
    console.error('❌ Erro ao exportar logs:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao exportar logs'
    });
  } finally {
    connection.release();
  }
});

// ========== LIMPAR LOGS ANTIGOS ==========
router.delete('/logs/cleanup', authenticateToken, requireAdmin, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const { dias = 90 } = req.query;
    
    const [result] = await connection.query(
      `DELETE FROM logs_sistema 
       WHERE tenant_id = ?
       AND data_acao < DATE_SUB(NOW(), INTERVAL ? DAY)
       AND nivel = 'info'`,
      [req.user.tenant_id, parseInt(dias)]
    );
    
    // Registrar limpeza
    await connection.query(
      `INSERT INTO logs_sistema (
        usuario_id, acao, nivel, detalhes, tenant_id
      ) VALUES (?, 'DATA_CLEANUP', 'info', ?, ?)`,
      [
        req.user.id,
        `Limpeza automática: ${result.affectedRows} logs antigos removidos`,
        req.user.tenant_id
      ]
    );
    
    res.json({
      success: true,
      data: {
        logs_removidos: result.affectedRows
      }
    });
    
  } catch (error) {
    console.error('❌ Erro ao limpar logs:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao limpar logs'
    });
  } finally {
    connection.release();
  }
});

module.exports = router;