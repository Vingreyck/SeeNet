// src/routes/requisicoes_epi.js
const express = require('express');
const router = express.Router();
const db = require('../config/database');
const { authMiddleware } = require('../middleware/auth');
const PDFDocument = require('pdfkit');
const https = require('https');
const http = require('http');

// ================================================================
// HELPERS
// ================================================================

function isGestorOuAdmin(tipo) {
  return tipo === 'administrador' || tipo === 'gestor_seguranca';
}

// Baixa imagem de URL e retorna Buffer
function downloadImage(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client.get(url, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

// Converte base64 para Buffer (remove prefixo data:image/...)
function base64ToBuffer(base64String) {
  if (!base64String) return null;
  const clean = base64String.replace(/^data:image\/\w+;base64,/, '');
  return Buffer.from(clean, 'base64');
}

// Formata data brasileira
function formatarDataBR(date, incluirHora = true) {
  const d = new Date(date);
  const dia = String(d.getDate()).padStart(2, '0');
  const mes = String(d.getMonth() + 1).padStart(2, '0');
  const ano = d.getFullYear();
  if (!incluirHora) return `${dia}/${mes}/${ano}`;
  const hora = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${dia}/${mes}/${ano} às ${hora}:${min}`;
}

// ================================================================
// GERAÇÃO DE PDF PROFISSIONAL BBnet Up
// ================================================================
async function gerarPDF(requisicao, tecnico, gestor) {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 0,
        info: {
          Title: `Requisição EPI #${requisicao.id} - BBnet Up`,
          Author: 'SeeNet - BBnet Up',
          Subject: 'Requisição de Equipamentos de Proteção Individual',
        },
      });

      const chunks = [];
      doc.on('data', (chunk) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = 595.28; // largura A4
      const H = 841.89; // altura A4
      const MARGIN = 40;
      const VERDE = '#00C878';
      const VERDE_ESCURO = '#007A4A';
      const CINZA = '#F5F5F5';
      const CINZA_BORDA = '#E0E0E0';
      const TEXTO = '#1A1A1A';
      const TEXTO_SEC = '#555555';

      // ── HEADER VERDE ──────────────────────────────────────────
      doc.rect(0, 0, W, 90).fill(VERDE_ESCURO);

      // Faixa decorativa lateral esquerda
      doc.rect(0, 0, 8, 90).fill(VERDE);

      // Logo BBnet Up (tenta baixar, senão usa texto)
      let logoBuffer = null;
      try {
        logoBuffer = await downloadImage(
          'https://static.wixstatic.com/media/40655f_6e4972b166904af6957a3208c1ab4fa4~mv2.png'
        );
      } catch (_) {}

      if (logoBuffer) {
        doc.image(logoBuffer, 20, 12, { height: 65, fit: [200, 65] });
      } else {
        doc
          .fontSize(22)
          .fillColor('#FFFFFF')
          .font('Helvetica-Bold')
          .text('BBnet UP', 20, 28);
        doc
          .fontSize(10)
          .fillColor('#CCFFDD')
          .text('Provedor de Internet', 20, 56);
      }

      // Título do documento no header
      doc
        .fontSize(18)
        .fillColor('#FFFFFF')
        .font('Helvetica-Bold')
        .text('FICHA DE ENTREGA DE EPI', 0, 22, { align: 'right', width: W - 20 });

      doc
        .fontSize(10)
        .fillColor('#CCFFDD')
        .font('Helvetica')
        .text(
          `Equipamentos de Proteção Individual  •  Nº ${String(requisicao.id).padStart(5, '0')}`,
          0, 50,
          { align: 'right', width: W - 20 }
        );

      doc
        .fontSize(9)
        .fillColor('#AAFFCC')
        .text(
          `Gerado em ${formatarDataBR(new Date())}`,
          0, 70,
          { align: 'right', width: W - 20 }
        );

      // ── BARRA DE STATUS ───────────────────────────────────────
      const statusColor =
        requisicao.status === 'aprovada'
          ? VERDE
          : requisicao.status === 'recusada'
          ? '#FF4444'
          : '#FF9900';
      const statusLabel =
        requisicao.status === 'aprovada'
          ? '✔  APROVADA'
          : requisicao.status === 'recusada'
          ? '✖  RECUSADA'
          : '⏳  PENDENTE';

      doc.rect(0, 90, W, 28).fill(statusColor);
      doc
        .fontSize(11)
        .fillColor('#FFFFFF')
        .font('Helvetica-Bold')
        .text(statusLabel, 0, 98, { align: 'center', width: W });

      let y = 132;

      // ── FUNÇÃO HELPER: seção com título ───────────────────────
      function secao(titulo, altura = 24) {
        doc.rect(MARGIN, y, W - MARGIN * 2, altura).fill(VERDE_ESCURO);
        doc
          .fontSize(10)
          .fillColor('#FFFFFF')
          .font('Helvetica-Bold')
          .text(titulo.toUpperCase(), MARGIN + 10, y + 7);
        y += altura + 8;
      }

      // ── FUNÇÃO HELPER: linha de info ──────────────────────────
      function linha(label, valor, x1 = MARGIN, largura = W - MARGIN * 2) {
        doc.rect(x1, y, largura, 24).fill(CINZA);
        doc.rect(x1, y, largura, 24).stroke(CINZA_BORDA);
        doc
          .fontSize(8.5)
          .fillColor(TEXTO_SEC)
          .font('Helvetica')
          .text(label, x1 + 8, y + 4);
        doc
          .fontSize(10)
          .fillColor(TEXTO)
          .font('Helvetica-Bold')
          .text(valor || '—', x1 + 8, y + 13);
        y += 26;
      }

      function linha2col(label1, val1, label2, val2) {
        const mid = MARGIN + (W - MARGIN * 2) / 2 + 4;
        const colW = (W - MARGIN * 2) / 2 - 4;
        doc.rect(MARGIN, y, colW, 24).fill(CINZA).stroke(CINZA_BORDA);
        doc.fontSize(8.5).fillColor(TEXTO_SEC).font('Helvetica').text(label1, MARGIN + 8, y + 4);
        doc.fontSize(10).fillColor(TEXTO).font('Helvetica-Bold').text(val1 || '—', MARGIN + 8, y + 13);

        doc.rect(mid, y, colW, 24).fill(CINZA).stroke(CINZA_BORDA);
        doc.fontSize(8.5).fillColor(TEXTO_SEC).font('Helvetica').text(label2, mid + 8, y + 4);
        doc.fontSize(10).fillColor(TEXTO).font('Helvetica-Bold').text(val2 || '—', mid + 8, y + 13);
        y += 26;
      }

      // ── 1. DADOS DO TÉCNICO ───────────────────────────────────
      secao('1. Dados do Colaborador');
      linha('Nome Completo', tecnico.nome);
      linha2col(
        'E-mail', tecnico.email && !tecnico.email.endsWith('@seenet.local') ? tecnico.email : '—',
        'Função', tecnico.tipo_usuario === 'tecnico' ? 'Técnico de Campo' : tecnico.tipo_usuario
      );

      y += 8;

      // ── 2. DADOS DA REQUISIÇÃO ────────────────────────────────
      secao('2. Informações da Requisição');

      const dataRequisicao = requisicao.data_criacao
        ? formatarDataBR(requisicao.data_criacao)
        : '—';
      const dataEntrega = requisicao.data_entrega
        ? formatarDataBR(requisicao.data_entrega, false)
        : requisicao.data_resposta
        ? formatarDataBR(requisicao.data_resposta, false)
        : '—';

      linha2col(
        'Nº da Requisição', `#${String(requisicao.id).padStart(5, '0')}`,
        'Status', statusLabel.replace(/[✔✖⏳]\s+/, '')
      );
      linha2col(
        'Data/Hora da Solicitação', dataRequisicao,
        'Data de Entrega', dataEntrega
      );

      if (gestor) {
        linha2col(
          'Avaliado por', gestor.nome,
          'Data da Avaliação',
          requisicao.data_resposta ? formatarDataBR(requisicao.data_resposta) : '—'
        );
      }

      if (requisicao.registro_manual) {
        doc.rect(MARGIN, y, W - MARGIN * 2, 20).fill('#FFF8E1').stroke('#FFD54F');
        doc
          .fontSize(9)
          .fillColor('#795500')
          .font('Helvetica')
          .text(
            '⚠  Registro retroativo inserido manualmente pelo gestor de segurança.',
            MARGIN + 8, y + 5
          );
        y += 22;
      }

      y += 8;

      // ── 3. EPIs ENTREGUES ─────────────────────────────────────
      secao('3. Equipamentos de Proteção Individual (EPIs)');

      const epis = Array.isArray(requisicao.epis_solicitados)
        ? requisicao.epis_solicitados
        : JSON.parse(requisicao.epis_solicitados || '[]');

      // Grade 2 colunas
      const colW2 = (W - MARGIN * 2) / 2 - 4;
      let col = 0;
      let rowY = y;

      epis.forEach((epi, i) => {
        const x = col === 0 ? MARGIN : MARGIN + colW2 + 8;
        doc.rect(x, rowY, colW2, 22).fill(i % 2 === 0 ? CINZA : '#EEFFEE').stroke(CINZA_BORDA);
        // Checkbox verde
        doc.rect(x + 6, rowY + 6, 10, 10).fill(VERDE).stroke(VERDE_ESCURO);
        doc.fontSize(8).fillColor('#FFFFFF').font('Helvetica-Bold')
          .text('✓', x + 7, rowY + 7);
        doc.fontSize(9).fillColor(TEXTO).font('Helvetica')
          .text(epi, x + 22, rowY + 6, { width: colW2 - 28 });

        col++;
        if (col === 2) { col = 0; rowY += 24; }
      });

      if (col === 1) rowY += 24; // fecha linha incompleta
      y = rowY + 8;

      if (requisicao.observacao_gestor) {
        secao('4. Observações do Gestor');
        doc.rect(MARGIN, y, W - MARGIN * 2, 50).fill(CINZA).stroke(CINZA_BORDA);
        doc.fontSize(10).fillColor(TEXTO).font('Helvetica')
          .text(requisicao.observacao_gestor, MARGIN + 10, y + 8, {
            width: W - MARGIN * 2 - 20,
          });
        y += 58;
      }

      // ── FOTO + ASSINATURA (lado a lado) ──────────────────────
      const fotoBuffer = base64ToBuffer(requisicao.foto_base64);
      const sigBuffer = base64ToBuffer(requisicao.assinatura_base64);
      const secNum = requisicao.observacao_gestor ? 5 : 4;

      if (fotoBuffer || sigBuffer) {
        // Verifica espaço — se necessário, nova página
        if (y > 560) {
          doc.addPage();
          y = MARGIN;
        }

        const boxW = (W - MARGIN * 2) / 2 - 8;
        const boxH = 160;

        // Título seção
        doc.rect(MARGIN, y, W - MARGIN * 2, 24).fill(VERDE_ESCURO);
        doc.fontSize(10).fillColor('#FFFFFF').font('Helvetica-Bold')
          .text(
            `${secNum}. EVIDÊNCIA FOTOGRÁFICA E ASSINATURA DIGITAL`,
            MARGIN + 10, y + 7
          );
        y += 32;

        // Box foto
        if (fotoBuffer) {
          doc.rect(MARGIN, y, boxW, boxH).stroke(CINZA_BORDA);
          doc.fontSize(8.5).fillColor(TEXTO_SEC).font('Helvetica')
            .text('Foto de confirmação (colaborador + EPIs)', MARGIN + 6, y + 4);
          try {
            doc.image(fotoBuffer, MARGIN + 4, y + 16, {
              fit: [boxW - 8, boxH - 22],
              align: 'center',
              valign: 'center',
            });
          } catch (_) {}
        }

        // Box assinatura
        if (sigBuffer) {
          const sx = MARGIN + boxW + 16;
          doc.rect(sx, y, boxW, boxH).fill('#FAFAFA').stroke(CINZA_BORDA);
          doc.fontSize(8.5).fillColor(TEXTO_SEC).font('Helvetica')
            .text('Assinatura digital do colaborador', sx + 6, y + 4);
          try {
            doc.image(sigBuffer, sx + 4, y + 16, {
              fit: [boxW - 8, boxH - 22],
              align: 'center',
              valign: 'center',
            });
          } catch (_) {}
        }

        y += boxH + 12;
      }

      // ── DECLARAÇÃO LEGAL ──────────────────────────────────────
      if (y > 680) { doc.addPage(); y = MARGIN; }

      doc.rect(MARGIN, y, W - MARGIN * 2, 56).fill('#FFFDE7').stroke('#F9A825');
      doc.fontSize(8.5).fillColor('#4A3700').font('Helvetica')
        .text(
          'DECLARAÇÃO: Declaro que recebi os Equipamentos de Proteção Individual (EPIs) ' +
          'listados neste documento em perfeito estado de conservação, comprometendo-me a ' +
          'utilizá-los sempre que necessário, conforme NR-6 (Norma Regulamentadora nº 6 do ' +
          'Ministério do Trabalho). Estou ciente das responsabilidades quanto ao uso, ' +
          'conservação e devolução dos equipamentos.',
          MARGIN + 10, y + 8,
          { width: W - MARGIN * 2 - 20 }
        );
      y += 64;

      // ── RODAPÉ ────────────────────────────────────────────────
      const footerY = H - 50;
      doc.rect(0, footerY, W, 50).fill(VERDE_ESCURO);
      doc.rect(0, footerY, 8, 50).fill(VERDE);

      doc.fontSize(8.5).fillColor('#AAFFCC').font('Helvetica')
        .text(
          'BBnet Up Provedor Ltda  •  CNPJ 23.870.928/0002-03  •  Itabaiana - SE',
          MARGIN, footerY + 8
        );
      doc.fontSize(8).fillColor('#88DDAA')
        .text(
          `SeeNet Sistema de Gestão Técnica  •  Documento gerado eletronicamente em ${formatarDataBR(new Date())}  •  Req. #${String(requisicao.id).padStart(5,'0')}`,
          MARGIN, footerY + 24
        );

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

// ================================================================
// LISTA DE EPIs PADRÃO
// ================================================================
const EPIS_PADRAO = [
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

// ================================================================
// ROTAS
// ================================================================

// GET /api/seguranca/epis
router.get('/epis', authMiddleware, (req, res) => {
  res.json({ epis: EPIS_PADRAO });
});

// POST /api/seguranca/requisicoes — técnico cria
router.post('/requisicoes', authMiddleware, async (req, res) => {
  try {
    const { epis_solicitados, assinatura_base64, foto_base64 } = req.body;
    if (!epis_solicitados?.length) return res.status(400).json({ error: 'Selecione ao menos um EPI' });
    if (!assinatura_base64) return res.status(400).json({ error: 'Assinatura obrigatória' });
    if (!foto_base64) return res.status(400).json({ error: 'Foto obrigatória' });

    const [id] = await db('requisicoes_epi').insert({
      tenant_id: req.user.tenant_id,
      tecnico_id: req.user.id,
      status: 'pendente',
      epis_solicitados: JSON.stringify(epis_solicitados),
      assinatura_base64,
      foto_base64,
      registro_manual: false,
    }).returning('id');

    res.status(201).json({ success: true, message: 'Requisição enviada com sucesso!', id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erro ao criar requisição' });
  }
});

// POST /api/seguranca/requisicoes/manual — gestor registra manualmente
router.post('/requisicoes/manual', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) {
      return res.status(403).json({ error: 'Sem permissão' });
    }

    const {
      tecnico_id,
      epis_solicitados,
      assinatura_base64,
      foto_base64,
      observacao_gestor,
      data_entrega, // data manual da entrega
    } = req.body;

    if (!tecnico_id) return res.status(400).json({ error: 'Técnico obrigatório' });
    if (!epis_solicitados?.length) return res.status(400).json({ error: 'Selecione ao menos um EPI' });

    // Busca dados do tecnico
    const tecnico = await db('usuarios').where('id', tecnico_id).first();
    if (!tecnico) return res.status(404).json({ error: 'Técnico não encontrado' });

    const dataEntregaFinal = data_entrega ? new Date(data_entrega) : new Date();

    // Insere já como aprovada
    const [inserted] = await db('requisicoes_epi').insert({
      tenant_id: req.user.tenant_id,
      tecnico_id,
      gestor_id: req.user.id,
      status: 'aprovada',
      epis_solicitados: JSON.stringify(epis_solicitados),
      assinatura_base64: assinatura_base64 || null,
      foto_base64: foto_base64 || null,
      observacao_gestor: observacao_gestor || 'Registro manual pelo gestor de segurança.',
      data_resposta: new Date(),
      data_entrega: dataEntregaFinal,
      registro_manual: true,
      criado_por_gestor_id: req.user.id,
    }).returning('*');

    // Gera PDF
    try {
      const gestor = await db('usuarios').where('id', req.user.id).first();
      const pdfBuffer = await gerarPDF(inserted, tecnico, gestor);
      await db('requisicoes_epi').where('id', inserted.id).update({
        pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}`,
      });
    } catch (e) {
      console.error('Erro ao gerar PDF no registro manual:', e);
    }

    res.status(201).json({ success: true, message: 'Registro manual criado com sucesso!', id: inserted.id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erro ao criar registro manual' });
  }
});

// GET /api/seguranca/requisicoes/minhas
router.get('/requisicoes/minhas', authMiddleware, async (req, res) => {
  try {
    const lista = await db('requisicoes_epi as r')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tenant_id', req.user.tenant_id)
      .where('r.tecnico_id', req.user.id)
      .select(
        'r.*',
        'g.nome as gestor_nome'
      )
      .orderBy('r.data_criacao', 'desc');

    res.json({ requisicoes: lista });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar requisições' });
  }
});

// GET /api/seguranca/requisicoes/pendentes
router.get('/requisicoes/pendentes', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });

    const lista = await db('requisicoes_epi as r')
      .join('usuarios as t', 't.id', 'r.tecnico_id')
      .where('r.tenant_id', req.user.tenant_id)
      .where('r.status', 'pendente')
      .select('r.*', 't.nome as tecnico_nome', 't.email as tecnico_email')
      .orderBy('r.data_criacao', 'asc');

    res.json({ requisicoes: lista });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar pendentes' });
  }
});

// GET /api/seguranca/requisicoes
router.get('/requisicoes', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });

    let query = db('requisicoes_epi as r')
      .join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tenant_id', req.user.tenant_id)
      .select('r.*', 't.nome as tecnico_nome', 't.email as tecnico_email', 'g.nome as gestor_nome')
      .orderBy('r.data_criacao', 'desc');

    if (req.query.status) query = query.where('r.status', req.query.status);
    if (req.query.tecnico_id) query = query.where('r.tecnico_id', req.query.tecnico_id);

    const lista = await query;
    res.json({ requisicoes: lista });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar requisições' });
  }
});

// GET /api/seguranca/requisicoes/:id
router.get('/requisicoes/:id', authMiddleware, async (req, res) => {
  try {
    const req_data = await db('requisicoes_epi as r')
      .join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.id', req.params.id)
      .where('r.tenant_id', req.user.tenant_id)
      .select('r.*', 't.nome as tecnico_nome', 't.email as tecnico_email', 'g.nome as gestor_nome')
      .first();

    if (!req_data) return res.status(404).json({ error: 'Não encontrado' });

    // Verifica acesso
    if (req_data.tecnico_id !== req.user.id && !isGestorOuAdmin(req.user.tipo_usuario)) {
      return res.status(403).json({ error: 'Sem permissão' });
    }

    res.json({ requisicao: req_data });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar requisição' });
  }
});

// POST /api/seguranca/requisicoes/:id/aprovar
router.post('/requisicoes/:id/aprovar', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });

    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (!requisicao) return res.status(404).json({ error: 'Não encontrada' });

    await db('requisicoes_epi').where('id', req.params.id).update({
      status: 'aprovada',
      gestor_id: req.user.id,
      observacao_gestor: req.body.observacao || null,
      data_resposta: new Date(),
      data_entrega: req.body.data_entrega ? new Date(req.body.data_entrega) : new Date(),
    });

    const updated = await db('requisicoes_epi').where('id', req.params.id).first();
    const tecnico = await db('usuarios').where('id', updated.tecnico_id).first();
    const gestor = await db('usuarios').where('id', req.user.id).first();

    // Gera PDF
    try {
      const pdfBuffer = await gerarPDF(updated, tecnico, gestor);
      await db('requisicoes_epi').where('id', req.params.id).update({
        pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}`,
      });
    } catch (e) {
      console.error('Erro ao gerar PDF:', e);
    }

    res.json({ success: true, message: 'Requisição aprovada e PDF gerado!' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erro ao aprovar' });
  }
});

// POST /api/seguranca/requisicoes/:id/recusar
router.post('/requisicoes/:id/recusar', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    if (!req.body.observacao?.trim()) return res.status(400).json({ error: 'Motivo obrigatório' });

    await db('requisicoes_epi').where('id', req.params.id).update({
      status: 'recusada',
      gestor_id: req.user.id,
      observacao_gestor: req.body.observacao,
      data_resposta: new Date(),
    });

    res.json({ success: true, message: 'Requisição recusada.' });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao recusar' });
  }
});

