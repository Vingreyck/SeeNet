// src/routes/requisicoes_epi.js
const express = require('express');
const router = express.Router();
const { db } = require('../config/database');
const authMiddleware = require('../middleware/auth');
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
    const fotoBuffer = base64ToBuffer(requisicao.foto_recebimento_base64);
    const sigBuffer = base64ToBuffer(requisicao.assinatura_recebimento_base64);
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
  'Carneira',
  'Jugular',
  'Balaclava',
  'Óculos de Segurança',
  'Luva de Segurança (Isolante)',
  'Luva de Vaqueta',
  'Bota de Segurança',
  'Cinto de Segurança',
  'Talabarte de Posicionamento',
  'Protetor Solar',
  'Escada de Alumínio',
  'Escada Extensível',
  'Fita de Sinalização Zebrada',
  'Cone de Sinalização',
  'Bandeirola',
  'Detector de Tensão',
  'Calça Operacional',
  'Camisa Manga Longa',
  'Catraca Trava Escada',
  'Jaleco Operacional',
  'Avental',
  'Luva Latex',
];

// ================================================================
// GERAÇÃO DE PDF — FICHA DE EPI (formato BW Telecom)
// ================================================================
async function gerarFichaEPI(tecnico, requisicoes, produtosEpi, tenant) {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 30,
        info: {
          Title: `Ficha de EPI - ${tecnico.nome} - BBnet Up`,
          Author: 'SeeNet - BBnet Up',
          Subject: 'Ficha de Controle de Equipamentos de Proteção Individual',
        },
      });

      const chunks = [];
      doc.on('data', (chunk) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = 595.28;
      const M = 30;
      const CW = W - M * 2; // largura útil
      const VERDE = '#007A4A';
      const CINZA_BORDA = '#999999';

      // ── CABEÇALHO ─────────────────────────────────────────────
      // Logo tentativa
      let logoBuffer = null;
      try {
        const https = require('https');
        logoBuffer = await new Promise((res, rej) => {
          https.get('https://static.wixstatic.com/media/40655f_6e4972b166904af6957a3208c1ab4fa4~mv2.png', (response) => {
            const chunks = [];
            response.on('data', (c) => chunks.push(c));
            response.on('end', () => res(Buffer.concat(chunks)));
            response.on('error', rej);
          }).on('error', rej);
        });
      } catch (_) {}

      let y = M;

      // Borda do cabeçalho
      doc.rect(M, y, CW, 60).stroke(CINZA_BORDA);

      if (logoBuffer) {
        try { doc.image(logoBuffer, M + 8, y + 8, { height: 44 }); } catch (_) {}
      }

      doc.fontSize(14).font('Helvetica-Bold').fillColor('#000000')
        .text('FICHA DE CONTROLE DE EQUIPAMENTOS', M + 120, y + 12, { width: CW - 130, align: 'center' });
      doc.fontSize(12).font('Helvetica-Bold')
        .text('DE PROTEÇÃO INDIVIDUAL – EPI', M + 120, y + 30, { width: CW - 130, align: 'center' });

      y += 64;

      // ── DADOS DO COLABORADOR ──────────────────────────────────
      const dataRevisao = formatarDataBR(new Date(), false);

      // Linha 1: Nome + Data Revisão
      doc.rect(M, y, CW * 0.6, 22).stroke(CINZA_BORDA);
      doc.rect(M + CW * 0.6, y, CW * 0.4, 22).stroke(CINZA_BORDA);
      doc.fontSize(8).font('Helvetica-Bold').fillColor('#000000')
        .text(`NOME: ${tecnico.nome?.toUpperCase() || ''}`, M + 4, y + 7);
      doc.text(`DATA DE REVISÃO: ${dataRevisao}`, M + CW * 0.6 + 4, y + 7);
      y += 22;

      // Linha 2: Função + CBO
      doc.rect(M, y, CW * 0.6, 22).stroke(CINZA_BORDA);
      doc.rect(M + CW * 0.6, y, CW * 0.4, 22).stroke(CINZA_BORDA);
      doc.fontSize(8).font('Helvetica-Bold')
        .text('FUNÇÃO: TÉCNICO DE REDE', M + 4, y + 7);
      doc.text('CBO: 313305', M + CW * 0.6 + 4, y + 7);
      y += 22;

      // Linha 3: Empresa + Data Admissão
      doc.rect(M, y, CW * 0.6, 22).stroke(CINZA_BORDA);
      doc.rect(M + CW * 0.6, y, CW * 0.4, 22).stroke(CINZA_BORDA);
      doc.fontSize(8).font('Helvetica-Bold')
        .text('EMPRESA: BBNET UP PROVEDOR LTDA', M + 4, y + 7);
      doc.text(`DATA ADMISSÃO: ${tecnico.data_criacao ? formatarDataBR(tecnico.data_criacao, false) : '---'}`, M + CW * 0.6 + 4, y + 7);
      y += 26;

      // ── DECLARAÇÃO LEGAL ──────────────────────────────────────
      const declaracao = `Reconheço ter sido orientado sobre os riscos à saúde dos eventuais agentes agressivos do meu trabalho e ter sido orientado adequadamente sobre as proteções que devem ser tomadas. Reconheço, também, estar recebendo todos os equipamentos de proteção individual necessários à minha função e ter sido treinado e orientado quanto a sua correta e obrigatória utilização. Declaro ainda:\n►Ter recebido treinamento sobre a utilização adequada destes EPIs, seu prazo de validade, bem como dos riscos que estou sujeito pelo seu não uso;\n►Indenizar a empresa, autorizando o desconto do custo da reparação do dano que eventualmente vier a provocar nos EPIs em questão, por atos de negligência ou mau uso, extravio ou na sua não devolução quando a mim solicitado, já que atesto tê-lo recebido em perfeitas condições (ciente e colocando minha anuência às disposições do Art. 462 da CLT);\n► Estar ciente da disposição legal constante na Norma Regulamentadora NR 01, sub-item 1.8.1 e item 1.9, de que constitui ato faltoso a recusa injustificada de usar os EPIs fornecidos pelo empregador, incorrendo nas penalidades previstas na legislação pertinente;\n► Que na não observância do seu uso, por negligência, os danos e/ou lesões resultantes de acidentes serão de minha inteira responsabilidade.`;

      doc.fontSize(7).font('Helvetica').fillColor('#000000')
        .text(declaracao, M, y, { width: CW, lineGap: 1 });

      y = doc.y + 10;

      // Linha de assinatura
      doc.fontSize(8).font('Helvetica')
        .text('__________________________________', M + 80, y);
      y += 12;
      doc.text('ASSINATURA DO EMPREGADO', M + 100, y);
      doc.text(`LOCAL: ITABAIANA/SE`, M + CW * 0.6, y);
      y += 20;

      // ── TABELA DE EPIs ────────────────────────────────────────
      // Cabeçalho da tabela
      const colWidths = {
        quat: 45,
        descricao: 150,
        fabricante: 105,
        ca: 50,
        data: 60,
        assinatura: CW - 45 - 150 - 105 - 50 - 60
      };

      function desenharCabecalhoTabela(yPos) {
        // Título "ESPECIFICAÇÃO DO EPI" + "RETIRADA"
        doc.rect(M, yPos, colWidths.quat + colWidths.descricao + colWidths.fabricante + colWidths.ca, 14)
          .fill('#E8E8E8').stroke(CINZA_BORDA);
        doc.fontSize(7).font('Helvetica-Bold').fillColor('#000000')
          .text('ESPECIFICAÇÃO DO EPI', M + 4, yPos + 4);

        doc.rect(M + colWidths.quat + colWidths.descricao + colWidths.fabricante + colWidths.ca, yPos,
          colWidths.data + colWidths.assinatura, 14)
          .fill('#E8E8E8').stroke(CINZA_BORDA);
        doc.text('RETIRADA', M + colWidths.quat + colWidths.descricao + colWidths.fabricante + colWidths.ca + 4, yPos + 4);

        yPos += 14;

        // Sub-cabeçalho
        let x = M;
        const headers = [
          { label: 'QUAT', w: colWidths.quat },
          { label: 'DESCRIÇÃO DO EPI', w: colWidths.descricao },
          { label: 'FABRICANTE', w: colWidths.fabricante },
          { label: 'CA', w: colWidths.ca },
          { label: 'DATA', w: colWidths.data },
          { label: 'ASSINATURA', w: colWidths.assinatura },
        ];

        headers.forEach(h => {
          doc.rect(x, yPos, h.w, 14).fill('#F0F0F0').stroke(CINZA_BORDA);
          doc.fontSize(6).font('Helvetica-Bold').fillColor('#000000')
            .text(h.label, x + 2, yPos + 4, { width: h.w - 4 });
          x += h.w;
        });

        return yPos + 14;
      }

      y = desenharCabecalhoTabela(y);

      // Mapa de produtos EPI para buscar CA/fornecedor
      const produtoMap = {};
      produtosEpi.forEach(p => {
        produtoMap[p.nome] = p;
      });

      // Desenhar linhas dos EPIs de cada requisição
      const reqsAprovadas = requisicoes
        .filter(r => ['concluida', 'aprovada', 'aguardando_confirmacao'].includes(r.status))
        .sort((a, b) => new Date(a.data_resposta || a.data_criacao) - new Date(b.data_resposta || b.data_criacao));

      for (const req of reqsAprovadas) {
        const epis = Array.isArray(req.epis_solicitados)
          ? req.epis_solicitados
          : JSON.parse(req.epis_solicitados || '[]');

        const dataEntrega = req.data_entrega || req.data_resposta || req.data_criacao;
        const dataStr = dataEntrega ? formatarDataBR(new Date(dataEntrega), false) : '---';

        for (const epiNome of epis) {
          // Nova página se necessário
          if (y > 740) {
            doc.addPage();
            y = M;
            y = desenharCabecalhoTabela(y);
          }

          // Extrair quantidade e nome limpo
          const qtdMatch = epiNome.match(/x(\d+)$/);
          const quantidade = qtdMatch ? parseInt(qtdMatch[1]) : 1;
          const nomeLimpo = epiNome
            .replace(/\s*\(Tam\.\s*\w+\)/, '')
            .replace(/\s*x\d+$/, '')
            .trim();

          // Buscar CA e fornecedor do produto
          const prodInfo = produtoMap[nomeLimpo] || {};
          const ca = prodInfo.ca || '........';
          const fornecedor = prodInfo.fornecedor || '';

          // Extrair tamanho
          const tamMatch = epiNome.match(/\(Tam\.\s*(\w+)\)/);
          let descricaoFinal = nomeLimpo;
          if (tamMatch) descricaoFinal += ` - ${tamMatch[1]}`;

          // Desenhar linha
          let x = M;
          const rowH = 16;

          // QUAT
          doc.rect(x, y, colWidths.quat, rowH).stroke(CINZA_BORDA);
          doc.fontSize(7).font('Helvetica').fillColor('#000000')
            .text(`${quantidade} UNI`, x + 2, y + 5, { width: colWidths.quat - 4 });
          x += colWidths.quat;

          // DESCRIÇÃO
          doc.rect(x, y, colWidths.descricao, rowH).stroke(CINZA_BORDA);
          doc.fontSize(7).font('Helvetica')
            .text(descricaoFinal, x + 2, y + 5, { width: colWidths.descricao - 4 });
          x += colWidths.descricao;

          // FABRICANTE
          doc.rect(x, y, colWidths.fabricante, rowH).stroke(CINZA_BORDA);
          doc.fontSize(6).font('Helvetica')
            .text(fornecedor.toUpperCase(), x + 2, y + 5, { width: colWidths.fabricante - 4 });
          x += colWidths.fabricante;

          // CA
          doc.rect(x, y, colWidths.ca, rowH).stroke(CINZA_BORDA);
          doc.fontSize(7).font('Helvetica')
            .text(ca, x + 2, y + 5, { width: colWidths.ca - 4 });
          x += colWidths.ca;

          // DATA
          doc.rect(x, y, colWidths.data, rowH).stroke(CINZA_BORDA);
          doc.fontSize(6).font('Helvetica')
            .text(dataStr, x + 2, y + 5, { width: colWidths.data - 4 });
          x += colWidths.data;

          // ASSINATURA (foto da assinatura se disponível)
          doc.rect(x, y, colWidths.assinatura, rowH).stroke(CINZA_BORDA);
          if (req.assinatura_recebimento_base64) {
            try {
              const sigClean = req.assinatura_recebimento_base64.replace(/^data:image\/\w+;base64,/, '');
              const sigBuf = Buffer.from(sigClean, 'base64');
              doc.image(sigBuf, x + 2, y + 1, { height: rowH - 2, fit: [colWidths.assinatura - 4, rowH - 2] });
            } catch (_) {}
          }

          y += rowH;
        }
      }

      // ── OBS NR-01 ─────────────────────────────────────────────
      if (y > 740) { doc.addPage(); y = M; }
      y += 10;
      doc.fontSize(7).font('Helvetica-Bold').fillColor('#000000')
        .text('OBS: ', M, y, { continued: true });
      doc.font('Helvetica')
        .text('Conforme determina a NR 01, a substituição do Equipamento de Proteção Individual (EPI) deve ser feita de acordo com o prazo de validade do fabricante e o estado do equipamento.', { width: CW });

      // ── RODAPÉ ────────────────────────────────────────────────
      const footerY = 841.89 - 40;
      doc.fontSize(7).font('Helvetica').fillColor('#555555')
        .text('BBNET UP PROVEDOR LTDA - CNPJ: 23.870.928/0002-03', M, footerY, { width: CW, align: 'center' });
      doc.text('RUA DOUTOR AUGUSTO CEZAR LEITE, 428 – ITABAIANA/SE', M, footerY + 10, { width: CW, align: 'center' });

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

// ================================================================
// ROTAS
// ================================================================

// GET /api/seguranca/epis — lista de EPIs para o técnico solicitar (agora do banco)
router.get('/epis', authMiddleware, async (req, res) => {
  try {
    const produtos = await db('produtos_epi')
      .where('tenant_id', req.user.tenant_id)
      .where('ativo', true)
      .orderBy('nome', 'asc');

    if (produtos.length > 0) {
      return res.json({ epis: produtos.map(p => p.nome) });
    }

    // Fallback se não tiver produtos cadastrados
    res.json({ epis: EPIS_PADRAO });
  } catch (err) {
    res.json({ epis: EPIS_PADRAO });
  }
});

// POST /api/seguranca/requisicoes — técnico cria
router.post('/requisicoes', authMiddleware, async (req, res) => {
  try {
    const { epis_solicitados } = req.body;
    if (!epis_solicitados?.length) return res.status(400).json({ error: 'Selecione ao menos um EPI' });

    const [{ id }] = await db('requisicoes_epi').insert({
      tenant_id: req.user.tenant_id,
      tecnico_id: req.user.id,
      status: 'pendente',
      epis_solicitados: JSON.stringify(epis_solicitados),
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
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (!requisicao) return res.status(404).json({ error: 'Não encontrada' });
    if (requisicao.status !== 'pendente')
      return res.status(400).json({ error: `Requisição já está com status: ${requisicao.status}` });

    const { observacao, data_entrega, itens_ixc = [] } = req.body;

    // ── Integração IXC (desconto de estoque) ─────────────────────
    let id_requisicao_ixc = null;
    let itens_ixc_resultado = [];

    if (itens_ixc.length > 0) {
      try {
        const integracao = await db('integracao_ixc')
          .where('tenant_id', req.user.tenant_id)
          .where('ativo', true)
          .first();

        if (integracao) {
          const IXCService = require('../services/IXCService');
          const ixc = new IXCService(integracao.url_api, integracao.token_api);

          const mapeamento = await db('mapeamento_tecnicos_ixc')
            .where('usuario_id', requisicao.tecnico_id)
            .where('tenant_id', req.user.tenant_id)
            .first();

          if (!mapeamento) {
            return res.status(400).json({
              error: 'Técnico sem almoxarifado mapeado no IXC. Configure em Mapeamento de Técnicos.'
            });
          }

          // 1️⃣ Cria a requisição de material no IXC
          const { id: reqIxcId } = await ixc.criarRequisicaoMaterial({
            id_filial:       integracao.id_filial || '1',
            id_almoxarifado: mapeamento.id_almoxarifado.toString(),
            id_colaborador:  mapeamento.tecnico_ixc_id.toString(),
            observacao:      `Req. EPI #${requisicao.id} - SeeNet`,
          });
          id_requisicao_ixc = reqIxcId;

          // 2️⃣ Adiciona cada item — IXC desconta do estoque automaticamente
          // Confirmação: campo qtde_saldo na resposta mostra saldo restante
          for (const item of itens_ixc) {
            try {
              const resultado = await ixc.adicionarItemRequisicaoMaterial(reqIxcId, {
                id_produto: item.id_produto,
                quantidade: item.quantidade || 1,
              });
              itens_ixc_resultado.push({
                id_produto:  item.id_produto,
                descricao:   item.descricao || '',
                quantidade:  item.quantidade || 1,
                id_item_ixc: resultado.id,
                qtde_saldo:  resultado.qtde_saldo, // saldo após desconto
              });
            } catch (itemErr) {
              console.error(`⚠️ Falha no item ${item.id_produto}:`, itemErr.message);
              itens_ixc_resultado.push({
                id_produto: item.id_produto,
                descricao:  item.descricao || '',
                quantidade: item.quantidade || 1,
                erro:        itemErr.message,
              });
            }
          }
        }
      } catch (ixcErr) {
        console.error('⚠️ Erro IXC (aprovação continua sem desconto):', ixcErr.message);
      }
    }

    // ── Atualizar banco ───────────────────────────────────────────
    await db('requisicoes_epi').where('id', req.params.id).update({
      status:            'aguardando_confirmacao',
      gestor_id:         req.user.id,
      observacao_gestor: observacao || null,
      data_resposta:     new Date(),
      data_entrega:      data_entrega ? new Date(data_entrega) : new Date(),
      id_requisicao_ixc,
      itens_ixc: itens_ixc_resultado.length > 0
        ? JSON.stringify(itens_ixc_resultado)
        : null,
    });

    // ── PDF (ainda sem foto/assinatura — será regerado na confirmação) ─
    const updated = await db('requisicoes_epi').where('id', req.params.id).first();
    const tecnico = await db('usuarios').where('id', updated.tecnico_id).first();
    const gestor  = await db('usuarios').where('id', req.user.id).first();
    try {
      const pdfBuffer = await gerarPDF(updated, tecnico, gestor);
      await db('requisicoes_epi').where('id', req.params.id).update({
        pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}`,
      });
    } catch (e) { console.error('⚠️ PDF falhou:', e.message); }

    const itens_com_erro = itens_ixc_resultado.filter(i => i.erro);
    res.json({
      success: true,
      message: 'Requisição aprovada! Aguardando confirmação do técnico.',
      id_requisicao_ixc,
      itens_descontados: itens_ixc_resultado.filter(i => !i.erro).length,
      ...(itens_com_erro.length > 0 && { itens_com_erro }),
    });

  } catch (err) {
    console.error('❌ Erro ao aprovar:', err);
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

// ================================================================
// ADICIONAR NOVA ROTA: histórico de requisições concluídas
// GET /api/seguranca/requisicoes/historico
// Retorna todas as requisições concluídas com foto e assinatura
// ================================================================
router.get('/requisicoes/historico', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    let query = db('requisicoes_epi as r')
      .join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tenant_id', req.user.tenant_id)
      .whereIn('r.status', ['concluida', 'aprovada', 'aguardando_confirmacao'])
      .select(
        'r.id', 'r.status', 'r.epis_solicitados', 'r.itens_ixc',
        'r.id_requisicao_ixc', 'r.data_criacao', 'r.data_resposta',
        'r.data_entrega', 'r.data_confirmacao_recebimento',
        'r.assinatura_recebimento_base64', 'r.foto_recebimento_base64',
        'r.observacao_gestor', 'r.registro_manual', 'r.pdf_base64',
        't.nome as tecnico_nome', 't.email as tecnico_email',
        't.foto_perfil as tecnico_foto',
        'g.nome as gestor_nome'
      )
      .orderBy('r.data_confirmacao_recebimento', 'desc');

    if (req.query.tecnico_id) query = query.where('r.tecnico_id', req.query.tecnico_id);

    const lista = await query;
    res.json({ requisicoes: lista });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erro ao buscar histórico' });
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

// POST /api/seguranca/requisicoes/:id/confirmar-recebimento
router.post('/requisicoes/:id/confirmar-recebimento', authMiddleware, async (req, res) => {
  try {
    const { assinatura_base64, foto_base64 } = req.body;

    if (!assinatura_base64) return res.status(400).json({ error: 'Assinatura obrigatória' });
    if (!foto_base64) return res.status(400).json({ error: 'Foto obrigatória' });

    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (!requisicao) return res.status(404).json({ error: 'Não encontrada' });

    // Só o próprio técnico pode confirmar
    if (requisicao.tecnico_id !== req.user.id) {
      return res.status(403).json({ error: 'Sem permissão' });
    }

    if (requisicao.status !== 'aguardando_confirmacao') {
      return res.status(400).json({ error: 'Requisição não está aguardando confirmação' });
    }

    await db('requisicoes_epi').where('id', req.params.id).update({
      status: 'concluida',
      assinatura_recebimento_base64: assinatura_base64,
      foto_recebimento_base64: foto_base64,
      data_confirmacao_recebimento: new Date(),
    });

    const updated = await db('requisicoes_epi').where('id', req.params.id).first();
    const tecnico = await db('usuarios').where('id', req.user.id).first();
    const gestor = updated.gestor_id
      ? await db('usuarios').where('id', updated.gestor_id).first()
      : null;

    // Gera PDF agora com todos os dados
    try {
      const pdfBuffer = await gerarPDF(updated, tecnico, gestor);
      await db('requisicoes_epi').where('id', req.params.id).update({
        pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}`,
      });
    } catch (e) {
      console.error('Erro ao gerar PDF na confirmação:', e);
    }

    res.json({ success: true, message: 'Recebimento confirmado! PDF gerado.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erro ao confirmar recebimento' });
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

// GET /api/seguranca/tecnicos/:id/perfil — gestor vê perfil de um técnico
router.get('/tecnicos/:id/perfil', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const tecnicoId = req.params.id;

    const usuario = await db('usuarios')
      .where('id', tecnicoId)
      .where('tenant_id', req.user.tenant_id)
      .select('id', 'nome', 'email', 'tipo_usuario', 'foto_perfil', 'data_criacao', 'ultimo_login')
      .first();

    if (!usuario) return res.status(404).json({ error: 'Técnico não encontrado' });

    const tenant = await db('tenants').where('id', req.user.tenant_id).first();

    const stats = await db('requisicoes_epi')
      .where('tecnico_id', tecnicoId)
      .where('tenant_id', req.user.tenant_id)
      .select(
        db.raw('COUNT(*) as total'),
        db.raw("COUNT(*) FILTER (WHERE status = 'concluida') as concluidas"),
        db.raw("COUNT(*) FILTER (WHERE status = 'aprovada' OR status = 'aguardando_confirmacao') as aprovadas"),
        db.raw("COUNT(*) FILTER (WHERE status = 'pendente') as pendentes"),
        db.raw("COUNT(*) FILTER (WHERE status = 'recusada') as recusadas")
      )
      .first();

    const requisicoes = await db('requisicoes_epi as r')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tecnico_id', tecnicoId)
      .where('r.tenant_id', req.user.tenant_id)
      .select(
        'r.id', 'r.status', 'r.epis_solicitados', 'r.itens_ixc',
        'r.id_requisicao_ixc', 'r.data_criacao', 'r.data_resposta',
        'r.data_entrega', 'r.data_confirmacao_recebimento',
        'r.observacao_gestor', 'r.registro_manual', 'r.pdf_base64',
        'r.assinatura_recebimento_base64', 'r.foto_recebimento_base64',
        'g.nome as gestor_nome'
      )
      .orderBy('r.data_criacao', 'desc');

    res.json({
      usuario: { ...usuario, empresa: tenant?.nome },
      stats,
      requisicoes,
    });
  } catch (err) {
    console.error('❌ Erro ao buscar perfil do técnico:', err);
    res.status(500).json({ error: 'Erro ao buscar perfil do técnico' });
  }
});

// GET /api/seguranca/almoxarifados-colaboradores — lista almoxarifados de colaboradores
router.get('/almoxarifados-colaboradores', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const integracao = await db('integracao_ixc')
      .where('tenant_id', req.user.tenant_id)
      .where('ativo', true)
      .first();

    if (!integracao) return res.json({ almoxarifados: [] });

    const IXCService = require('../services/IXCService');
    const ixc = new IXCService(integracao.url_api, integracao.token_api);

    const IDS_COLABORADORES = [25,26,27,28,29,30,31,32,33,35,36,37,38,39,40,41,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,76,97,102,107,116];

    const body = {
      qtype: 'almox.id',
      query: '1',
      oper: '>=',
      page: '1',
      rp: '200',
      sortname: 'almox.descricao',
      sortorder: 'asc'
    };

    const response = await ixc.clientAlterar.post('/almox', body, {
      headers: { 'ixcsoft': 'listar' }
    });

    const todos = response.data.registros || [];
    const filtrados = todos
      .filter(a => IDS_COLABORADORES.includes(parseInt(a.id)) && a.ativo === 'S')
      .map(a => ({ id: a.id, descricao: a.descricao }));

    res.json({ almoxarifados: filtrados });
  } catch (err) {
    console.error('❌ Erro ao buscar almoxarifados:', err.message);
    res.status(500).json({ error: 'Erro ao buscar almoxarifados' });
  }
});

// GET /api/seguranca/produtos-epi — lista produtos de EPI do IXC
router.get('/produtos-epi', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    // Mapeamento fixo: EPI SeeNet → ID produto IXC
    const MAPEAMENTO_EPI = [
          { epi: 'Capacete de Segurança (Classe B)', id_produto: '397', descricao_ixc: 'CAPACETE DE ABA REDONDA', tamanhos: null },
          { epi: 'Carneira', id_produto: '398', descricao_ixc: 'CARNEIRA COM CATRACA', tamanhos: null },
          { epi: 'Jugular', id_produto: '417', descricao_ixc: 'JUGULAR DE ELÁSTICO PARA CAPACETE', tamanhos: null },
          { epi: 'Balaclava', id_produto: '388', descricao_ixc: 'TOUCA BALACLAVA', tamanhos: null },
          { epi: 'Óculos de Segurança', id_produto: '421', descricao_ixc: 'ÓCULOS DE PROTEÇÃO', tamanhos: null },
          { epi: 'Luva de Segurança (Isolante)', id_produto: '419', descricao_ixc: 'LUVA NBR', tamanhos: null },
          { epi: 'Luva de Vaqueta', id_produto: '418', descricao_ixc: 'LUVA DE COURO VAQUETA', tamanhos: null },
          { epi: 'Bota de Segurança', id_produto: '390', descricao_ixc: 'BOTA OPERACIONAL', tamanhos: ['39','40','41'] },
          { epi: 'Cinto de Segurança', id_produto: '400', descricao_ixc: 'CINTO DE SEGURANÇA PQD', tamanhos: null },
          { epi: 'Talabarte de Posicionamento', id_produto: '429', descricao_ixc: 'TALABARTE DE POSICIONAMENTO', tamanhos: null },
          { epi: 'Protetor Solar', id_produto: '423', descricao_ixc: 'PROTETOR SOLAR FPS60 FPUVA20', tamanhos: null },
          { epi: 'Escada de Alumínio', id_produto: '494', descricao_ixc: 'ESCADA ALUMÍNIO', tamanhos: null },
          { epi: 'Escada Extensível', id_produto: '485', descricao_ixc: 'ESCADA EXTENSÍVEL FIBRA VAZADA', tamanhos: null },
          { epi: 'Fita de Sinalização Zebrada', id_produto: '411', descricao_ixc: 'FITA DE SINALIZAÇÃO ZEBRADA', tamanhos: null },
          { epi: 'Cone de Sinalização', id_produto: '484', descricao_ixc: 'CONE DE SINALIZAÇÃO', tamanhos: null },
          { epi: 'Bandeirola', id_produto: '556', descricao_ixc: 'BANDEIROLA P/ SINALIZAÇÃO', tamanhos: null },
          { epi: 'Detector de Tensão', id_produto: '637', descricao_ixc: 'DETECTOR TENSÃO', tamanhos: null },
          { epi: 'Calça Operacional', id_produto: '395', descricao_ixc: 'CALÇA OPERACIONAL', tamanhos: ['36','38','40','41','42','46','48'] },
          { epi: 'Camisa Manga Longa', id_produto: '538', descricao_ixc: 'CAMISA MANGA LONGA', tamanhos: ['P','M','G','GG'] },
          { epi: 'Catraca Trava Escada', id_produto: '430', descricao_ixc: 'CATRACA TRAVA GANCHO PARA ESCADA EXTENSÍVEL', tamanhos: null },
          { epi: 'Jaleco Operacional', id_produto: '416', descricao_ixc: 'JALECO OPERACIONAL', tamanhos: null },
          { epi: 'Avental', id_produto: '635', descricao_ixc: 'AVENTAL', tamanhos: null },
          { epi: 'Luva Latex', id_produto: '636', descricao_ixc: 'LUVA LATEX', tamanhos: null },
        ];

    res.json({ mapeamento: MAPEAMENTO_EPI });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar produtos EPI' });
  }
});

