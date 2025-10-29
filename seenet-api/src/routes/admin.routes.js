// seenet-api/src/routes/admin.routes.js - VERSÃO CORRIGIDA
const express = require('express');
const router = express.Router();
const { db } = require('../config/database');
const authMiddleware = require('../middleware/auth');

// Middleware para verificar se é admin
const requireAdmin = (req, res, next) => {
  if (!req.user || req.user.tipo_usuario !== 'administrador') {
    return res.status(403).json({
      success: false,
      error: 'Acesso negado. Apenas administradores.'
    });
  }
  next();
};

// ========== REGISTRAR LOG DE AUDITORIA ==========
router.post('/logs', authMiddleware, async (req, res) => {
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

// ========== BUSCAR LOGS COM FILTROS (ADMIN) ==========
router.get('/logs', authMiddleware, requireAdmin, async (req, res) => {
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
    
    if (usuario_id) query = query.where('l.usuario_id', usuario_id);
    if (acao) query = query.where('l.acao', acao);
    if (nivel) query = query.where('l.nivel', nivel);
    if (data_inicio) query = query.where('l.data_acao', '>=', data_inicio);
    if (data_fim) query = query.where('l.data_acao', '<=', data_fim);
    
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

// ========== ESTATÍSTICAS GERAIS (ADMIN) ==========
router.get('/stats', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { data_inicio, data_fim } = req.query;
    
    let baseQuery = db('logs_sistema')
      .where('tenant_id', req.user.tenant_id);
    
    if (data_inicio && data_fim) {
      baseQuery = baseQuery.whereBetween('data_acao', [data_inicio, data_fim]);
    }
    
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

// ========== ESTATÍSTICAS RÁPIDAS (ADMIN) ==========
router.get('/stats/quick', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const logs24h = await db('logs_sistema')
      .where('tenant_id', req.user.tenant_id)
      .where('data_acao', '>', db.raw("NOW() - INTERVAL '24 HOURS'"))
      .count('* as total')
      .first();
    
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

// ========== EXPORTAR LOGS (ADMIN) ==========
router.get('/logs/export', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { data_inicio, data_fim, formato = 'json' } = req.query;
    
    let query = db('logs_sistema')
      .where('tenant_id', req.user.tenant_id);
    
    if (data_inicio && data_fim) {
      query = query.whereBetween('data_acao', [data_inicio, data_fim]);
    }
    
    const logs = await query.orderBy('data_acao', 'desc');
    
    if (formato === 'csv') {
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

// ========== GERENCIAMENTO DE USUÁRIOS (ADMIN) ========== ✅ CORRIGIDO
router.get('/users', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const users = await db('usuarios')
      .where('tenant_id', req.user.tenant_id)
      .select('id', 'nome', 'email', 'tipo_usuario', 'ativo', 'data_criacao', 'data_atualizacao') // ✅ ADICIONADO 'ativo'
      .orderBy('nome');
    
    res.json(users);
  } catch (error) {
    console.error('❌ Erro ao buscar usuários:', error);
    res.status(500).json({
      error: 'Erro ao buscar usuários',
      details: error.message
    });
  }
});

router.post('/users', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { nome, email, senha, tipo_usuario } = req.body;
    
    const [id] = await db('usuarios').insert({
      nome,
      email,
      senha,
      tipo_usuario,
      tenant_id: req.user.tenant_id,
      // ✅ REMOVIDO: created_at e updated_at (deixar o banco usar defaults)
    }).returning('id');
    
    res.json({
      success: true,
      data: { id }
    });
  } catch (error) {
    console.error('❌ Erro ao criar usuário:', error);
    res.status(500).json({
      error: 'Erro ao criar usuário',
      details: error.message
    });
  }
});

router.put('/users/:id', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { nome, email, senha, tipo_usuario } = req.body;
    
    const updateData = {
      nome,
      email,
      tipo_usuario,
      data_atualizacao: db.fn.now() // ✅ CORRIGIDO
    };
    
    if (senha) {
      updateData.senha = senha;
    }
    
    await db('usuarios')
      .where({ id, tenant_id: req.user.tenant_id })
      .update(updateData);
    
    res.json({
      success: true
    });
  } catch (error) {
    console.error('❌ Erro ao atualizar usuário:', error);
    res.status(500).json({
      error: 'Erro ao atualizar usuário',
      details: error.message
    });
  }
});

router.delete('/users/:id', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    
    await db('usuarios')
      .where({ id, tenant_id: req.user.tenant_id })
      .delete();
    
    res.json({
      success: true
    });
  } catch (error) {
    console.error('❌ Erro ao excluir usuário:', error);
    res.status(500).json({
      error: 'Erro ao excluir usuário',
      details: error.message
    });
  }
});

// ========== LIMPAR LOGS ANTIGOS (ADMIN) ==========
router.delete('/logs/cleanup', authMiddleware, requireAdmin, async (req, res) => {
  try {
    const { dias = 90 } = req.query;
    
    const result = await db('logs_sistema')
      .where('tenant_id', req.user.tenant_id)
      .where('data_acao', '<', db.raw(`NOW() - INTERVAL '${parseInt(dias)} DAYS'`))
      .where('nivel', 'info')
      .delete();
    
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