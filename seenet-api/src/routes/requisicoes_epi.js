const express = require('express');
const router = express.Router();
const { db } = require('../config/database');
const auditService = require('../services/auditService');
const authMiddleware = require('../middleware/auth');

// Lista fixa de EPIs disponíveis
const LISTA_EPIS = [
  'Capacete de Segurança (Classe B)',
  'Carneira e Jugular',
  'Balaclava',
  'Óculos de Segurança',
  'Luva de Segurança (Isolante)',
  'Luva de Vaqueta',
  'Cinto de Segurança',
  'Talabarte de Posicionamento',
  'Trava-Quedas',
  'Detector de Tensão',
  'Cones de Sinalização',
  'Fita e/ou Corrente Zebrada',
];

// ========== LISTAR EPIS DISPONÍVEIS ==========
router.get('/epis', authMiddleware, (req, res) => {
  res.json({ epis: LISTA_EPIS });
});

// ========== CRIAR REQUISIÇÃO (técnico) ==========
router.post('/requisicoes', authMiddleware, async (req, res) => {
  try {
    const { epis_solicitados, assinatura_base64, foto_base64 } = req.body;
    const { userId, tenantId } = req.user;

    if (!epis_solicitados || epis_solicitados.length === 0) {
      return res.status(400).json({ error: 'Selecione ao menos um EPI' });
    }
    if (!assinatura_base64) {
      return res.status(400).json({ error: 'Assinatura é obrigatória' });
    }
    if (!foto_base64) {
      return res.status(400).json({ error: 'Foto é obrigatória' });
    }

    // Validar que os EPIs enviados são válidos
    const episInvalidos = epis_solicitados.filter(e => !LISTA_EPIS.includes(e));
    if (episInvalidos.length > 0) {
      return res.status(400).json({ error: `EPIs inválidos: ${episInvalidos.join(', ')}` });
    }

    const [nova] = await db('requisicoes_epi').insert({
      tenant_id: tenantId,
      tecnico_id: userId,
      epis_solicitados: JSON.stringify(epis_solicitados),
      assinatura_base64,
      foto_base64,
      status: 'pendente',
    }).returning('*');

    await auditService.log({
      action: 'REQUISICAO_EPI_CRIADA',
      usuario_id: userId,
      tenant_id: tenantId,
      details: `Requisição de EPI criada: ${epis_solicitados.join(', ')}`,
      ip_address: req.ip,
    });

    res.status(201).json({ message: 'Requisição enviada com sucesso', id: nova.id });
  } catch (error) {
    console.error('Erro ao criar requisição EPI:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== MINHAS REQUISIÇÕES (técnico) ==========
router.get('/requisicoes/minhas', authMiddleware, async (req, res) => {
  try {
    const { userId, tenantId } = req.user;

    const requisicoes = await db('requisicoes_epi as r')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tenant_id', tenantId)
      .where('r.tecnico_id', userId)
      .select(
        'r.id',
        'r.status',
        'r.epis_solicitados',
        'r.observacao_gestor',
        'r.pdf_base64',
        'r.data_criacao',
        'r.data_resposta',
        'g.nome as gestor_nome'
      )
      .orderBy('r.data_criacao', 'desc');

    res.json({ requisicoes });
  } catch (error) {
    console.error('Erro ao listar requisições:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LISTAR PENDENTES (gestor/admin) ==========
router.get('/requisicoes/pendentes', authMiddleware, async (req, res) => {
  try {
    const { tenantId, tipo } = req.user;

    if (!['administrador', 'gestor_seguranca'].includes(tipo)) {
      return res.status(403).json({ error: 'Acesso não autorizado' });
    }

    const requisicoes = await db('requisicoes_epi as r')
      .join('usuarios as t', 't.id', 'r.tecnico_id')
      .where('r.tenant_id', tenantId)
      .where('r.status', 'pendente')
      .select(
        'r.id',
        'r.status',
        'r.epis_solicitados',
        'r.assinatura_base64',
        'r.foto_base64',
        'r.data_criacao',
        't.nome as tecnico_nome',
        't.email as tecnico_email',
        't.foto_perfil as tecnico_foto_perfil'
      )
      .orderBy('r.data_criacao', 'asc');

    res.json({ requisicoes });
  } catch (error) {
    console.error('Erro ao listar pendentes:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== LISTAR TODAS (gestor/admin) ==========
router.get('/requisicoes', authMiddleware, async (req, res) => {
  try {
    const { tenantId, tipo } = req.user;

    if (!['administrador', 'gestor_seguranca'].includes(tipo)) {
      return res.status(403).json({ error: 'Acesso não autorizado' });
    }

    const { status } = req.query; // filtro opcional

    let query = db('requisicoes_epi as r')
      .join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tenant_id', tenantId)
      .select(
        'r.id',
        'r.status',
        'r.epis_solicitados',
        'r.observacao_gestor',
        'r.pdf_base64',
        'r.data_criacao',
        'r.data_resposta',
        't.nome as tecnico_nome',
        't.email as tecnico_email',
        'g.nome as gestor_nome'
      )
      .orderBy('r.data_criacao', 'desc');

    if (status) query = query.where('r.status', status);

    const requisicoes = await query;
    res.json({ requisicoes });
  } catch (error) {
    console.error('Erro ao listar requisições:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== DETALHE DE UMA REQUISIÇÃO ==========
router.get('/requisicoes/:id', authMiddleware, async (req, res) => {
  try {
    const { tenantId, userId, tipo } = req.user;
    const { id } = req.params;

    const requisicao = await db('requisicoes_epi as r')
      .join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tenant_id', tenantId)
      .where('r.id', id)
      .select(
        'r.*',
        't.nome as tecnico_nome',
        't.email as tecnico_email',
        't.foto_perfil as tecnico_foto_perfil',
        'g.nome as gestor_nome'
      )
      .first();

    if (!requisicao) {
      return res.status(404).json({ error: 'Requisição não encontrada' });
    }

    // Técnico só pode ver a própria
    if (tipo === 'tecnico' && requisicao.tecnico_id !== userId) {
      return res.status(403).json({ error: 'Acesso não autorizado' });
    }

    res.json({ requisicao });
  } catch (error) {
    console.error('Erro ao buscar requisição:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== APROVAR REQUISIÇÃO (gestor/admin) ==========
router.post('/requisicoes/:id/aprovar', authMiddleware, async (req, res) => {
  try {
    const { tenantId, userId, tipo } = req.user;
    const { id } = req.params;
    const { observacao } = req.body;

    if (!['administrador', 'gestor_seguranca'].includes(tipo)) {
      return res.status(403).json({ error: 'Acesso não autorizado' });
    }

    const requisicao = await db('requisicoes_epi')
      .where({ id, tenant_id: tenantId, status: 'pendente' })
      .first();

    if (!requisicao) {
      return res.status(404).json({ error: 'Requisição não encontrada ou já respondida' });
    }

    // Gerar PDF
    const pdfBase64 = await gerarPdfRequisicao(requisicao, 'aprovada', observacao);

    await db('requisicoes_epi').where('id', id).update({
      status: 'aprovada',
      gestor_id: userId,
      observacao_gestor: observacao || null,
      pdf_base64: pdfBase64,
      data_resposta: db.fn.now(),
      data_atualizacao: db.fn.now(),
    });

    await auditService.log({
      action: 'REQUISICAO_EPI_APROVADA',
      usuario_id: userId,
      tenant_id: tenantId,
      details: `Requisição #${id} aprovada`,
      ip_address: req.ip,
    });

    res.json({ message: 'Requisição aprovada com sucesso' });
  } catch (error) {
    console.error('Erro ao aprovar requisição:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== RECUSAR REQUISIÇÃO (gestor/admin) ==========
router.post('/requisicoes/:id/recusar', authMiddleware, async (req, res) => {
  try {
    const { tenantId, userId, tipo } = req.user;
    const { id } = req.params;
    const { observacao } = req.body;

    if (!['administrador', 'gestor_seguranca'].includes(tipo)) {
      return res.status(403).json({ error: 'Acesso não autorizado' });
    }

    if (!observacao) {
      return res.status(400).json({ error: 'Observação é obrigatória ao recusar' });
    }

    const requisicao = await db('requisicoes_epi')
      .where({ id, tenant_id: tenantId, status: 'pendente' })
      .first();

    if (!requisicao) {
      return res.status(404).json({ error: 'Requisição não encontrada ou já respondida' });
    }

    await db('requisicoes_epi').where('id', id).update({
      status: 'recusada',
      gestor_id: userId,
      observacao_gestor: observacao,
      data_resposta: db.fn.now(),
      data_atualizacao: db.fn.now(),
    });

    await auditService.log({
      action: 'REQUISICAO_EPI_RECUSADA',
      usuario_id: userId,
      tenant_id: tenantId,
      details: `Requisição #${id} recusada: ${observacao}`,
      ip_address: req.ip,
    });

    res.json({ message: 'Requisição recusada' });
  } catch (error) {
    console.error('Erro ao recusar requisição:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== ATUALIZAR FOTO DE PERFIL ==========
router.put('/perfil/foto', authMiddleware, async (req, res) => {
  try {
    const { userId, tenantId } = req.user;
    const { foto_base64 } = req.body;

    if (!foto_base64) {
      return res.status(400).json({ error: 'Foto é obrigatória' });
    }

    await db('usuarios').where('id', userId).update({
      foto_perfil: foto_base64,
      data_atualizacao: db.fn.now(),
    });

    res.json({ message: 'Foto de perfil atualizada' });
  } catch (error) {
    console.error('Erro ao atualizar foto:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== BUSCAR PERFIL ==========
router.get('/perfil', authMiddleware, async (req, res) => {
  try {
    const { userId, tenantId } = req.user;

    const usuario = await db('usuarios as u')
      .join('tenants as t', 't.id', 'u.tenant_id')
      .where('u.id', userId)
      .select(
        'u.id',
        'u.nome',
        'u.email',
        'u.tipo_usuario',
        'u.foto_perfil',
        'u.data_criacao',
        'u.ultimo_login',
        't.nome as empresa'
      )
      .first();

    // Contar requisições
    const stats = await db('requisicoes_epi')
      .where({ tecnico_id: userId, tenant_id: tenantId })
      .select(
        db.raw("COUNT(*) as total"),
        db.raw("COUNT(*) FILTER (WHERE status = 'aprovada') as aprovadas"),
        db.raw("COUNT(*) FILTER (WHERE status = 'pendente') as pendentes"),
        db.raw("COUNT(*) FILTER (WHERE status = 'recusada') as recusadas"),
      )
      .first();

    res.json({ usuario, stats });
  } catch (error) {
    console.error('Erro ao buscar perfil:', error);
    res.status(500).json({ error: 'Erro interno do servidor' });
  }
});

// ========== GERADOR DE PDF ==========
async function gerarPdfRequisicao(requisicao, status, observacao) {
  try {
    const PDFDocument = require('pdfkit');
    const { PassThrough } = require('stream');

    const tecnico = await db('usuarios').where('id', requisicao.tecnico_id).first();
    const epis = typeof requisicao.epis_solicitados === 'string'
      ? JSON.parse(requisicao.epis_solicitados)
      : requisicao.epis_solicitados;

    const doc = new PDFDocument({ margin: 50 });
    const pass = new PassThrough();
    const chunks = [];

    doc.pipe(pass);
    pass.on('data', chunk => chunks.push(chunk));

    // Cabeçalho
    doc.fontSize(18).font('Helvetica-Bold')
       .text('REQUERIMENTO DE EPI', { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(10).font('Helvetica')
       .text(`Nº: #${requisicao.id}`, { align: 'center' })
       .text(`Data: ${new Date(requisicao.data_criacao).toLocaleDateString('pt-BR')}`, { align: 'center' });

    doc.moveDown();
    doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
    doc.moveDown();

    // Dados do colaborador
    doc.fontSize(12).font('Helvetica-Bold').text('DADOS DO COLABORADOR');
    doc.moveDown(0.3);
    doc.fontSize(10).font('Helvetica')
       .text(`Nome: ${tecnico.nome}`)
       .text(`E-mail: ${tecnico.email}`)
       .text(`Data da requisição: ${new Date(requisicao.data_criacao).toLocaleString('pt-BR')}`);

    doc.moveDown();

    // Lista de EPIs
    doc.fontSize(12).font('Helvetica-Bold').text('EPIs SOLICITADOS');
    doc.moveDown(0.3);
    epis.forEach(epi => {
      doc.fontSize(10).font('Helvetica').text(`• ${epi}`);
    });

    doc.moveDown();

    // Status
    doc.fontSize(12).font('Helvetica-Bold').text('STATUS DA REQUISIÇÃO');
    doc.moveDown(0.3);
    doc.fontSize(10).font('Helvetica')
       .text(`Status: ${status.toUpperCase()}`)
       .text(`Data da resposta: ${new Date().toLocaleString('pt-BR')}`);

    if (observacao) {
      doc.text(`Observação: ${observacao}`);
    }

    doc.moveDown();

    // Assinatura do técnico (imagem base64)
    if (requisicao.assinatura_base64) {
      doc.fontSize(12).font('Helvetica-Bold').text('ASSINATURA DO COLABORADOR');
      doc.moveDown(0.3);
      try {
        const sigBuffer = Buffer.from(
          requisicao.assinatura_base64.replace(/^data:image\/\w+;base64,/, ''),
          'base64'
        );
        doc.image(sigBuffer, { width: 200, height: 80 });
      } catch (e) {
        doc.fontSize(10).font('Helvetica').text('[Assinatura registrada digitalmente]');
      }
    }

    doc.moveDown();

    // Foto do técnico com material
    if (requisicao.foto_base64) {
      doc.fontSize(12).font('Helvetica-Bold').text('FOTO DE CONFIRMAÇÃO');
      doc.moveDown(0.3);
      try {
        const fotoBuffer = Buffer.from(
          requisicao.foto_base64.replace(/^data:image\/\w+;base64,/, ''),
          'base64'
        );
        doc.image(fotoBuffer, { width: 200, height: 200 });
      } catch (e) {
        doc.fontSize(10).font('Helvetica').text('[Foto registrada]');
      }
    }

    doc.end();

    return new Promise((resolve, reject) => {
      pass.on('end', () => {
        const pdfBuffer = Buffer.concat(chunks);
        resolve(pdfBuffer.toString('base64'));
      });
      pass.on('error', reject);
    });
  } catch (error) {
    console.error('Erro ao gerar PDF:', error.message);
    return null;
  }
}

module.exports = router;