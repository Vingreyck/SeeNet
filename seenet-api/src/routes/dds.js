// src/routes/dds.js
const express = require('express');
const router = express.Router();
const { db } = require('../config/database');
const notificationService = require('../services/NotificationService');
const authMiddleware = require('../middleware/auth');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

// ================================================================
// HELPERS
// ================================================================
function isGestorOuAdmin(tipo) {
  return tipo === 'administrador' || tipo === 'gestor_seguranca' || tipo === 'gestor';
}

function formatarDataBR(date, incluirHora = true) {
  const d = new Date(date);
  const brt = new Date(d.getTime() - 3 * 60 * 60 * 1000);
  const dia = String(brt.getUTCDate()).padStart(2, '0');
  const mes = String(brt.getUTCMonth() + 1).padStart(2, '0');
  const ano = brt.getUTCFullYear();
  if (!incluirHora) return `${dia}/${mes}/${ano}`;
  const hora = String(brt.getUTCHours()).padStart(2, '0');
  const min = String(brt.getUTCMinutes()).padStart(2, '0');
  return `${dia}/${mes}/${ano} ${hora}:${min}`;
}

// Expirar sessões antigas
async function expirarSessoesAntigas() {
  await db('dds_sessoes')
    .where('status', 'ativo')
    .where('expira_em', '<', new Date())
    .update({ status: 'expirado' });
}

// ── Logo de segurança do trabalho (lido do disco uma vez) ──────
let _logoSegurancaBuf = null;
function getLogoSeguranca() {
  if (_logoSegurancaBuf) return _logoSegurancaBuf;
  try {
    const p = path.join(__dirname, '../assets/logo_seguranca_trabalho.png');
    _logoSegurancaBuf = fs.readFileSync(p);
    return _logoSegurancaBuf;
  } catch (_) { return null; }
}

// Desenha o logo no PDF — usa imagem real ou fallback
function desenharLogo(doc, x, y, size) {
  const buf = getLogoSeguranca();
  if (buf) {
    doc.image(buf, x, y, { width: size, height: size });
  } else {
    // Fallback simples
    doc.circle(x + size / 2, y + size / 2, size / 2 - 1).fill('#2E8B1E');
  }
}

// Centraliza uma imagem (buffer) dentro de uma célula da tabela
function imagemCentralizada(doc, imgBuf, cellX, cellY, cellW, cellH) {
  try {
    const si = doc.openImage(imgBuf);
    const scale = Math.min((cellW - 8) / si.width, (cellH - 4) / si.height);
    const iw = si.width * scale;
    const ih = si.height * scale;
    const ix = cellX + (cellW - iw) / 2;
    const iy = cellY + (cellH - ih) / 2;
    doc.image(imgBuf, ix, iy, { width: iw, height: ih });
  } catch (_) {}
}

// ================================================================
// ROTAS DE CONFIGURAÇÃO
// ================================================================

router.get('/config', authMiddleware, async (req, res) => {
  try {
    let config = await db('config_seguranca_dds')
      .where('tenant_id', req.user.tenant_id).first();
    if (!config) {
      const [inserted] = await db('config_seguranca_dds')
        .insert({ tenant_id: req.user.tenant_id }).returning('*');
      config = inserted;
    }
    res.json({ config });
  } catch (err) {
    console.error('❌ dds/config GET:', err);
    res.status(500).json({ error: 'Erro ao buscar configuração' });
  }
});

router.put('/config', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const { responsavel_nome, responsavel_cargo,
            responsavel_registro1, responsavel_registro2,
            responsavel_assinatura } = req.body;

    const update = { atualizado_em: new Date() };
    if (responsavel_nome       !== undefined) update.responsavel_nome       = responsavel_nome;
    if (responsavel_cargo      !== undefined) update.responsavel_cargo      = responsavel_cargo;
    if (responsavel_registro1  !== undefined) update.responsavel_registro1  = responsavel_registro1;
    if (responsavel_registro2  !== undefined) update.responsavel_registro2  = responsavel_registro2;
    if (responsavel_assinatura !== undefined) update.responsavel_assinatura = responsavel_assinatura;

    const existe = await db('config_seguranca_dds')
      .where('tenant_id', req.user.tenant_id).first();
    if (existe) {
      await db('config_seguranca_dds').where('tenant_id', req.user.tenant_id).update(update);
    } else {
      await db('config_seguranca_dds').insert({ tenant_id: req.user.tenant_id, ...update });
    }
    res.json({ success: true, message: 'Configuração salva!' });
  } catch (err) {
    console.error('❌ dds/config PUT:', err);
    res.status(500).json({ error: 'Erro ao salvar configuração' });
  }
});

