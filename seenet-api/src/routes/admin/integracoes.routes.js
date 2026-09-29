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
    const tenantId = req.user.tenant_id;
    const isAdmin = req.user.tipo_usuario === 'administrador';

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

    // ⚠️ NÃO re-codificar o token em base64 aqui. `token_api` é gravado CRU
    // (é assim que TODO o resto do sistema — SincronizadorIXC, IXCService,
    // EstoqueAlertaService, TelegramBotService, OrdensServicoController etc.
    // — lê e usa direto, fazendo o Buffer.from(token).toString('base64')
    // SÓ na hora de montar o header `Authorization: Basic`). A versão antiga
    // desta rota fazia `Buffer.from(token_api).toString('base64')` ANTES de
    // salvar, o que dava um token DUAS VEZES codificado — passaria pelo teste
    // de conexão (feito com o token cru, req.body.token_api) e só quebraria
    // depois, silenciosamente, em TODA chamada real ao IXC (401). Achado em
    // 29/set antes de chegar a salvar, ao corrigir o bug de coluna abaixo.
    //
    // ⚠️ Coluna correta é `tenant_id` (era `empresa_id` — nome antigo, de antes
    // da tabela virar multi-tenant; o resto do sistema, ex. SincronizadorIXC,
    // já usa `tenant_id`). Com o nome errado, o INSERT/ON CONFLICT dava erro
    // de coluna inexistente e a rota nunca tinha chegado a salvar nada de
    // verdade (achado em 29/set, ao usar esta rota por trás de um script pela
    // 1ª vez). Faço existe→UPDATE / senão→INSERT em vez de ON CONFLICT porque
    // não há garantia de índice único em `tenant_id` nesta tabela sem migração.
    // `updated_at` também não existe nesta tabela (o campo de data real é
    // `ultima_sincronizacao`, gravado só pelo próprio sincronizador) — removido.
    const existente = await client.query(
      'SELECT id FROM integracao_ixc WHERE tenant_id = $1',
      [tenantId]
    );

    if (existente.rows.length > 0) {
      await client.query(`
        UPDATE integracao_ixc
        SET url_api = $1, token_api = $2, ativo = true
        WHERE tenant_id = $3
      `, [url_api, token_api, tenantId]);
    } else {
      await client.query(`
        INSERT INTO integracao_ixc (tenant_id, url_api, token_api, ativo)
        VALUES ($1, $2, $3, true)
      `, [tenantId, url_api, token_api]);
    }

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
    const tenantId = req.user.tenant_id;
    const isAdmin = req.user.tipo_usuario === 'administrador';

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
    const tenantId = req.user.tenant_id;

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

/**
 * Buscar o mapeamento IXC de um técnico (mostra a LOJA atual no admin)
 * GET /api/integracoes/ixc/mapeamento/:usuarioId
 */
router.get('/ixc/mapeamento/:usuarioId', async (req, res) => {
  try {
    const tenantId = req.user.tenant_id;
    const isAdmin = req.user.tipo_usuario === 'administrador';
    if (!isAdmin) {
      return res.status(403).json({ success: false, error: 'Apenas administradores' });
    }
    const { usuarioId } = req.params;
    // SELECT * evita erro caso a coluna id_almoxarifado_loja ainda não exista.
    const { rows } = await pool.query(
      `SELECT * FROM mapeamento_tecnicos_ixc WHERE usuario_id = $1 AND tenant_id = $2`,
      [usuarioId, tenantId]
    );
    const m = rows[0] || null;
    return res.json({
      success: true,
      data: m ? {
        usuario_id: m.usuario_id,
        tecnico_ixc_id: m.tecnico_ixc_id,
        id_almoxarifado: m.id_almoxarifado,
        almoxarifado_nome: m.almoxarifado_nome,
        id_almoxarifado_loja: m.id_almoxarifado_loja || null,
        almoxarifado_loja_nome: m.almoxarifado_loja_nome || null,
      } : null
    });
  } catch (error) {
    console.error('❌ Erro ao buscar mapeamento:', error.message);
    return res.status(500).json({ success: false, error: 'Erro ao buscar mapeamento' });
  }
});

/**
 * Mapear a LOJA (almoxarifado de desconto de material/comodato da OS) de um técnico.
 * NÃO altera o almox pessoal (EPI). POST /api/integracoes/ixc/mapear-loja
 * body: { usuario_id, id_almoxarifado_loja, almoxarifado_loja_nome }
 */
router.post('/ixc/mapear-loja', async (req, res) => {
  const client = await pool.connect();
  try {
    const tenantId = req.user.tenant_id;
    const isAdmin = req.user.tipo_usuario === 'administrador';
    if (!isAdmin) {
      return res.status(403).json({ success: false, error: 'Apenas administradores podem mapear' });
    }
    const { usuario_id, id_almoxarifado_loja, almoxarifado_loja_nome } = req.body;
    if (!usuario_id || !id_almoxarifado_loja) {
      return res.status(400).json({ success: false, error: 'usuario_id e id_almoxarifado_loja são obrigatórios' });
    }

    // Atualiza a linha existente do técnico (o mapeamento base — almox/colaborador —
    // já deve existir). Se não existir, orienta a mapear o técnico primeiro.
    const upd = await client.query(
      `UPDATE mapeamento_tecnicos_ixc
         SET id_almoxarifado_loja = $1,
             almoxarifado_loja_nome = $2
       WHERE usuario_id = $3 AND tenant_id = $4`,
      [id_almoxarifado_loja, almoxarifado_loja_nome || null, usuario_id, tenantId]
    );

    if (upd.rowCount === 0) {
      return res.status(400).json({
        success: false,
        error: 'Técnico ainda não tem mapeamento IXC (almoxarifado/colaborador). Configure o mapeamento base primeiro.'
      });
    }

    console.log(`🏬 Loja ${id_almoxarifado_loja} mapeada para o técnico ${usuario_id}`);
    return res.json({ success: true, message: 'Loja mapeada com sucesso' });
  } catch (error) {
    console.error('❌ Erro ao mapear loja:', error.message);
    return res.status(500).json({ success: false, error: 'Erro ao mapear loja' });
  } finally {
    client.release();
  }
});

module.exports = router;