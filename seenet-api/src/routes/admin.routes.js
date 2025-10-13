// seenet-api/src/routes/admin.routes.js - VERSÃO CORRIGIDA PARA KNEX/POSTGRESQL
const express = require('express');
const router = express.Router();
const { db } = require('../config/database');
const { authMiddleware } = require('../middleware/auth');

// Middleware de autenticação
router.use(authMiddleware);

// Middleware para verificar se é admin (adicione no seu auth middleware se ainda não existe)
const requireAdmin = (req, res, next) => {
  if (!req.user || !req.user.is_admin) {
    return res.status(403).json({
      success: false,
      error: 'Acesso negado. Apenas administradores.'
    });
  }
  next();
};

// ========== REGISTRAR LOG DE AUDITORIA ==========
router.post('/logs', async (req, res) => {
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
    
    // Inserir log no banco PostgreSQL
    await db('logs_sistema').insert({
      usuario_id: usuario_id || req.user.id,
      acao,
      nivel: nivel || 'info',
      tabela_afetada,
      registro_id,
      dados_anteriores: dados_anteriores ? JSON.stringify(dados_anteriores) : null,
      dados_novos: dados_novos ? JSON.stringify(dados_novos) : null,
      detalhes,
      ip_address: ip_address || req.ip,
      user_agent: user_agent || req.get('User-Agent'),
      tenant_id: req.user.tenant_id,
      data_acao: db.fn.now()
    });
    
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
  }
});

// ========== BUSCAR LOGS COM FILTROS ==========
router.get('/logs', requireAdmin, async (req, res) => {
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
    
    let query = db('logs_sistema as l')
      .leftJoin('usuarios as u', 'l.usuario_id', 'u.id')
      .select(
        'l.*',
        'u.nome as usuario_nome',
        'u.email as usuario_email'
      )
      .where('l.tenant_id', req.user.tenant_id);
    
    // Aplicar filtros
    if (usuario_id) {
      query = query.where('l.usuario_id', usuario_id);
    }
    
    if (acao) {
      query = query.where('l.acao', acao);
    }
    
    if (nivel) {
      query = query.where('l.nivel', nivel);
    }
    
    if (data_inicio) {
      query = query.where('l.data_acao', '>=', data_inicio);
    }
    
    if (data_fim) {
      query = query.where('l.data_acao', '<=', data_fim);
    }
    
    // Aplicar paginação e ordenação
    const logs = await query
      .orderBy('l.data_acao', 'desc')
      .limit(parseInt(limite))
      .offset(parseInt(offset));
    
    res.json({
      success: true,
      data: {
        logs,
        total: logs.length,
        limite: parseInt(limite),
        offset: parseInt(offset)
      }
    });
    
  } catch (error) {
    console.error('❌ Erro ao buscar logs:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao buscar logs',
      details: error.message
    });
  }
});