// ================================================================
// CRIAR SESSÃO DE DDS
// ================================================================
router.post('/sessao', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const { tema, duracao_minutos, local_dds, link_meet } = req.body;
    if (!tema?.trim()) return res.status(400).json({ error: 'Tema obrigatório' });

    const minutos = parseInt(duracao_minutos) || 15;
    if (minutos < 1 || minutos > 120)
      return res.status(400).json({ error: 'Duração deve ser entre 1 e 120 minutos' });

    const expiraEm = new Date(Date.now() + minutos * 60 * 1000);
    const [sessao] = await db('dds_sessoes').insert({
      tenant_id: req.user.tenant_id, gestor_id: req.user.id,
      tema: tema.trim(), local_dds: local_dds?.trim() || 'BBNet Up Provedor',
      duracao_minutos: minutos, expira_em: expiraEm, status: 'ativo',
      link_meet: link_meet?.trim() || null,
    }).returning('*');

    console.log(`✅ DDS criado: "${tema}" — expira em ${minutos}min`);
    try {
      await notificationService.enviarParaTodos(
        db, req.user.tenant_id,
        '🦺 DDS Iniciado!',
        `Tema: ${tema.trim()} — Abra o app para registrar sua presença.`,
        { route: '/checklist', tipo: 'dds_novo', referencia_id: String(sessao.id) }
      );
    } catch (notifErr) {
      console.warn('⚠️ Falha ao notificar usuários do DDS:', notifErr.message);
    }
    res.status(201).json({
      success: true, message: 'DDS aberto com sucesso!',
      sessao: {
        id: sessao.id, tema: sessao.tema, local_dds: sessao.local_dds,
        duracao_minutos: sessao.duracao_minutos, expira_em: sessao.expira_em,
        status: sessao.status,
      }
    });
  } catch (err) {
    console.error('❌ dds/sessao POST:', err);
    res.status(500).json({ error: 'Erro ao criar sessão DDS' });
  }
});

// ================================================================
// VERIFICAR SESSÃO ATIVA
// ================================================================
router.get('/sessao/ativa', authMiddleware, async (req, res) => {
  try {
    await expirarSessoesAntigas();
    const sessao = await db('dds_sessoes')
      .where('tenant_id', req.user.tenant_id)
      .where('status', 'ativo')
      .orderBy('criado_em', 'desc').first();

    if (!sessao) return res.json({ sessao: null });

    const jaAssinou = await db('dds_assinaturas')
      .where('dds_sessao_id', sessao.id)
      .where('usuario_id', req.user.id).first();

    const msRestante = new Date(sessao.expira_em) - new Date();
    const segundosRestantes = Math.max(0, Math.floor(msRestante / 1000));

    res.json({
      sessao: {
        id: sessao.id, tema: sessao.tema, local_dds: sessao.local_dds,
        duracao_minutos: sessao.duracao_minutos, expira_em: sessao.expira_em,
        segundos_restantes: segundosRestantes, ja_assinou: !!jaAssinou,
        link_meet: sessao.link_meet || null,
      }
    });
  } catch (err) {
    console.error('❌ dds/sessao/ativa:', err);
    res.status(500).json({ error: 'Erro ao verificar sessão ativa' });
  }
});

// ================================================================
// ASSINAR PRESENÇA
// ================================================================
router.post('/sessao/:id/assinar', authMiddleware, async (req, res) => {
  try {
    const sessaoId = parseInt(req.params.id);
    const { foto_base64, assinatura_base64 } = req.body;
    if (!foto_base64 && !assinatura_base64)
      return res.status(400).json({ error: 'Foto de validação obrigatória' });

    await expirarSessoesAntigas();
    const sessao = await db('dds_sessoes')
      .where('id', sessaoId).where('tenant_id', req.user.tenant_id).first();
    if (!sessao) return res.status(404).json({ error: 'Sessão não encontrada' });
    if (sessao.status !== 'ativo') return res.status(400).json({ error: 'Esta sessão de DDS já expirou' });

    const existe = await db('dds_assinaturas')
      .where('dds_sessao_id', sessaoId).where('usuario_id', req.user.id).first();
    if (existe) return res.status(400).json({ error: 'Você já assinou neste DDS' });

    await db('dds_assinaturas').insert({
      dds_sessao_id: sessaoId,
      usuario_id: req.user.id,
      foto_base64: foto_base64 || null,
      assinatura_base64: assinatura_base64 || null,
      assinado_em: new Date(),
    });

    console.log(`✅ DDS ${sessaoId} — assinatura de ${req.user.nome || req.user.id}`);
    res.json({ success: true, message: 'Presença registrada com sucesso!' });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ error: 'Você já assinou neste DDS' });
    console.error('❌ dds/assinar:', err);
    res.status(500).json({ error: 'Erro ao registrar assinatura' });
  }
});