// GET /api/seguranca/almoxarifados-colaboradores
router.get('/almoxarifados-colaboradores', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const integracao = await db('integracao_ixc')
      .where('tenant_id', req.user.tenant_id)
      .where('ativo', true)
      .first();

    if (!integracao) return res.json({ almoxarifados: [] });

    const IXCService = require('../services/IXCService');
    const ixc = new IXCService(integracao.url_api, integracao.token_api);

    const IDS_COLABORADORES = [25,26,27,28,29,30,31,32,33,35,36,37,38,39,40,41,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,76,97,102,107,116];

    const body = {
      qtype: 'almox.id',
      query: '1',
      oper: '>=',
      page: '1',
      rp: '200',
      sortname: 'almox.descricao',
      sortorder: 'asc'
    };

    const response = await ixc.clientAlterar.post('/almox', body, {
      headers: { 'ixcsoft': 'listar' }
    });

    const todos = response.data.registros || [];
    const filtrados = todos
      .filter(a => IDS_COLABORADORES.includes(parseInt(a.id)) && a.ativo === 'S')
      .map(a => ({ id: a.id, descricao: a.descricao }));

    res.json({ almoxarifados: filtrados });
  } catch (err) {
    console.error('❌ Erro ao buscar almoxarifados:', err.message);
    res.status(500).json({ error: 'Erro ao buscar almoxarifados' });
  }
});