// ========== ESTATÍSTICAS GERAIS ==========
router.get('/stats', requireAdmin, async (req, res) => {
  try {
    const { data_inicio, data_fim } = req.query;
    
    let baseQuery = db('logs_sistema')
      .where('tenant_id', req.user.tenant_id);
    
    if (data_inicio && data_fim) {
      baseQuery = baseQuery.whereBetween('data_acao', [data_inicio, data_fim]);
    }
    
    // Total por ação
    const totalPorAcao = await db('logs_sistema')
      .where('tenant_id', req.user.tenant_id)
      .modify((qb) => {
        if (data_inicio && data_fim) {
          qb.whereBetween('data_acao', [data_inicio, data_fim]);
        }
      })
      .select('acao')
      .count('* as total')
      .groupBy('acao')
      .orderBy('total', 'desc');
    
    // Total por nível
    const totalPorNivel = await db('logs_sistema')
      .where('tenant_id', req.user.tenant_id)
      .modify((qb) => {
        if (data_inicio && data_fim) {
          qb.whereBetween('data_acao', [data_inicio, data_fim]);
        }
      })
      .select('nivel')
      .count('* as total')
      .groupBy('nivel');
    
    // Usuários mais ativos
    const usuariosMaisAtivos = await db('logs_sistema as l')
      .join('usuarios as u', 'l.usuario_id', 'u.id')
      .where('l.tenant_id', req.user.tenant_id)
      .modify((qb) => {
        if (data_inicio && data_fim) {
          qb.whereBetween('l.data_acao', [data_inicio, data_fim]);
        }
      })
      .select('u.nome', 'u.email')
      .count('l.id as total_acoes')
      .groupBy('l.usuario_id', 'u.nome', 'u.email')
      .orderBy('total_acoes', 'desc')
      .limit(10);
    
    // Ações suspeitas
    const acoesSuspeitas = await db('logs_sistema')
      .whereIn('nivel', ['warning', 'error'])
      .where('tenant_id', req.user.tenant_id)
      .modify((qb) => {
        if (data_inicio && data_fim) {
          qb.whereBetween('data_acao', [data_inicio, data_fim]);
        }
      })
      .orderBy('data_acao', 'desc')
      .limit(50);
    
    // Calcular total de logs
    const totalLogs = totalPorAcao.reduce((sum, item) => sum + parseInt(item.total), 0);
    
    res.json({
      success: true,
      data: {
        periodo: {
          inicio: data_inicio || 'Início',
          fim: data_fim || 'Agora'
        },
        resumo: {
          total_logs: totalLogs,
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
      error: 'Erro ao gerar estatísticas',
      details: error.message
    });
  }
});

// ========== ESTATÍSTICAS RÁPIDAS ==========
router.get('/stats/quick', async (req, res) => {
  try {
    // Logs das últimas 24h
    const logs24h = await db('logs_sistema')
      .where('tenant_id', req.user.tenant_id)
      .where('data_acao', '>', db.raw("NOW() - INTERVAL '24 HOURS'"))
      .count('* as total')
      .first();
    
    // Ações críticas hoje
    const acoesCriticas = await db('logs_sistema')
      .where('tenant_id', req.user.tenant_id)
      .whereIn('nivel', ['warning', 'error'])
      .where('data_acao', '>', db.raw("NOW() - INTERVAL '24 HOURS'"))
      .count('* as total')
      .first();
    
    res.json({
      success: true,
      data: {
        logs_24h: parseInt(logs24h?.total || 0),
        acoes_criticas: parseInt(acoesCriticas?.total || 0)
      }
    });
    
  } catch (error) {
    console.error('❌ Erro ao obter estatísticas rápidas:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao obter estatísticas',
      details: error.message
    });
  }
});

// ========== EXPORTAR LOGS ==========
router.get('/logs/export', requireAdmin, async (req, res) => {
  try {
    const { data_inicio, data_fim, formato = 'json' } = req.query;
    
    let query = db('logs_sistema')
      .where('tenant_id', req.user.tenant_id);
    
    if (data_inicio && data_fim) {
      query = query.whereBetween('data_acao', [data_inicio, data_fim]);
    }
    
    const logs = await query.orderBy('data_acao', 'desc');
    
    if (formato === 'csv') {
      // Converter para CSV
      const csv = [
        'ID,Usuario ID,Acao,Nivel,Tabela,Registro ID,Detalhes,IP,Data',
        ...logs.map(log => 
          `${log.id},${log.usuario_id || ''},"${log.acao}","${log.nivel || ''}","${log.tabela_afetada || ''}",${log.registro_id || ''},"${(log.detalhes || '').replace(/"/g, '""')}","${log.ip_address || ''}","${log.data_acao}"`
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
      error: 'Erro ao exportar logs',
      details: error.message
    });
  }
});

// ========== LIMPAR LOGS ANTIGOS ==========
router.delete('/logs/cleanup', requireAdmin, async (req, res) => {
  try {
    const { dias = 90 } = req.query;
    
    // Deletar logs antigos
    const result = await db('logs_sistema')
      .where('tenant_id', req.user.tenant_id)
      .where('data_acao', '<', db.raw(`NOW() - INTERVAL '${parseInt(dias)} DAYS'`))
      .where('nivel', 'info')
      .delete();
    
    // Registrar limpeza
    await db('logs_sistema').insert({
      usuario_id: req.user.id,
      acao: 'DATA_CLEANUP',
      nivel: 'info',
      detalhes: `Limpeza automática: ${result} logs antigos removidos`,
      tenant_id: req.user.tenant_id,
      data_acao: db.fn.now()
    });
    
    res.json({
      success: true,
      data: {
        logs_removidos: result
      }
    });
    
  } catch (error) {
    console.error('❌ Erro ao limpar logs:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao limpar logs',
      details: error.message
    });
  }
});

module.exports = router;