// ================================================================
// HISTÓRICO
// ================================================================
router.get('/historico', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    await expirarSessoesAntigas();
    const { ano, mes } = req.query;

    let query = db('dds_sessoes as s')
      .leftJoin('usuarios as g', 'g.id', 's.gestor_id')
      .where('s.tenant_id', req.user.tenant_id)
      .where('s.status', 'expirado')
      .select(
        's.id', 's.tema', 's.local_dds', 's.duracao_minutos',
        's.expira_em', 's.criado_em', 's.status', 'g.nome as gestor_nome',
        db.raw('(SELECT COUNT(*) FROM dds_assinaturas WHERE dds_sessao_id = s.id) as total_assinaturas')
      )
      .orderBy('s.criado_em', 'desc');

    if (ano) query = query.whereRaw('EXTRACT(YEAR FROM s.criado_em) = ?', [ano]);
    if (mes) query = query.whereRaw('EXTRACT(MONTH FROM s.criado_em) = ?', [mes]);

    const sessoes = await query;
    res.json({ sessoes });
  } catch (err) {
    console.error('❌ dds/historico:', err);
    res.status(500).json({ error: 'Erro ao buscar histórico' });
  }
});

// ================================================================
// PARTICIPANTES
// ================================================================
router.get('/sessao/:id/participantes', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const sessaoId = parseInt(req.params.id);
    const sessao = await db('dds_sessoes')
      .where('id', sessaoId).where('tenant_id', req.user.tenant_id).first();
    if (!sessao) return res.status(404).json({ error: 'Sessão não encontrada' });

    const participantes = await db('dds_assinaturas as a')
      .join('usuarios as u', 'u.id', 'a.usuario_id')
      .where('a.dds_sessao_id', sessaoId)
      .select('u.id', 'u.nome', 'u.tipo_usuario', 'a.assinatura_base64', 'a.foto_base64', 'a.assinado_em')
      .orderBy('a.assinado_em', 'asc');

    res.json({ sessao, participantes });
  } catch (err) {
    console.error('❌ dds/participantes:', err);
    res.status(500).json({ error: 'Erro ao buscar participantes' });
  }
});

// ================================================================
// CALENDÁRIO DO TÉCNICO
// ================================================================
router.get('/tecnico/:id/calendario', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const tecnicoId = parseInt(req.params.id);
    const { ano } = req.query;

    let query = db('dds_assinaturas as a')
      .join('dds_sessoes as s', 's.id', 'a.dds_sessao_id')
      .where('a.usuario_id', tecnicoId)
      .where('s.tenant_id', req.user.tenant_id)
      .select(
        's.id as sessao_id', 's.tema', 's.local_dds', 's.duracao_minutos',
        'a.assinatura_base64', 'a.assinado_em',
        db.raw("TO_CHAR(a.assinado_em AT TIME ZONE 'UTC' AT TIME ZONE 'America/Maceio', 'YYYY-MM-DD') as data_str")
      )
      .orderBy('a.assinado_em', 'desc');

    if (ano) {
      query = query.whereRaw(
        "EXTRACT(YEAR FROM a.assinado_em AT TIME ZONE 'UTC' AT TIME ZONE 'America/Maceio') = ?", [ano]
      );
    }

    const registros = await query;
    const porData = {};
    for (const r of registros) {
      if (!porData[r.data_str]) porData[r.data_str] = [];
      porData[r.data_str].push({
        sessao_id: r.sessao_id, tema: r.tema, local_dds: r.local_dds,
        duracao_minutos: r.duracao_minutos, assinatura_base64: r.assinatura_base64,
        assinado_em: r.assinado_em,
      });
    }
    res.json({ calendario: porData });
  } catch (err) {
    console.error('❌ dds/calendario:', err);
    res.status(500).json({ error: 'Erro ao buscar calendário' });
  }
});