// GET /api/seguranca/requisicoes/:id/pdf — baixa o PDF
router.get('/requisicoes/:id/pdf', authMiddleware, async (req, res) => {
  try {
    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (!requisicao) return res.status(404).json({ error: 'Não encontrada' });

    if (requisicao.tecnico_id !== req.user.id && !isGestorOuAdmin(req.user.tipo_usuario)) {
      return res.status(403).json({ error: 'Sem permissão' });
    }

    // Se não tiver PDF gerado ainda, gera agora
    let pdfBase64 = requisicao.pdf_base64;
    if (!pdfBase64 && requisicao.status === 'aprovada') {
      const tecnico = await db('usuarios').where('id', requisicao.tecnico_id).first();
      const gestor = requisicao.gestor_id
        ? await db('usuarios').where('id', requisicao.gestor_id).first()
        : null;
      const pdfBuffer = await gerarPDF(requisicao, tecnico, gestor);
      pdfBase64 = `data:application/pdf;base64,${pdfBuffer.toString('base64')}`;
      await db('requisicoes_epi').where('id', req.params.id).update({ pdf_base64: pdfBase64 });
    }

    if (!pdfBase64) return res.status(404).json({ error: 'PDF não disponível' });

    res.json({ pdf_base64: pdfBase64 });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar PDF' });
  }
});