// GET /api/seguranca/produtos-epi — mapeamento EPI → IXC (agora do banco)
router.get('/produtos-epi', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const produtos = await db('produtos_epi')
      .where('tenant_id', req.user.tenant_id)
      .where('ativo', true)
      .orderBy('nome', 'asc');

    const mapeamento = produtos.map(p => ({
      epi: p.nome,
      id_produto: p.id_produto_ixc,
      descricao_ixc: p.descricao_ixc,
      tamanhos: p.tamanhos,
      ca: p.ca,
      fornecedor: p.fornecedor,
    }));

    res.json({ mapeamento });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao buscar produtos EPI' });
  }
});

// ================================================================
// CRUD PRODUTOS EPI (CA, Fornecedor, etc.)
// ================================================================

// GET /api/seguranca/produtos-epi-cadastro — lista todos os produtos EPI do tenant
router.get('/produtos-epi-cadastro', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const produtos = await db('produtos_epi')
      .where('tenant_id', req.user.tenant_id)
      .where('ativo', true)
      .orderBy('nome', 'asc');

    res.json({ produtos });
  } catch (err) {
    console.error('❌ Erro ao buscar produtos EPI:', err);
    res.status(500).json({ error: 'Erro ao buscar produtos' });
  }
});

// PUT /api/seguranca/produtos-epi-cadastro/:id — atualizar CA e fornecedor
router.put('/produtos-epi-cadastro/:id', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const { ca, fornecedor, tamanhos } = req.body;

    const produto = await db('produtos_epi')
      .where('id', req.params.id)
      .where('tenant_id', req.user.tenant_id)
      .first();

    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });

    const updateData = { data_atualizacao: new Date() };
    if (ca !== undefined) updateData.ca = ca;
    if (fornecedor !== undefined) updateData.fornecedor = fornecedor;
    if (tamanhos !== undefined) updateData.tamanhos = JSON.stringify(tamanhos);

    await db('produtos_epi').where('id', req.params.id).update(updateData);

    res.json({ success: true, message: 'Produto atualizado!' });
  } catch (err) {
    console.error('❌ Erro ao atualizar produto EPI:', err);
    res.status(500).json({ error: 'Erro ao atualizar' });
  }
});

