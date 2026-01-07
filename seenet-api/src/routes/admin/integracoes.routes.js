const express = require('express');
const router = express.Router();
const { Pool } = require('pg');
const IXCService = require('../../services/IXCService');
const authMiddleware = require('../../middleware/auth');
const crypto = require('crypto');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// ✅ Middleware de autenticação
router.use(authMiddleware);

/**
 * Configurar integração IXC
 * POST /api/integracoes/ixc/configurar
 */
router.post('/ixc/configurar', async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { url_api, token_api } = req.body;
    const { tenantId, isAdmin } = req.user;

    // Verificar se é admin
    if (!isAdmin) {
      return res.status(403).json({
        success: false,
        error: 'Apenas administradores podem configurar integrações'
      });
    }

    console.log('⚙️ Configurando integração IXC...');

    // Testar conexão antes de salvar
    const ixc = new IXCService(url_api, token_api);
    const conexaoOk = await ixc.testarConexao();

    if (!conexaoOk) {
      return res.status(400).json({
        success: false,
        error: 'Não foi possível conectar ao IXC com as credenciais fornecidas'
      });
    }

    await client.query('BEGIN');

    // Criptografar token (simples - você pode usar um método mais robusto)
    const tokenCriptografado = Buffer.from(token_api).toString('base64');

    // Inserir ou atualizar configuração
    await client.query(`
      INSERT INTO integracao_ixc (empresa_id, url_api, token_api, ativo)
      VALUES ($1, $2, $3, true)
      ON CONFLICT (empresa_id)
      DO UPDATE SET
        url_api = EXCLUDED.url_api,
        token_api = EXCLUDED.token_api,
        ativo = true,
        updated_at = NOW()
    `, [tenantId, url_api, tokenCriptografado]);

    await client.query('COMMIT');

    console.log('✅ Integração IXC configurada com sucesso');

    return res.json({
      success: true,
      message: 'Integração configurada com sucesso'
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Erro ao configurar integração:', error);
    return res.status(500).json({
      success: false,
      error: 'Erro ao configurar integração'
    });
  } finally {
    client.release();
  }
});

/**
 * Mapear técnico (SeeNet <-> IXC)
 * POST /api/integracoes/ixc/mapear-tecnico
 */
router.post('/ixc/mapear-tecnico', async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { tecnico_seenet_id, tecnico_ixc_id, tecnico_ixc_nome } = req.body;
    const { tenantId, isAdmin } = req.user;

    if (!isAdmin) {
      return res.status(403).json({
        success: false,
        error: 'Apenas administradores podem mapear técnicos'
      });
    }

    console.log(`🔗 Mapeando técnico SeeNet ${tecnico_seenet_id} -> IXC ${tecnico_ixc_id}`);

    await client.query('BEGIN');

    await client.query(`
      INSERT INTO mapeamento_tecnicos_ixc (
        empresa_id, tecnico_seenet_id, tecnico_ixc_id, tecnico_ixc_nome
      ) VALUES ($1, $2, $3, $4)
      ON CONFLICT (tecnico_seenet_id)
      DO UPDATE SET
        tecnico_ixc_id = EXCLUDED.tecnico_ixc_id,
        tecnico_ixc_nome = EXCLUDED.tecnico_ixc_nome,
        updated_at = NOW()
    `, [tenantId, tecnico_seenet_id, tecnico_ixc_id, tecnico_ixc_nome]);

    await client.query('COMMIT');

    console.log('✅ Técnico mapeado com sucesso');

    return res.json({
      success: true,
      message: 'Técnico mapeado com sucesso'
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Erro ao mapear técnico:', error);
    return res.status(500).json({
      success: false,
      error: 'Erro ao mapear técnico'
    });
  } finally {
    client.release();
  }
});

/**
 * Testar integração IXC
 * GET /api/integracoes/ixc/testar
 */
router.get('/ixc/testar', async (req, res) => {
  try {
    const { tenantId } = req.user;

    console.log('🧪 Testando integração IXC...');

    const { rows } = await pool.query(`
      SELECT url_api, token_api FROM integracao_ixc
      WHERE empresa_id = $1 AND ativo = true
    `, [tenantId]);

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Integração IXC não configurada'
      });
    }

    const integracao = rows[0];
    const tokenDescriptografado = Buffer.from(integracao.token_api, 'base64').toString();

    const ixc = new IXCService(integracao.url_api, tokenDescriptografado);
    const conexaoOk = await ixc.testarConexao();

    if (conexaoOk) {
      return res.json({
        success: true,
        message: 'Conexão com IXC OK'
      });
    } else {
      return res.status(500).json({
        success: false,
        error: 'Falha na conexão com IXC'
      });
    }
  } catch (error) {
    console.error('❌ Erro ao testar integração:', error);
    return res.status(500).json({
      success: false,
      error: 'Erro ao testar integração'
    });
  }
});

module.exports = router;