// GET /api/seguranca/tecnicos — lista técnicos para o gestor
router.get('/tecnicos', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });

    const lista = await db('usuarios')
      .where('tenant_id', req.user.tenant_id)
      .where('ativo', true)
      .whereIn('tipo_usuario', ['tecnico', 'administrador'])
      .select('id', 'nome', 'email', 'tipo_usuario')
      .orderBy('nome');

    res.json({ tecnicos: lista });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar técnicos' });
  }
});

// GET /api/seguranca/perfil
router.get('/perfil', authMiddleware, async (req, res) => {
  try {
    const usuario = await db('usuarios')
      .where('id', req.user.id)
      .select('id', 'nome', 'email', 'tipo_usuario', 'foto_perfil', 'data_criacao', 'ultimo_login')
      .first();

    const tenant = await db('tenants').where('id', req.user.tenant_id).first();

    const stats = await db('requisicoes_epi')
      .where('tecnico_id', req.user.id)
      .where('tenant_id', req.user.tenant_id)
      .select(
        db.raw('COUNT(*) as total'),
        db.raw("COUNT(*) FILTER (WHERE status = 'aprovada') as aprovadas"),
        db.raw("COUNT(*) FILTER (WHERE status = 'pendente') as pendentes"),
        db.raw("COUNT(*) FILTER (WHERE status = 'recusada') as recusadas")
      )
      .first();

    res.json({
      usuario: { ...usuario, empresa: tenant?.nome },
      stats,
    });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar perfil' });
  }
});

// PUT /api/seguranca/perfil/foto
router.put('/perfil/foto', authMiddleware, async (req, res) => {
  try {
    const { foto_base64 } = req.body;
    if (!foto_base64) return res.status(400).json({ error: 'Foto obrigatória' });

    await db('usuarios').where('id', req.user.id).update({ foto_perfil: foto_base64 });
    res.json({ success: true, message: 'Foto atualizada!' });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao atualizar foto' });
  }
});

module.exports = router;