// ================================================================
// ENCERRAR SESSÃO
// ================================================================
router.put('/sessao/:id/encerrar', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });
    await db('dds_sessoes')
      .where('id', req.params.id).where('tenant_id', req.user.tenant_id)
      .update({ status: 'expirado' });
    res.json({ success: true, message: 'Sessão encerrada' });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao encerrar sessão' });
  }
});

// ================================================================
// PDF — HISTÓRICO ANUAL
// ================================================================
router.get('/historico/pdf', (req, res, next) => {
  if (!req.headers.authorization && req.query.token) {
    req.headers.authorization = `Bearer ${req.query.token}`;
    try {
      const decoded = require('jsonwebtoken').decode(req.query.token);
      if (decoded?.tenantCode) req.headers['x-tenant-code'] = decoded.tenantCode;
    } catch (_) {}
  }
  next();
}, authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const ano = req.query.ano || new Date().getFullYear();
    const sessoes = await db('dds_sessoes as s')
      .leftJoin('usuarios as g', 'g.id', 's.gestor_id')
      .where('s.tenant_id', req.user.tenant_id)
      .where('s.status', 'expirado')
      .whereRaw('EXTRACT(YEAR FROM s.criado_em) = ?', [ano])
      .select('s.id', 's.tema', 's.local_dds', 's.duracao_minutos', 's.criado_em', 'g.nome as gestor_nome')
      .orderBy('s.criado_em', 'asc');

    let config = await db('config_seguranca_dds').where('tenant_id', req.user.tenant_id).first();
    if (!config) config = {
      responsavel_nome: 'Wellington Carvalho da Costa Junior',
      responsavel_cargo: 'Técnico de Segurança do Trabalho',
      responsavel_registro1: 'CREA/SE: 2716950962',
      responsavel_registro2: 'MTE/SE: 0045411/SE',
      responsavel_assinatura: null,
    };

    const porMes = {};
    const MESES = ['','JANEIRO','FEVEREIRO','MARÇO','ABRIL','MAIO','JUNHO',
      'JULHO','AGOSTO','SETEMBRO','OUTUBRO','NOVEMBRO','DEZEMBRO'];
    for (const s of sessoes) {
      const m = new Date(s.criado_em).getMonth() + 1;
      if (!porMes[m]) porMes[m] = [];
      porMes[m].push(s);
    }

    const pdfBuffer = await gerarPdfHistoricoDDS(sessoes, porMes, MESES, ano, config);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=DDS_${ano}.pdf`);
    res.send(pdfBuffer);
  } catch (err) {
    console.error('❌ dds/historico/pdf:', err);
    res.status(500).json({ error: 'Erro ao gerar PDF' });
  }
});

// ================================================================
// PDF — SESSÃO INDIVIDUAL
// ================================================================
router.get('/sessao/:id/pdf', (req, res, next) => {
  if (!req.headers.authorization && req.query.token) {
    req.headers.authorization = `Bearer ${req.query.token}`;
    try {
      const decoded = require('jsonwebtoken').decode(req.query.token);
      if (decoded?.tenantCode) req.headers['x-tenant-code'] = decoded.tenantCode;
    } catch (_) {}
  }
  next();
}, authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const sessaoId = parseInt(req.params.id);
    const sessao = await db('dds_sessoes as s')
      .leftJoin('usuarios as g', 'g.id', 's.gestor_id')
      .where('s.id', sessaoId).where('s.tenant_id', req.user.tenant_id)
      .select('s.*', 'g.nome as gestor_nome').first();
    if (!sessao) return res.status(404).json({ error: 'Sessão não encontrada' });

    const participantes = await db('dds_assinaturas as a')
      .join('usuarios as u', 'u.id', 'a.usuario_id')
      .where('a.dds_sessao_id', sessaoId)
      .select('u.nome', 'a.assinatura_base64', 'a.assinado_em')
      .orderBy('a.assinado_em', 'asc');

    let config = await db('config_seguranca_dds').where('tenant_id', req.user.tenant_id).first();
    if (!config) config = {
      responsavel_nome: 'Wellington Carvalho da Costa Junior',
      responsavel_cargo: 'Técnico de Segurança do Trabalho',
      responsavel_registro1: 'CREA/SE: 2716950962',
      responsavel_registro2: 'MTE/SE: 0045411/SE',
      responsavel_assinatura: null,
    };

    const pdfBuffer = await gerarPdfSessaoDDS(sessao, participantes, config);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=DDS_Sessao_${sessaoId}.pdf`);
    res.send(pdfBuffer);
  } catch (err) {
    console.error('❌ dds/sessao/pdf:', err);
    res.status(500).json({ error: 'Erro ao gerar PDF' });
  }
});

