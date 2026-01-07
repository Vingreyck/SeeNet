const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { db } = require('../config/database');
const geminiService = require('../services/geminiService');
const auditService = require('../services/auditService');
const logger = require('../config/logger');

const router = express.Router();

// ========== CRIAR TRANSCRIÇÃO ==========
router.post('/', [
  body('titulo').trim().isLength({ min: 2, max: 255 }),
  body('transcricao_original').trim().isLength({ min: 10, max: 10000 }),
  body('descricao').optional().trim().isLength({ max: 1000 }),
  body('duracao_segundos').optional().isInt({ min: 1 }),
  body('categoria_problema').optional().trim().isLength({ max: 100 }),
  body('cliente_info').optional().trim().isLength({ max: 500 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Dados inválidos', details: errors.array() });
    }

    const { 
      titulo, 
      transcricao_original, 
      descricao, 
      duracao_segundos, 
      categoria_problema, 
      cliente_info 
    } = req.body;

    // Processar com IA se disponível
    let pontos_da_acao;
    try {
      pontos_da_acao = await processarComIA(transcricao_original);
    } catch (iaError) {
      pontos_da_acao = gerarProcessamentoFallback(transcricao_original);
      logger.warn('IA indisponível, usando processamento fallback');
    }

    // Salvar transcrição
    const [transcricaoId] = await db('transcricoes_tecnicas').insert({
      tenant_id: req.tenantId,
      tecnico_id: req.user.id,
      titulo,
      descricao,
      transcricao_original,
      pontos_da_acao,
      status: 'concluida',
      duracao_segundos,
      categoria_problema,
      cliente_info,
      data_inicio: new Date().toISOString(),
      data_conclusao: new Date().toISOString(),
      data_upload: new Date().toISOString()
    });

    // Log de auditoria
    await auditService.log({
      action: 'TRANSCRIPTION_CREATED',
      usuario_id: req.user.id,
      tenant_id: req.tenantId,
      tabela_afetada: 'transcricoes_tecnicas',
      registro_id: transcricaoId,
      details: `Transcrição criada: ${titulo}`,
      ip_address: req.ip
    });

    logger.info(`✅ Transcrição criada: ${titulo} (Tenant: ${req.tenantCode})`);

    res.status(201).json({
      message: 'Transcrição salva com sucesso',
      id: transcricaoId
    });

  } catch (error) {
    logger.error('Erro ao criar transcrição:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LISTAR TRANSCRIÇÕES DO TÉCNICO ==========
router.get('/minhas', [
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('categoria').optional().trim(),
  query('busca').optional().trim()
], async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    
    let query = db('transcricoes_tecnicas')
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id);

    // Filtros opcionais
    if (req.query.categoria) {
      query = query.where('categoria_problema', req.query.categoria);
    }

    if (req.query.busca) {
      const busca = `%${req.query.busca}%`;
      query = query.where(function() {
        this.where('titulo', 'like', busca)
            .orWhere('transcricao_original', 'like', busca)
            .orWhere('pontos_da_acao', 'like', busca);
      });
    }

    // Contar total
    const totalQuery = query.clone();
    const total = await totalQuery.count('id as count').first();

    // Buscar transcrições
    const transcricoes = await query
      .orderBy('data_upload', 'desc')
      .limit(limit)
      .offset(offset)
      .select(
        'id',
        'titulo',
        'categoria_problema',
        'duracao_segundos',
        'status',
        'data_upload'
      );

    res.json({
      transcricoes,
      pagination: {
        page,
        limit,
        total: total.count,
        pages: Math.ceil(total.count / limit)
      }
    });

  } catch (error) {
    logger.error('Erro ao listar transcrições:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== VER TRANSCRIÇÃO COMPLETA ==========
router.get('/:transcricaoId', async (req, res) => {
  try {
    const { transcricaoId } = req.params;

    const transcricao = await db('transcricoes_tecnicas')
      .where('id', transcricaoId)
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id) // Só pode ver suas próprias
      .first();

    if (!transcricao) {
      return res.status(404).json({ error: 'Transcrição não encontrada' });
    }

    res.json({ transcricao });
  } catch (error) {
    logger.error('Erro ao buscar transcrição:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== ESTATÍSTICAS DO TÉCNICO ==========
router.get('/stats/resumo', async (req, res) => {
  try {
    const hoje = new Date();
    const inicioMes = new Date(hoje.getFullYear(), hoje.getMonth(), 1).toISOString();
    
    const stats = await db.raw(`
      SELECT 
        COUNT(*) as total_transcricoes,
        COUNT(CASE WHEN data_upload >= ? THEN 1 END) as este_mes,
        AVG(duracao_segundos) as duracao_media,
        SUM(duracao_segundos) as tempo_total
      FROM transcricoes_tecnicas 
      WHERE tenant_id = ? AND tecnico_id = ?
    `, [inicioMes, req.tenantId, req.user.id]);

    const categorias = await db('transcricoes_tecnicas')
      .where('tenant_id', req.tenantId)
      .where('tecnico_id', req.user.id)
      .whereNotNull('categoria_problema')
      .groupBy('categoria_problema')
      .select('categoria_problema')
      .count('* as total')
      .orderBy('total', 'desc')
      .limit(5);

    res.json({
      resumo: stats[0],
      categorias_mais_usadas: categorias
    });

  } catch (error) {
    logger.error('Erro ao buscar estatísticas:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== FUNÇÕES AUXILIARES ==========
async function processarComIA(transcricao) {
  const prompt = `
TAREFA: Transforme esta descrição técnica em pontos de ação organizados e profissionais.

TEXTO ORIGINAL:
"${transcricao}"

INSTRUÇÕES:
1. Extraia as ações técnicas realizadas
2. Organize em pontos numerados
3. Use linguagem técnica e profissional
4. Inclua detalhes importantes (equipamentos, configurações, resultados)
5. Mantenha ordem cronológica das ações
6. Adicione categoria do problema se identificável

FORMATO DE SAÍDA:

**CATEGORIA:** [Tipo do problema identificado]

**AÇÕES REALIZADAS:**
1. [Primeira ação com detalhes técnicos]
2. [Segunda ação com resultados]
3. [Terceira ação e verificações]

**RESULTADO:** [Status final e observações]

**OBSERVAÇÕES:** [Informações adicionais relevantes]
`;

  return await geminiService.gerarDiagnostico(prompt);
}

function gerarProcessamentoFallback(transcricao) {
  return `**CATEGORIA:** Atendimento Técnico

**AÇÕES REALIZADAS:**
1. Documentação registrada conforme relato do técnico
2. Procedimentos executados conforme protocolo padrão
3. Verificações técnicas realizadas no sistema

**RESULTADO:** Atendimento documentado com sucesso

**OBSERVAÇÕES:**
• Transcrição original: "${transcricao}"
• Data/Hora: ${new Date().toLocaleString('pt-BR')}
• Processamento realizado em modo local (IA não disponível)

---
💡 **Dica:** IA temporariamente indisponível. Processamento automático será restaurado em breve.`;
}

module.exports = router;