// POST /api/seguranca/produtos-epi-cadastro — adicionar novo produto EPI
router.post('/produtos-epi-cadastro', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const { nome, id_produto_ixc, descricao_ixc, ca, fornecedor, tamanhos } = req.body;

    if (!nome) return res.status(400).json({ error: 'Nome obrigatório' });

    const existe = await db('produtos_epi')
      .where('tenant_id', req.user.tenant_id)
      .where('nome', nome)
      .first();

    if (existe) return res.status(400).json({ error: 'Produto já cadastrado' });

    const [inserted] = await db('produtos_epi').insert({
      tenant_id: req.user.tenant_id,
      nome,
      id_produto_ixc: id_produto_ixc || null,
      descricao_ixc: descricao_ixc || null,
      ca: ca || 'N/A',
      fornecedor: fornecedor || '',
      tamanhos: tamanhos ? JSON.stringify(tamanhos) : null,
    }).returning('*');

    res.status(201).json({ success: true, message: 'Produto cadastrado!', produto: inserted });
  } catch (err) {
    console.error('❌ Erro ao cadastrar produto EPI:', err);
    res.status(500).json({ error: 'Erro ao cadastrar' });
  }
});

// DELETE /api/seguranca/produtos-epi-cadastro/:id — desativar produto
router.delete('/produtos-epi-cadastro/:id', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    await db('produtos_epi')
      .where('id', req.params.id)
      .where('tenant_id', req.user.tenant_id)
      .update({ ativo: false, data_atualizacao: new Date() });

    res.json({ success: true, message: 'Produto removido!' });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao remover' });
  }
});