// ================================================================
// GERAÇÃO DE PDF — HISTÓRICO ANUAL
// ================================================================
async function gerarPdfHistoricoDDS(sessoes, porMes, MESES, ano, config) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ size: 'A4', margin: 0 });
      const chunks = [];
      doc.on('data', c => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = 595.28;
      const M = 28;
      const CW = W - M * 2;
      const VERDE = '#2E8B1E';
      const AMARELO = '#FFD700';
      const CB = '#666666';
      const cruzSize = 50;

      let y = M;

      // ── CABEÇALHO ──────────────────────────────────────────────
      desenharLogo(doc, M + 2, y, cruzSize);
      desenharLogo(doc, W - M - cruzSize - 2, y, cruzSize);
      doc.fontSize(16).font('Helvetica-Bold').fillColor('#000000')
        .text('BW TELECOM LTDA', M + cruzSize + 20, y + 8,
          { width: CW - (cruzSize + 20) * 2, align: 'center' });
      y += cruzSize + 12;

      doc.rect(M, y, CW, 28).fill(VERDE);
      doc.fontSize(13).font('Helvetica-Bold').fillColor('#FFFFFF')
        .text(`REGISTRO DE DDS REALIZADOS ${ano}`, M, y + 7, { width: CW, align: 'center' });
      y += 32 + 6;

      // ── CABEÇALHO TABELA ────────────────────────────────────────
      const COL = {
        data:    { x: M,       w: 52 },
        tempo:   { x: M + 52,  w: 42 },
        assunto: { x: M + 94,  w: 230 },
        local:   { x: M + 324, w: 108 },
        resp:    { x: M + 432, w: CW - 432 },
      };

      function drawHeader(yPos) {
        Object.values(COL).forEach(c => {
          doc.rect(c.x, yPos, c.w, 18).fill(AMARELO).stroke(CB);
        });
        doc.fontSize(8.5).font('Helvetica-Bold').fillColor('#000000');
        doc.text('DATA',             COL.data.x,    yPos + 5, { width: COL.data.w,    align: 'center' });
        doc.text('TEMPO',            COL.tempo.x,   yPos + 5, { width: COL.tempo.w,   align: 'center' });
        doc.text('ASSUNTO ABORDADO', COL.assunto.x, yPos + 5, { width: COL.assunto.w, align: 'center' });
        doc.text('LOCAL',            COL.local.x,   yPos + 5, { width: COL.local.w,   align: 'center' });
        doc.text('RESPONSÁVEL',      COL.resp.x,    yPos + 5, { width: COL.resp.w,    align: 'center' });
        return yPos + 20;
      }

      y = drawHeader(y);
      let zebra = false;

      for (const [mesNum, lista] of Object.entries(porMes).sort((a, b) => a[0] - b[0])) {
        if (y > 760) { doc.addPage(); y = M; y = drawHeader(y); }

        doc.rect(M, y, CW, 16).fill('#D9D9D9').stroke(CB);
        doc.fontSize(9).font('Helvetica-Bold').fillColor('#000000')
          .text(`MÊS DE ${MESES[parseInt(mesNum)]} ${ano}`, M, y + 4, { width: CW, align: 'center' });
        y += 16;

        for (const s of lista) {
          if (y > 760) { doc.addPage(); y = M; y = drawHeader(y); }

          const rH = 18;
          const bg = zebra ? '#FFFFFF' : '#F5F5F5';
          zebra = !zebra;

          Object.values(COL).forEach(c => {
            doc.rect(c.x, y, c.w, rH).fill(bg).stroke(CB);
          });

          doc.fontSize(8).font('Helvetica').fillColor('#000000');
          doc.text(formatarDataBR(s.criado_em, false), COL.data.x + 2,    y + 5, { width: COL.data.w - 4 });
          doc.text(`5 a ${s.duracao_minutos} mts`,     COL.tempo.x + 2,   y + 5, { width: COL.tempo.w - 4 });
          doc.text(s.tema.toUpperCase(),                COL.assunto.x + 2, y + 5, { width: COL.assunto.w - 4, ellipsis: true, lineBreak: false });
          doc.text(s.local_dds || 'BBNet Up Provedor',  COL.local.x + 2,   y + 5, { width: COL.local.w - 4,   ellipsis: true, lineBreak: false });

          // Assinatura do responsável centralizada na célula
          if (config.responsavel_assinatura) {
            try {
              const sigClean = config.responsavel_assinatura.replace(/^data:image\/\w+;base64,/, '');
              const sigBuf = Buffer.from(sigClean, 'base64');
              imagemCentralizada(doc, sigBuf, COL.resp.x, y, COL.resp.w, rH);
            } catch (_) {}
          }

          y += rH;
        }
      }

      // ── RODAPÉ RESPONSÁVEL ──────────────────────────────────────
      if (y > 720) { doc.addPage(); y = M; }
      y += 20;

      const footerX = M + CW * 0.5;
      const footerW = CW * 0.45;

      if (config.responsavel_assinatura) {
        try {
          const sigClean = config.responsavel_assinatura.replace(/^data:image\/\w+;base64,/, '');
          const sigBuf = Buffer.from(sigClean, 'base64');
          imagemCentralizada(doc, sigBuf, footerX, y, footerW, 36);
        } catch (_) {}
      }

      doc.moveTo(footerX, y + 38).lineTo(footerX + footerW, y + 38)
        .strokeColor('#000000').lineWidth(0.8).stroke();
      doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
        .text(config.responsavel_nome    || '', footerX, y + 40, { width: footerW, align: 'center' });
      doc.fontSize(7).font('Helvetica')
        .text(config.responsavel_cargo   || '', footerX, y + 50, { width: footerW, align: 'center' });
      doc.text(config.responsavel_registro1 || '', footerX, y + 59, { width: footerW, align: 'center' });
      doc.text(config.responsavel_registro2 || '', footerX, y + 68, { width: footerW, align: 'center' });

      doc.end();
    } catch (err) { reject(err); }
  });
}

// ================================================================
// GERAÇÃO DE PDF — SESSÃO INDIVIDUAL (lista de presença)
// ================================================================
async function gerarPdfSessaoDDS(sessao, participantes, config) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ size: 'A4', margin: 0 });
      const chunks = [];
      doc.on('data', c => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = 595.28;
      const M = 28;
      const CW = W - M * 2;
      const VERDE = '#2E8B1E';
      const AMARELO = '#FFD700';
      const CB = '#666666';
      const cruzSize = 50;

      let y = M;

      // ── CABEÇALHO ──────────────────────────────────────────────
      desenharLogo(doc, M + 2, y, cruzSize);
      desenharLogo(doc, W - M - cruzSize - 2, y, cruzSize);
      doc.fontSize(16).font('Helvetica-Bold').fillColor('#000000')
        .text('BW TELECOM LTDA', M + cruzSize + 20, y + 8,
          { width: CW - (cruzSize + 20) * 2, align: 'center' });
      y += cruzSize + 12;

      doc.rect(M, y, CW, 28).fill(VERDE);
      doc.fontSize(13).font('Helvetica-Bold').fillColor('#FFFFFF')
        .text('LISTA DE PRESENÇA — DDS', M, y + 7, { width: CW, align: 'center' });
      y += 36;

      // ── DADOS DA SESSÃO ─────────────────────────────────────────
      function campoInfo(label, valor, xPos, largura) {
        doc.rect(xPos, y, largura, 22).fill('#F5F5F5').stroke(CB);
        doc.fontSize(7.5).font('Helvetica').fillColor('#555555')
          .text(label, xPos + 4, y + 3);
        doc.fontSize(10).font('Helvetica-Bold').fillColor('#000000')
          .text(valor || '—', xPos + 4, y + 11, { width: largura - 8, lineBreak: false });
      }

      const metade = CW / 2;
      campoInfo('TEMA', sessao.tema, M, CW);
      y += 24;
      campoInfo('DATA', formatarDataBR(sessao.criado_em, false), M, metade - 4);
      campoInfo('DURAÇÃO', `${sessao.duracao_minutos} minutos`, M + metade + 4, metade - 4);
      y += 24;
      campoInfo('LOCAL', sessao.local_dds || 'BBNet Up Provedor', M, CW);
      y += 28;

      // ── TABELA DE PARTICIPANTES ─────────────────────────────────
      doc.rect(M, y, CW, 16).fill(AMARELO).stroke(CB);
      doc.fontSize(9).font('Helvetica-Bold').fillColor('#000000')
        .text('PARTICIPANTES', M, y + 4, { width: CW, align: 'center' });
      y += 18;

      const colNome = { x: M,              w: CW * 0.4  };
      const colHora = { x: M + CW * 0.4,   w: CW * 0.15 };
      const colSig  = { x: M + CW * 0.55,  w: CW * 0.45 };

      // Header
      [colNome, colHora, colSig].forEach(c => {
        doc.rect(c.x, y, c.w, 16).fill('#D9D9D9').stroke(CB);
      });
      doc.fontSize(8.5).font('Helvetica-Bold').fillColor('#000000');
      doc.text('NOME',       colNome.x + 4, y + 4, { width: colNome.w });
      doc.text('HORÁRIO',    colHora.x + 2, y + 4, { width: colHora.w, align: 'center' });
      doc.text('ASSINATURA', colSig.x  + 4, y + 4, { width: colSig.w,  align: 'center' });
      y += 18;

      let zebra = false;
      for (const p of participantes) {
        if (y > 760) { doc.addPage(); y = M; }

        const rH = 32;
        const bg = zebra ? '#FFFFFF' : '#F5F5F5';
        zebra = !zebra;

        [colNome, colHora, colSig].forEach(c => {
          doc.rect(c.x, y, c.w, rH).fill(bg).stroke(CB);
        });

        doc.fontSize(9).font('Helvetica').fillColor('#000000')
          .text(p.nome || '', colNome.x + 4, y + (rH - 9) / 2, { width: colNome.w - 8 });

        const hora = p.assinado_em ? (() => {
          const d = new Date(p.assinado_em);
          const brt = new Date(d.getTime() - 3 * 60 * 60 * 1000);
          return `${String(brt.getUTCHours()).padStart(2,'0')}:${String(brt.getUTCMinutes()).padStart(2,'0')}`;
        })() : '--';
        doc.text(hora, colHora.x + 2, y + (rH - 9) / 2, { width: colHora.w, align: 'center' });

        // Assinatura centralizada na célula
        const imgBase64 = p.foto_base64 || p.assinatura_base64;
        if (imgBase64) {
          try {
            const sigClean = imgBase64.replace(/^data:image\/\w+;base64,/, '');
            const sigBuf = Buffer.from(sigClean, 'base64');
            imagemCentralizada(doc, sigBuf, colSig.x, y, colSig.w, rH);
          } catch (_) {}
        }

        y += rH;
      }

      if (participantes.length === 0) {
        doc.rect(M, y, CW, 28).fill('#F5F5F5').stroke(CB);
        doc.fontSize(10).font('Helvetica').fillColor('#999999')
          .text('Nenhum participante registrado', M, y + 9, { width: CW, align: 'center' });
        y += 30;
      }

      // ── RODAPÉ RESPONSÁVEL ──────────────────────────────────────
      y += 20;
      if (y > 720) { doc.addPage(); y = M; }

      const footerX = M + CW * 0.5;
      const footerW = CW * 0.45;

      if (config.responsavel_assinatura) {
        try {
          const sigClean = config.responsavel_assinatura.replace(/^data:image\/\w+;base64,/, '');
          const sigBuf = Buffer.from(sigClean, 'base64');
          imagemCentralizada(doc, sigBuf, footerX, y, footerW, 36);
        } catch (_) {}
      }

      doc.moveTo(footerX, y + 38).lineTo(footerX + footerW, y + 38)
        .strokeColor('#000000').lineWidth(0.8).stroke();
      doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
        .text(config.responsavel_nome    || '', footerX, y + 40, { width: footerW, align: 'center' });
      doc.fontSize(7).font('Helvetica')
        .text(config.responsavel_cargo   || '', footerX, y + 50, { width: footerW, align: 'center' });
      doc.text(config.responsavel_registro1 || '', footerX, y + 59, { width: footerW, align: 'center' });
      doc.text(config.responsavel_registro2 || '', footerX, y + 68, { width: footerW, align: 'center' });

      doc.end();
    } catch (err) { reject(err); }
  });
}

module.exports = router;