// GET /api/seguranca/tecnicos/:id/ficha-epi — PDF da ficha completa de EPI
router.get('/tecnicos/:id/ficha-epi', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const tecnicoId = req.params.id;

    const tecnico = await db('usuarios')
      .where('id', tecnicoId)
      .where('tenant_id', req.user.tenant_id)
      .first();

    if (!tecnico) return res.status(404).json({ error: 'Técnico não encontrado' });

    const requisicoes = await db('requisicoes_epi')
      .where('tecnico_id', tecnicoId)
      .where('tenant_id', req.user.tenant_id)
      .whereIn('status', ['concluida', 'aprovada', 'aguardando_confirmacao'])
      .orderBy('data_criacao', 'asc');

    const produtosEpi = await db('produtos_epi')
      .where('tenant_id', req.user.tenant_id)
      .where('ativo', true);

    const tenant = await db('tenants').where('id', req.user.tenant_id).first();

    const pdfBuffer = await gerarFichaEPI(tecnico, requisicoes, produtosEpi, tenant);
    const pdfBase64 = `data:application/pdf;base64,${pdfBuffer.toString('base64')}`;

    res.json({ pdf_base64: pdfBase64 });
  } catch (err) {
    console.error('❌ Erro ao gerar ficha EPI:', err);
    res.status(500).json({ error: 'Erro ao gerar ficha de EPI' });
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