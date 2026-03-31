// src/routes/requisicoes_epi.js
const express = require('express');
const router = express.Router();
const { db } = require('../config/database');
const authMiddleware = require('../middleware/auth');
const PDFDocument = require('pdfkit');
const notificationService = require('../services/NotificationService');
const https = require('https');
const http = require('http');

// ================================================================
// HELPERS
// ================================================================

function isGestorOuAdmin(tipo) {
  return tipo === 'administrador' || tipo === 'gestor_seguranca';
}

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

function base64ToBuffer(base64String) {
  if (!base64String) return null;
  const clean = base64String.replace(/^data:image\/\w+;base64,/, '');
  return Buffer.from(clean, 'base64');
}

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
// GERAÇÃO DE PDF — REQUISIÇÃO INDIVIDUAL (formato SeeNet)
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

      const W = 595.28;
      const H = 841.89;
      const MARGIN = 40;
      const VERDE = '#00C878';
      const VERDE_ESCURO = '#007A4A';
      const CINZA = '#F5F5F5';
      const CINZA_BORDA = '#E0E0E0';
      const TEXTO = '#1A1A1A';
      const TEXTO_SEC = '#555555';

      doc.rect(0, 0, W, 90).fill(VERDE_ESCURO);
      doc.rect(0, 0, 8, 90).fill(VERDE);

      let logoBuffer = null;
      try {
        logoBuffer = await downloadImage(
          'https://static.wixstatic.com/media/40655f_6e4972b166904af6957a3208c1ab4fa4~mv2.png'
        );
      } catch (_) {}

      if (logoBuffer) {
        doc.image(logoBuffer, 20, 12, { height: 65, fit: [200, 65] });
      } else {
        doc.fontSize(22).fillColor('#FFFFFF').font('Helvetica-Bold').text('BBnet UP', 20, 28);
        doc.fontSize(10).fillColor('#CCFFDD').text('Provedor de Internet', 20, 56);
      }

      doc.fontSize(18).fillColor('#FFFFFF').font('Helvetica-Bold')
        .text('FICHA DE ENTREGA DE EPI', 0, 22, { align: 'right', width: W - 20 });
      doc.fontSize(10).fillColor('#CCFFDD').font('Helvetica')
        .text(`Equipamentos de Proteção Individual  •  Nº ${String(requisicao.id).padStart(5, '0')}`, 0, 50, { align: 'right', width: W - 20 });
      doc.fontSize(9).fillColor('#AAFFCC')
        .text(`Gerado em ${formatarDataBR(new Date())}`, 0, 70, { align: 'right', width: W - 20 });

      const statusColor = requisicao.status === 'aprovada' ? VERDE : requisicao.status === 'recusada' ? '#FF4444' : '#FF9900';
      const statusLabel = requisicao.status === 'aprovada' ? '✔  APROVADA' : requisicao.status === 'recusada' ? '✖  RECUSADA' : '⏳  PENDENTE';

      doc.rect(0, 90, W, 28).fill(statusColor);
      doc.fontSize(11).fillColor('#FFFFFF').font('Helvetica-Bold').text(statusLabel, 0, 98, { align: 'center', width: W });

      let y = 132;

      function secao(titulo, altura = 24) {
        doc.rect(MARGIN, y, W - MARGIN * 2, altura).fill(VERDE_ESCURO);
        doc.fontSize(10).fillColor('#FFFFFF').font('Helvetica-Bold').text(titulo.toUpperCase(), MARGIN + 10, y + 7);
        y += altura + 8;
      }

      function linha(label, valor, x1 = MARGIN, largura = W - MARGIN * 2) {
        doc.rect(x1, y, largura, 24).fill(CINZA).stroke(CINZA_BORDA);
        doc.fontSize(8.5).fillColor(TEXTO_SEC).font('Helvetica').text(label, x1 + 8, y + 4);
        doc.fontSize(10).fillColor(TEXTO).font('Helvetica-Bold').text(valor || '—', x1 + 8, y + 13);
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

      secao('1. Dados do Colaborador');
      linha('Nome Completo', tecnico.nome);
      linha2col('E-mail', tecnico.email && !tecnico.email.endsWith('@seenet.local') ? tecnico.email : '—', 'Função', tecnico.tipo_usuario === 'tecnico' ? 'Técnico de Campo' : tecnico.tipo_usuario);
      y += 8;

      secao('2. Informações da Requisição');
      const dataRequisicao = requisicao.data_criacao ? formatarDataBR(requisicao.data_criacao) : '—';
      const dataEntrega = requisicao.data_entrega ? formatarDataBR(requisicao.data_entrega, false) : requisicao.data_resposta ? formatarDataBR(requisicao.data_resposta, false) : '—';
      linha2col('Nº da Requisição', `#${String(requisicao.id).padStart(5, '0')}`, 'Status', statusLabel.replace(/[✔✖⏳]\s+/, ''));
      linha2col('Data/Hora da Solicitação', dataRequisicao, 'Data de Entrega', dataEntrega);
      if (gestor) {
        linha2col('Avaliado por', gestor.nome, 'Data da Avaliação', requisicao.data_resposta ? formatarDataBR(requisicao.data_resposta) : '—');
      }
      if (requisicao.registro_manual) {
        doc.rect(MARGIN, y, W - MARGIN * 2, 20).fill('#FFF8E1').stroke('#FFD54F');
        doc.fontSize(9).fillColor('#795500').font('Helvetica').text('⚠  Registro retroativo inserido manualmente pelo gestor de segurança.', MARGIN + 8, y + 5);
        y += 22;
      }
      y += 8;

      secao('3. Equipamentos de Proteção Individual (EPIs)');
      const epis = Array.isArray(requisicao.epis_solicitados) ? requisicao.epis_solicitados : JSON.parse(requisicao.epis_solicitados || '[]');
      const colW2 = (W - MARGIN * 2) / 2 - 4;
      let col = 0;
      let rowY = y;
      epis.forEach((epi, i) => {
        const x = col === 0 ? MARGIN : MARGIN + colW2 + 8;
        doc.rect(x, rowY, colW2, 22).fill(i % 2 === 0 ? CINZA : '#EEFFEE').stroke(CINZA_BORDA);
        doc.rect(x + 6, rowY + 6, 10, 10).fill(VERDE).stroke(VERDE_ESCURO);
        doc.fontSize(8).fillColor('#FFFFFF').font('Helvetica-Bold').text('✓', x + 7, rowY + 7);
        doc.fontSize(9).fillColor(TEXTO).font('Helvetica').text(epi, x + 22, rowY + 6, { width: colW2 - 28 });
        col++;
        if (col === 2) { col = 0; rowY += 24; }
      });
      if (col === 1) rowY += 24;
      y = rowY + 8;

      if (requisicao.observacao_gestor) {
        secao('4. Observações do Gestor');
        doc.rect(MARGIN, y, W - MARGIN * 2, 50).fill(CINZA).stroke(CINZA_BORDA);
        doc.fontSize(10).fillColor(TEXTO).font('Helvetica').text(requisicao.observacao_gestor, MARGIN + 10, y + 8, { width: W - MARGIN * 2 - 20 });
        y += 58;
      }

      const fotoBuffer = base64ToBuffer(requisicao.foto_recebimento_base64);
      const sigBuffer = base64ToBuffer(requisicao.assinatura_recebimento_base64);
      const secNum = requisicao.observacao_gestor ? 5 : 4;
      if (fotoBuffer || sigBuffer) {
        if (y > 560) { doc.addPage(); y = MARGIN; }
        const boxW = (W - MARGIN * 2) / 2 - 8;
        const boxH = 160;
        doc.rect(MARGIN, y, W - MARGIN * 2, 24).fill(VERDE_ESCURO);
        doc.fontSize(10).fillColor('#FFFFFF').font('Helvetica-Bold').text(`${secNum}. EVIDÊNCIA FOTOGRÁFICA E ASSINATURA DIGITAL`, MARGIN + 10, y + 7);
        y += 32;
        if (fotoBuffer) {
          doc.rect(MARGIN, y, boxW, boxH).stroke(CINZA_BORDA);
          doc.fontSize(8.5).fillColor(TEXTO_SEC).font('Helvetica').text('Foto de confirmação (colaborador + EPIs)', MARGIN + 6, y + 4);
          try { doc.image(fotoBuffer, MARGIN + 4, y + 16, { fit: [boxW - 8, boxH - 22], align: 'center', valign: 'center' }); } catch (_) {}
        }
        if (sigBuffer) {
          const sx = MARGIN + boxW + 16;
          doc.rect(sx, y, boxW, boxH).fill('#FAFAFA').stroke(CINZA_BORDA);
          doc.fontSize(8.5).fillColor(TEXTO_SEC).font('Helvetica').text('Assinatura digital do colaborador', sx + 6, y + 4);
          try { doc.image(sigBuffer, sx + 4, y + 16, { fit: [boxW - 8, boxH - 22], align: 'center', valign: 'center' }); } catch (_) {}
        }
        y += boxH + 12;
      }

      if (y > 680) { doc.addPage(); y = MARGIN; }
      doc.rect(MARGIN, y, W - MARGIN * 2, 56).fill('#FFFDE7').stroke('#F9A825');
      doc.fontSize(8.5).fillColor('#4A3700').font('Helvetica')
        .text('DECLARAÇÃO: Declaro que recebi os Equipamentos de Proteção Individual (EPIs) listados neste documento em perfeito estado de conservação, comprometendo-me a utilizá-los sempre que necessário, conforme NR-6 (Norma Regulamentadora nº 6 do Ministério do Trabalho). Estou ciente das responsabilidades quanto ao uso, conservação e devolução dos equipamentos.', MARGIN + 10, y + 8, { width: W - MARGIN * 2 - 20 });
      y += 64;

      const footerY = H - 50;
      doc.rect(0, footerY, W, 50).fill(VERDE_ESCURO);
      doc.rect(0, footerY, 8, 50).fill(VERDE);
      doc.fontSize(8.5).fillColor('#AAFFCC').font('Helvetica').text('BBnet Up Provedor Ltda  •  CNPJ 23.870.928/0002-03  •  Itabaiana - SE', MARGIN, footerY + 8);
      doc.fontSize(8).fillColor('#88DDAA').text(`SeeNet Sistema de Gestão Técnica  •  Documento gerado eletronicamente em ${formatarDataBR(new Date())}  •  Req. #${String(requisicao.id).padStart(5,'0')}`, MARGIN, footerY + 24);

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
  'Capacete de Segurança (Classe B)', 'Carneira', 'Jugular', 'Balaclava',
  'Óculos de Segurança', 'Luva de Segurança (Isolante)', 'Luva de Vaqueta',
  'Bota de Segurança', 'Cinto de Segurança', 'Talabarte de Posicionamento',
  'Protetor Solar', 'Escada de Alumínio', 'Escada Extensível',
  'Fita de Sinalização Zebrada', 'Cone de Sinalização', 'Bandeirola',
  'Detector de Tensão', 'Calça Operacional', 'Camisa Manga Longa(Jaleco)',
  'Catraca Trava Escada', 'Avental', 'Luva Latex',
];

// ================================================================
// LOGOS BW TELECOM (base64)
// ================================================================
const LOGO_CRUZ_BASE64 = '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAA0JCgsKCA0LCwsPDg0QFCEVFBISFCgdHhghMCoyMS8qLi00O0tANDhHOS0uQllCR05QVFVUMz9dY1xSYktTVFH/2wBDAQ4PDxQRFCcVFSdRNi42UVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVFRUVH/wAARCAAmACcDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD0TUb+3020a5uX2oOAB1Y+g965PUtWv5LmP7XerZ2pk2lLYncCrAOpbGdwDZ4+U44zRrGo+bqd3dMElgtd1t5OSHXoC46gZbjJGCOCOa6HRdISxhSWceZd7QNzEt5Q7ImScKM4681GsnocUpSrScYuyRyxjnkeCRtO1aG4Ur5tzGsjSONvzYyeOf0+mDYsNZvoYpbiC6N3AJgq20xzIVZjtAbqX+U8c8c1ag1nUH8ZGwa4zbeay7Ni9ApI5xmtXW9GjvYXuLeNUvlVtjgD58rja3qCOOen0yDKXVGcINpypvb5f1+poWV5FfW4mh3AdGVhhkPoR2NFcRo+r2emXNtOJJgs8bLco7+YFC8Jtxz2xg9B+Boq1JdTop4mEo+80mZkbGDxOjXUi7kvAZXPTIfk/wA66LXbHxHNq88lg9wLY7dgS4Cj7ozxuHfNGuRPpl/KTGXsrzcVAYoFlZdrAtnAyOcsCPTHJrQ0TXopbJRdvsVHMSXDHKSbR1LHocY+9jPb0EJdGcsKcU3Tm7a3OKjt9TOsmBGk/tDcRkS4bOOfmz6e9dLoVj4jh1eCS/e4NsN28PcBh90443Hvip4tEnj8SHWmuLb7JuaXO852lTz0x39al1zxFB5D2unzq0r4jNwCfLiyCR8w7nBx6cnPFCVtWFOlGneU21Z6eZxGpPHJqd28JBiaZyhHTG44orrNGsLa/vNiRLJZWvDbz5iFwCuF4AwfvEjOflPHQFJQb1Mo4OVT3kzqbm3hu7d7e4jEkTjDKe9clf6Rc6Chvbe4Wa0hUJskJWRQzjIUgdT03cHBPtRRVyWlzvxMVyOXVGJHqtmsYWTSoZWAIJOFySQSeFHcHHoCRyK3dI0ifVIUuvPFpYszNHFCcyL85ONxHADYOBxwDjPNFFZx1ep5+GftJ8sjq7a3htLdLe3jEcSDCqO1FFFbnspW0R//2Q==';
const LOGO_BW_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAACkAAAApCAIAAAAnApehAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAC8klEQVR4nGNgGAWjYBSMglEwYgAbL7uMqRwcCSoK08VaRoawNYlFTxvQUP69WrMsG9pabZhgVvQEZJnP9FApU1kg8p0WCrG+8Em9hLQEEEBUsrOzS4IBMzMzRISHh2fp0qVaWlpk2u01KQhik2mmNUSEQ4ATavfj+us3rn/9+hUiPnfu3P9gYGpqChGBcI2Njcm0O/FgLsQmrSA9iIi6rw5EJHpz6rNnz75//87IyAgU//v3L8SyiIgIILetrQ3I/v37NzwYSASMDMCAhdjkXOthm+9kX+qWdaUMHOB1SWUpQNN//vwJNJ2FheU/DBQVFQG1Pn/+HMjeunUrmZ5mYWeBRDYaAjpIyUm1pqYGaPqfP39YWVn37t0LtxsoLioqCmE7OjqSaTcbDzvE3zm3qiT0pUHIQDpkRTzE+oDaUKDpwKBmY2N79eoV3O6WlpaKigog48ePH8DwINNuDn5ossq6Wg4XtK9zhwjaVrkALf7375+6uvp/JNDd3X3r1i0gY+PGjWRaDATCqqIQazLOl8AFAxdFQQRDO2MgllVXVwNJoNd//foFZCxevBgizsvLS77dOWfLIda4t/vDBQvv10EDozwbYse7d++AZEdHx4cPH4CML1++QMTJtxhkDSyhRaxLCl4SB0SRG5MhInl3qp2dnZGDmoOD4/Xr13Du5MmTKbIbM4UDUcHj2ry7tcA8LSsrC7cJmI+B6l+8eAEXgZd3lAKgTcyszExACCRZQAygIJANRBApCJeRiREoC2QzsTBRx2IgEFMVL7hZq2CtbF/lJqohEbk6EWhN8qE8RTvVuO0ZhnFmBlGmBtGmAfMiCx/WSRnLJh/Jp5rdQH/4zgxTclJT99YR05TQjzJm5WILmBchrCyWdroYqCBxRxY7H0f05rTwZYlxOzIi1idTzW42LjaTFCtFO+WQOTFe7QGh8+Nc6rzDlyf49oWGLI0Nmh/j3uPvMynYptiZR4LXKNHSOMWSanaPglEwCkbBKBj0AABRRteQUzXwCAAAAABJRU5ErkJggg==';

// ================================================================
// GERAÇÃO DE PDF — FICHA DE EPI (formato BW Telecom)
// ================================================================
async function gerarFichaEPI(tecnico, requisicoes, produtosEpi, tenant) {
  return new Promise(async (resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 15,
        info: {
          Title: `Ficha de EPI - ${tecnico.nome} - BW Telecom`,
          Author: 'SeeNet - BW Telecom',
          Subject: 'Ficha de Controle de Equipamentos de Proteção Individual',
        },
      });

      const chunks = [];
      doc.on('data', (chunk) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const W = 595.28;
      const M = 15;
      const CW = W - M * 2;
      const CB = '#999999';

      let y = M;

      // ── LOGOS ─────────────────────────────────────────────────
      try { const cruzBuf = Buffer.from(LOGO_CRUZ_BASE64, 'base64'); doc.image(cruzBuf, M + 5, y + 6, { height: 42 }); } catch (_) {}
      try { const bwBuf = Buffer.from(LOGO_BW_BASE64, 'base64'); doc.image(bwBuf, M + 50, y + 10, { height: 34 }); } catch (_) {}

      doc.rect(M, y, CW, 55).stroke(CB);
      doc.fontSize(13).font('Helvetica-Bold').fillColor('#000000')
        .text('FICHA DE CONTROLE DE EQUIPAMENTOS', M + 95, y + 10, { width: CW - 200, align: 'center' });
      doc.fontSize(12).font('Helvetica-Bold')
        .text('DE PROTEÇÃO INDIVIDUAL – EPI', M + 95, y + 28, { width: CW - 200, align: 'center' });

      try { const cruzBuf2 = Buffer.from(LOGO_CRUZ_BASE64, 'base64'); doc.image(cruzBuf2, W - M - 50, y + 6, { height: 42 }); } catch (_) {}

      y += 59;

      // ── DADOS DO COLABORADOR ──────────────────────────────────
      const dataRevisaoFicha = formatarDataBR(new Date(), false);
      const lCol = CW * 0.55;
      const rCol = CW * 0.45;

      doc.rect(M + lCol, y, rCol, 18).stroke(CB);
      doc.fontSize(7.5).font('Helvetica-Bold').fillColor('#000000')
        .text(`DATA DE REVISÃO: ${dataRevisaoFicha}`, M + lCol + 4, y + 5);
      y += 18;

      doc.rect(M, y - 18, lCol, 36).stroke(CB);
      doc.fontSize(7.5).font('Helvetica-Bold')
        .text(`NOME: ${tecnico.nome?.toUpperCase() || ''}`, M + 4, y - 12);

      doc.rect(M + lCol, y, rCol, 18).stroke(CB);
      doc.text(`DATA ADMISSÃO: ${tecnico.data_criacao ? formatarDataBR(tecnico.data_criacao, false) : '---'}`, M + lCol + 4, y + 5);
      y += 18;

      doc.rect(M, y, lCol, 18).stroke(CB);
      doc.fontSize(7).font('Helvetica-Bold')
        .text('END: PRAÇA PADRE MANOEL DE OLIVEIRA, Nº10 – MALHADOR-SE.', M + 4, y + 5);
      doc.rect(M + lCol, y, rCol * 0.6, 18).stroke(CB);
      doc.text('CARGO: TÉCNICO DE REDE', M + lCol + 4, y + 5);
      doc.rect(M + lCol + rCol * 0.6, y, rCol * 0.4, 18).stroke(CB);
      doc.text('CBO: 313305', M + lCol + rCol * 0.6 + 4, y + 5);
      y += 22;

      // ── DECLARAÇÃO LEGAL ──────────────────────────────────────
      const declaracao = 'Reconheço ter sido orientado sobre os riscos à saúde dos eventuais agentes agressivos do meu trabalho e ter sido orientado adequadamente sobre as proteções que devem ser tomadas. Reconheço, também, estar recebendo todos os equipamentos de proteção individual necessários à minha função e ter sido treinado e orientado quanto a sua correta e obrigatória utilização. Declaro ainda:\n►Ter recebido treinamento sobre a utilização adequada destes EPIs, seu prazo de validade, bem como dos riscos que estou sujeito pelo seu não uso;\n►Indenizar a empresa, autorizando o desconto do custo da reparação do dano que eventualmente vier a provocar nos EPIs em questão, por atos de negligência ou mau uso, extravio ou na sua não devolução quando a mim solicitado, já que atesto tê-lo recebido em perfeitas condições (ciente e colocando minha anuência às disposições do Art. 462 da CLT);\n► Estar ciente da disposição legal constante na Norma Regulamentadora NR 01, sub-item 1.8.1 e item 1.9, de que constitui ato faltoso a recusa injustificada de usar os EPIs fornecidos pelo empregador, incorrendo nas penalidades previstas na legislação pertinente;\n► Que na não observância do seu uso, por negligência, os danos e/ou lesões resultantes de acidentes serão de minha inteira responsabilidade.';

      doc.fontSize(6).font('Helvetica').fillColor('#000000').text(declaracao, M, y, { width: CW, lineGap: 0.8 });
      y = doc.y + 6;

      if (tecnico.assinatura_admissao) {
        try {
          const sigClean = tecnico.assinatura_admissao.replace(/^data:image\/\w+;base64,/, '');
          const sigBuf = Buffer.from(sigClean, 'base64');
          doc.image(sigBuf, M + 50, y, { height: 28 });
          y += 32;
        } catch (_) { doc.text('__________________________________', M + 60, y); y += 14; }
      } else {
        doc.text('__________________________________', M + 60, y); y += 14;
      }

      doc.fontSize(7.5).font('Helvetica').text('ASSINATURA DO EMPREGADO', M + 70, y);
      doc.text('LOCAL: MALHADOR/SE', M + CW * 0.6, y);
      y += 16;

      // ── TABELA DE EPIs (com DEVOLUÇÃO) ────────────────────────
            const colT = { quat: 30, uni: 24, desc: 110, fab: 72, ca: 36, data: 46, assRet: 55, subst: 30, dataDev: 46, assDev: CW - 30 - 24 - 110 - 72 - 36 - 46 - 55 - 30 - 46 };

            function cabecalhoTabela(yPos) {
              const specW = colT.quat + colT.uni + colT.desc + colT.fab + colT.ca;
              const retW = colT.data + colT.assRet;
              const devW = colT.subst + colT.dataDev + colT.assDev;

              doc.rect(M, yPos, specW, 14).fill('#D0D0D0');
              doc.rect(M, yPos, specW, 14).lineWidth(1).stroke('#000000');
              doc.fontSize(7).font('Helvetica-Bold').fillColor('#000000')
                .text('ESPECIFICAÇÃO DO EPI', M, yPos + 4, { width: specW, align: 'center' });

              doc.rect(M + specW, yPos, retW, 14).fill('#D0D0D0');
              doc.rect(M + specW, yPos, retW, 14).lineWidth(1).stroke('#000000');
              doc.fontSize(7).font('Helvetica-Bold').fillColor('#000000')
                .text('RETIRADA', M + specW, yPos + 4, { width: retW, align: 'center' });

              doc.rect(M + specW + retW, yPos, devW, 14).fill('#D0D0D0');
              doc.rect(M + specW + retW, yPos, devW, 14).lineWidth(1).stroke('#000000');
              doc.fontSize(7).font('Helvetica-Bold').fillColor('#000000')
                .text('DEVOLUÇÃO', M + specW + retW, yPos + 4, { width: devW, align: 'center' });

              yPos += 14;

              let x = M;
              const headers = [
                { l: 'QUAT', w: colT.quat }, { l: 'UNI', w: colT.uni },
                { l: 'DESCRIÇÃO DO EPI', w: colT.desc }, { l: 'FABRICANTE', w: colT.fab },
                { l: 'CA', w: colT.ca }, { l: 'DATA', w: colT.data },
                { l: 'ASSINATURA', w: colT.assRet }, { l: 'SUBST', w: colT.subst },
                { l: 'DATA', w: colT.dataDev }, { l: 'ASSINATURA', w: colT.assDev },
              ];
              headers.forEach(h => {
                doc.rect(x, yPos, h.w, 12).fill('#E8E8E8');
                doc.rect(x, yPos, h.w, 12).lineWidth(0.5).stroke('#000000');
                doc.fontSize(5.5).font('Helvetica-Bold').fillColor('#000000')
                  .text(h.l, x, yPos + 3, { width: h.w, align: 'center' });
                x += h.w;
              });

              doc.lineWidth(1);
              return yPos + 12;
            }
            y = cabecalhoTabela(y);

      const produtoMap = {};
      produtosEpi.forEach(p => { produtoMap[p.nome] = p; });

      const reqsAprovadas = requisicoes
        .filter(r => ['concluida', 'aprovada', 'aguardando_confirmacao'].includes(r.status))
        .sort((a, b) => new Date(a.data_resposta || a.data_criacao) - new Date(b.data_resposta || b.data_criacao));

      for (const req of reqsAprovadas) {
        const episFicha = Array.isArray(req.epis_solicitados) ? req.epis_solicitados : JSON.parse(req.epis_solicitados || '[]');
        const devolucoes = req.devolucoes ? (Array.isArray(req.devolucoes) ? req.devolucoes : JSON.parse(req.devolucoes || '[]')) : [];
        const dataEntregaFicha = req.data_entrega || req.data_resposta || req.data_criacao;
        const dataStr = dataEntregaFicha ? formatarDataBR(new Date(dataEntregaFicha), false) : '---';

        for (const epiNome of episFicha) {
          if (y > 740) { doc.addPage(); y = M; y = cabecalhoTabela(y); }

          const qtdMatch = epiNome.match(/x(\d+)$/);
          const quantidade = qtdMatch ? parseInt(qtdMatch[1]) : 1;
          const nomeLimpo = epiNome.replace(/\s*\(Tam\.\s*\w+\)/, '').replace(/\s*x\d+$/, '').trim();
          const prodInfo = produtoMap[nomeLimpo] || {};
          const ca = prodInfo.ca || '........';
          const fornecedor = prodInfo.fornecedor || '';
          const tamMatch = epiNome.match(/\(Tam\.\s*(\w+)\)/);
          let descFinal = nomeLimpo;
          if (tamMatch) descFinal += ` - ${tamMatch[1]}`;

          const devInfo = devolucoes.find(d => d.epi === epiNome || d.epi === nomeLimpo) || {};
          const codigoSubst = devInfo.codigo_subst || '';
          const dataDev = devInfo.data_devolucao || '';

          let x = M;
          const rH = 14;

          doc.rect(x, y, colT.quat, rH).stroke(CB);
          doc.fontSize(5.5).font('Helvetica').fillColor('#000000').text(`${quantidade}`, x + 2, y + 4, { width: colT.quat - 4, align: 'center' });
          x += colT.quat;

          doc.rect(x, y, colT.uni, rH).stroke(CB);
          doc.fontSize(5.5).text('UNI', x + 2, y + 4, { width: colT.uni - 4, align: 'center' });
          x += colT.uni;

          doc.rect(x, y, colT.desc, rH).stroke(CB);
          doc.fontSize(5.5).text(descFinal, x + 2, y + 4, { width: colT.desc - 4 });
          x += colT.desc;

          doc.rect(x, y, colT.fab, rH).stroke(CB);
          doc.fontSize(5).text(fornecedor.toUpperCase(), x + 2, y + 4, { width: colT.fab - 4 });
          x += colT.fab;

          doc.rect(x, y, colT.ca, rH).stroke(CB);
          doc.fontSize(5.5).text(ca, x + 2, y + 4, { width: colT.ca - 4 });
          x += colT.ca;

          doc.rect(x, y, colT.data, rH).stroke(CB);
          doc.fontSize(5).text(dataStr, x + 2, y + 4, { width: colT.data - 4 });
          x += colT.data;

          doc.rect(x, y, colT.assRet, rH).stroke(CB);
          if (req.assinatura_recebimento_base64) {
            try {
              const sigClean2 = req.assinatura_recebimento_base64.replace(/^data:image\/\w+;base64,/, '');
              const sigBuf2 = Buffer.from(sigClean2, 'base64');
              doc.image(sigBuf2, x + 1, y + 1, { height: rH - 2, fit: [colT.assRet - 2, rH - 2] });
            } catch (_) {}
          }
          x += colT.assRet;

          doc.rect(x, y, colT.subst, rH).stroke(CB);
          if (codigoSubst) {
            doc.fontSize(5).font('Helvetica-Bold').text(codigoSubst, x + 1, y + 4, { width: colT.subst - 2, align: 'center' });
            doc.font('Helvetica');
          }
          x += colT.subst;

          doc.rect(x, y, colT.dataDev, rH).stroke(CB);
          if (dataDev) { doc.fontSize(5).text(dataDev, x + 2, y + 4, { width: colT.dataDev - 4 }); }
          x += colT.dataDev;

          doc.rect(x, y, colT.assDev, rH).stroke(CB);
          if (devInfo.assinatura_devolucao) {
            try {
              const devSigClean = devInfo.assinatura_devolucao.replace(/^data:image\/\w+;base64,/, '');
              const devSigBuf = Buffer.from(devSigClean, 'base64');
              doc.image(devSigBuf, x + 1, y + 1, { height: rH - 2, fit: [colT.assDev - 2, rH - 2] });
            } catch (_) {}
          }

          y += rH;
        }
      }

      // ── CÓDIGO DE SUBSTITUIÇÃO (legenda) ──────────────────────
      if (y > 720) { doc.addPage(); y = M; }
      y += 8;
      doc.rect(M, y, CW, 12).fill('#E0E0E0').stroke(CB);
      doc.fontSize(6).font('Helvetica-Bold').fillColor('#000000').text('CÓDIGO DE SUBSTITUIÇÃO', M + CW / 2 - 50, y + 3);
      y += 14;
      const codigos = [
        { cod: 'PE', desc: 'PERDA OU EXTRAVIO', cod2: 'IU', desc2: 'IMPRÓPRIO PARA USO' },
        { cod: 'SP', desc: 'SUBST. (PERDA VIDA ÚTIL)', cod2: 'AD', desc2: 'APRESENTA DEFEITO' },
        { cod: 'DT', desc: 'DANIFICADO P/ TRABALHO', cod2: 'DE', desc2: 'DESLIG. DA EMPRESA' },
      ];
      codigos.forEach(row => {
        doc.rect(M, y, CW / 2, 12).fill('#F5F5F5').stroke(CB);
        doc.rect(M + CW / 2, y, CW / 2, 12).fill('#F5F5F5').stroke(CB);
        doc.fontSize(5.5).font('Helvetica-Bold').fillColor('#000000').text(`${row.cod} - `, M + 4, y + 3, { continued: true });
        doc.font('Helvetica').text(row.desc);
        doc.fontSize(5.5).font('Helvetica-Bold').text(`${row.cod2} - `, M + CW / 2 + 4, y + 3, { continued: true });
        doc.font('Helvetica').text(row.desc2);
        y += 12;
      });

      // ── OBS NR-01 ─────────────────────────────────────────────
      if (y > 740) { doc.addPage(); y = M; }
      y += 8;
      doc.fontSize(6).font('Helvetica-Bold').fillColor('#000000').text('OBS: ', M, y, { continued: true });
      doc.font('Helvetica').text('Conforme determina a NR 01, a substituição do Equipamento de Proteção Individual (EPI) deve ser feita de acordo com o prazo de validade do fabricante e o estado do equipamento.', { width: CW });

      // ── RODAPÉ ────────────────────────────────────────────────
      const footerYFicha = 841.89 - 34;
      doc.fontSize(6.5).font('Helvetica-Bold').fillColor('#000000').text('BW TELECOM LTDA - CNPJ: 47.626.282/0001-09', M, footerYFicha, { width: CW, align: 'center' });
      doc.fontSize(6.5).font('Helvetica').text('PRAÇA PADRE MANOEL DE OLIVEIRA, Nº10 – MALHADOR-SE.', M, footerYFicha + 10, { width: CW, align: 'center' });

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

// ================================================================
// ROTAS
// ================================================================

router.get('/epis', authMiddleware, async (req, res) => {
  try {
    const produtos = await db('produtos_epi').where('tenant_id', req.user.tenant_id).where('ativo', true).orderBy('nome', 'asc');
    if (produtos.length > 0) return res.json({ epis: produtos.map(p => p.nome) });
    res.json({ epis: EPIS_PADRAO });
  } catch (err) { res.json({ epis: EPIS_PADRAO }); }
});

router.post('/requisicoes', authMiddleware, async (req, res) => {
  try {
    const { epis_solicitados } = req.body;
    if (!epis_solicitados?.length) return res.status(400).json({ error: 'Selecione ao menos um EPI' });
    const [{ id }] = await db('requisicoes_epi').insert({
      tenant_id: req.user.tenant_id, tecnico_id: req.user.id, status: 'pendente',
      epis_solicitados: JSON.stringify(epis_solicitados), registro_manual: false,
    }).returning('id');
    res.status(201).json({ success: true, message: 'Requisição enviada com sucesso!', id });

        // ✅ NOTIFICAÇÃO: Avisar gestores de nova requisição
        try {
          const tecnico = await db('usuarios').where('id', req.user.id).first();
          await notificationService.enviarParaGestores(
            db, req.user.tenant_id,
            '📋 Nova Requisição de EPI',
            `${tecnico.nome} solicitou equipamentos de proteção.`,
            { route: '/seguranca/gestao', tipo: 'nova_requisicao', referencia_id: String(id) }
          );
        } catch (notifErr) { console.warn('⚠️ Falha ao notificar gestores:', notifErr.message); }

      } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao criar requisição' }); }
});

router.post('/requisicoes/manual', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { tecnico_id, epis_solicitados, assinatura_base64, foto_base64, observacao_gestor, data_entrega, foto_documento_base64, eh_fichario } = req.body;
    if (!tecnico_id) return res.status(400).json({ error: 'Técnico obrigatório' });
    if (!epis_solicitados?.length) return res.status(400).json({ error: 'Selecione ao menos um EPI' });
    const tecnico = await db('usuarios').where('id', tecnico_id).first();
    if (!tecnico) return res.status(404).json({ error: 'Técnico não encontrado' });
    const dataEntregaFinal = data_entrega ? new Date(data_entrega) : new Date();
    const [inserted] = await db('requisicoes_epi').insert({
      tenant_id: req.user.tenant_id, tecnico_id, gestor_id: req.user.id, status: 'aprovada',
      epis_solicitados: JSON.stringify(epis_solicitados), assinatura_base64: assinatura_base64 || null,
      foto_base64: foto_base64 || null, observacao_gestor: observacao_gestor || 'Registro manual pelo gestor de segurança.',
      data_resposta: new Date(), data_entrega: dataEntregaFinal, registro_manual: true, criado_por_gestor_id: req.user.id,
      foto_documento_base64: foto_documento_base64 || null,
      eh_fichario: eh_fichario === true,
    }).returning('*');
    try {
      const gestor = await db('usuarios').where('id', req.user.id).first();
      const pdfBuffer = await gerarPDF(inserted, tecnico, gestor);
      await db('requisicoes_epi').where('id', inserted.id).update({ pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}` });
    } catch (e) { console.error('Erro ao gerar PDF no registro manual:', e); }
    res.status(201).json({ success: true, message: 'Registro manual criado com sucesso!', id: inserted.id });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao criar registro manual' }); }
});

router.get('/requisicoes/minhas', authMiddleware, async (req, res) => {
  try {
    const { mes, ano } = req.query;
    let query = db('requisicoes_epi as r').leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tenant_id', req.user.tenant_id).where('r.tecnico_id', req.user.id)
      .select('r.*', 'g.nome as gestor_nome');
    if (ano) query = query.whereRaw('EXTRACT(YEAR FROM r.data_criacao) = ?', [ano]);
    if (mes) query = query.whereRaw('EXTRACT(MONTH FROM r.data_criacao) = ?', [mes]);
    const lista = await query.orderBy('r.data_criacao', 'desc');
    res.json({ requisicoes: lista });

router.get('/requisicoes/pendentes', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const lista = await db('requisicoes_epi as r').join('usuarios as t', 't.id', 'r.tecnico_id')
      .where('r.tenant_id', req.user.tenant_id).where('r.status', 'pendente')
      .select('r.*', 't.nome as tecnico_nome', 't.email as tecnico_email').orderBy('r.data_criacao', 'asc');
    res.json({ requisicoes: lista });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar pendentes' }); }
});

router.get('/requisicoes/historico', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    let query = db('requisicoes_epi as r').join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id').where('r.tenant_id', req.user.tenant_id)
      .whereIn('r.status', ['concluida', 'aprovada', 'aguardando_confirmacao'])
      .select('r.id', 'r.status', 'r.epis_solicitados', 'r.itens_ixc', 'r.id_requisicao_ixc',
        'r.data_criacao', 'r.data_resposta', 'r.data_entrega', 'r.data_confirmacao_recebimento',
        'r.assinatura_recebimento_base64', 'r.foto_recebimento_base64', 'r.observacao_gestor',
        'r.registro_manual', 'r.pdf_base64', 'r.devolucoes', 't.nome as tecnico_nome',
        't.email as tecnico_email', 't.foto_perfil as tecnico_foto', 'g.nome as gestor_nome')
      .orderBy('r.data_confirmacao_recebimento', 'desc');
    if (req.query.tecnico_id) query = query.where('r.tecnico_id', req.query.tecnico_id);
    const lista = await query;
    res.json({ requisicoes: lista });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao buscar histórico' }); }
});

router.get('/requisicoes', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    let query = db('requisicoes_epi as r').join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id').where('r.tenant_id', req.user.tenant_id)
      .select('r.*', 't.nome as tecnico_nome', 't.email as tecnico_email', 'g.nome as gestor_nome')
      .orderBy('r.data_criacao', 'desc');
    if (req.query.status) query = query.where('r.status', req.query.status);
    if (req.query.tecnico_id) query = query.where('r.tecnico_id', req.query.tecnico_id);
    const lista = await query;
    res.json({ requisicoes: lista });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar requisições' }); }
});

router.get('/requisicoes/:id', authMiddleware, async (req, res) => {
  try {
    const req_data = await db('requisicoes_epi as r').join('usuarios as t', 't.id', 'r.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'r.gestor_id').where('r.id', req.params.id)
      .where('r.tenant_id', req.user.tenant_id)
      .select('r.*', 't.nome as tecnico_nome', 't.email as tecnico_email', 'g.nome as gestor_nome').first();
    if (!req_data) return res.status(404).json({ error: 'Não encontrado' });
    if (req_data.tecnico_id !== req.user.id && !isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });
    res.json({ requisicao: req_data });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar requisição' }); }
});

router.post('/requisicoes/:id/aprovar', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });

    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (!requisicao) return res.status(404).json({ error: 'Não encontrada' });
    if (requisicao.status !== 'pendente')
      return res.status(400).json({ error: `Requisição já está com status: ${requisicao.status}` });

    const { observacao, data_entrega, itens_ixc = [], devolucoes = [] } = req.body;

    // ── Integração IXC ─────────────────────────────────────────
    let id_requisicao_ixc = null;
    let itens_ixc_resultado = [];

    if (itens_ixc.length > 0) {
      try {
        const integracao = await db('integracao_ixc').where('tenant_id', req.user.tenant_id).where('ativo', true).first();
        if (integracao) {
          const IXCService = require('../services/IXCService');
          const ixc = new IXCService(integracao.url_api, integracao.token_api);
          const mapeamento = await db('mapeamento_tecnicos_ixc').where('usuario_id', requisicao.tecnico_id).where('tenant_id', req.user.tenant_id).first();
          if (!mapeamento) return res.status(400).json({ error: 'Técnico sem almoxarifado mapeado no IXC.' });

          const { id: reqIxcId } = await ixc.criarRequisicaoMaterial({
            id_filial: integracao.id_filial || '1', id_almoxarifado: mapeamento.id_almoxarifado.toString(),
            id_colaborador: mapeamento.tecnico_ixc_id.toString(), observacao: `Req. EPI #${requisicao.id} - SeeNet`,
          });
          id_requisicao_ixc = reqIxcId;

          for (const item of itens_ixc) {
            try {
              const resultado = await ixc.adicionarItemRequisicaoMaterial(reqIxcId, { id_produto: item.id_produto, quantidade: item.quantidade || 1 });
              itens_ixc_resultado.push({ id_produto: item.id_produto, descricao: item.descricao || '', quantidade: item.quantidade || 1, id_item_ixc: resultado.id, qtde_saldo: resultado.qtde_saldo });
            } catch (itemErr) {
              console.error(`⚠️ Falha no item ${item.id_produto}:`, itemErr.message);
              itens_ixc_resultado.push({ id_produto: item.id_produto, descricao: item.descricao || '', quantidade: item.quantidade || 1, erro: itemErr.message });
            }
          }
        }
      } catch (ixcErr) { console.error('⚠️ Erro IXC:', ixcErr.message); }
    }

    // ── Atualizar banco ────────────────────────────────────────
    await db('requisicoes_epi').where('id', req.params.id).update({
      status: 'aguardando_confirmacao', gestor_id: req.user.id, observacao_gestor: observacao || null,
      data_resposta: new Date(), data_entrega: data_entrega ? new Date(data_entrega) : new Date(),
      id_requisicao_ixc, itens_ixc: itens_ixc_resultado.length > 0 ? JSON.stringify(itens_ixc_resultado) : null,
      devolucoes: devolucoes.length > 0 ? JSON.stringify(devolucoes) : null,
    });

    // ── PDF ─────────────────────────────────────────────────────
    const updated = await db('requisicoes_epi').where('id', req.params.id).first();
    const tecnico = await db('usuarios').where('id', updated.tecnico_id).first();
    const gestor = await db('usuarios').where('id', req.user.id).first();
    try {
      const pdfBuffer = await gerarPDF(updated, tecnico, gestor);
      await db('requisicoes_epi').where('id', req.params.id).update({ pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}` });
    } catch (e) { console.error('⚠️ PDF falhou:', e.message); }

    const itens_com_erro = itens_ixc_resultado.filter(i => i.erro);
    res.json({
          success: true, message: 'Requisição aprovada! Aguardando confirmação do técnico.',
          id_requisicao_ixc, itens_descontados: itens_ixc_resultado.filter(i => !i.erro).length,
          ...(itens_com_erro.length > 0 && { itens_com_erro }),
        });

        // ✅ NOTIFICAÇÃO: Avisar técnico que foi aprovada
        try {
          await notificationService.enviarParaUsuario(
            db, requisicao.tecnico_id,
            '✅ Requisição Aprovada!',
            'Seus EPIs foram aprovados. Confirme o recebimento quando receber.',
            { route: '/seguranca', tipo: 'requisicao_aprovada', referencia_id: String(req.params.id) }
          );
        } catch (notifErr) { console.warn('⚠️ Falha ao notificar técnico:', notifErr.message); }

      } catch (err) { console.error('❌ Erro ao aprovar:', err); res.status(500).json({ error: 'Erro ao aprovar' }); }
});

router.post('/requisicoes/:id/recusar', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    if (!req.body.observacao?.trim()) return res.status(400).json({ error: 'Motivo obrigatório' });
    await db('requisicoes_epi').where('id', req.params.id).update({
      status: 'recusada', gestor_id: req.user.id, observacao_gestor: req.body.observacao, data_resposta: new Date(),
    });
    res.json({ success: true, message: 'Requisição recusada.' });

        // ✅ NOTIFICAÇÃO: Avisar técnico que foi recusada
        try {
          const reqRecusada = await db('requisicoes_epi').where('id', req.params.id).first();
          await notificationService.enviarParaUsuario(
            db, reqRecusada.tecnico_id,
            '❌ Requisição Recusada',
            `Motivo: ${req.body.observacao}`,
            { route: '/seguranca/minhas', tipo: 'requisicao_recusada', referencia_id: String(req.params.id) }
          );
        } catch (notifErr) { console.warn('⚠️ Falha ao notificar técnico:', notifErr.message); }

      } catch (err) { res.status(500).json({ error: 'Erro ao recusar' }); }
});

router.get('/requisicoes/:id/pdf', authMiddleware, async (req, res) => {
  try {
    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (!requisicao) return res.status(404).json({ error: 'Não encontrada' });
    if (requisicao.tecnico_id !== req.user.id && !isGestorOuAdmin(req.user.tipo_usuario))
      return res.status(403).json({ error: 'Sem permissão' });
    let pdfBase64 = requisicao.pdf_base64;
    if (!pdfBase64 && requisicao.status === 'aprovada') {
      const tecnico = await db('usuarios').where('id', requisicao.tecnico_id).first();
      const gestor = requisicao.gestor_id ? await db('usuarios').where('id', requisicao.gestor_id).first() : null;
      const pdfBuffer = await gerarPDF(requisicao, tecnico, gestor);
      pdfBase64 = `data:application/pdf;base64,${pdfBuffer.toString('base64')}`;
      await db('requisicoes_epi').where('id', req.params.id).update({ pdf_base64: pdfBase64 });
    }
    if (!pdfBase64) return res.status(404).json({ error: 'PDF não disponível' });
    res.json({ pdf_base64: pdfBase64 });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar PDF' }); }
});

router.post('/requisicoes/:id/confirmar-recebimento', authMiddleware, async (req, res) => {
  try {
    const { assinatura_base64, foto_base64 } = req.body;
    if (!assinatura_base64) return res.status(400).json({ error: 'Assinatura obrigatória' });
    if (!foto_base64) return res.status(400).json({ error: 'Foto obrigatória' });
    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (!requisicao) return res.status(404).json({ error: 'Não encontrada' });
    if (requisicao.tecnico_id !== req.user.id) return res.status(403).json({ error: 'Sem permissão' });
    if (requisicao.status !== 'aguardando_confirmacao') return res.status(400).json({ error: 'Requisição não está aguardando confirmação' });
    await db('requisicoes_epi').where('id', req.params.id).update({
      status: 'concluida', assinatura_recebimento_base64: assinatura_base64,
      foto_recebimento_base64: foto_base64, data_confirmacao_recebimento: new Date(),
    });
    const updated = await db('requisicoes_epi').where('id', req.params.id).first();
    const tecnico = await db('usuarios').where('id', req.user.id).first();
    const gestor = updated.gestor_id ? await db('usuarios').where('id', updated.gestor_id).first() : null;
    try {
      const pdfBuffer = await gerarPDF(updated, tecnico, gestor);
      await db('requisicoes_epi').where('id', req.params.id).update({ pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}` });
    } catch (e) { console.error('Erro ao gerar PDF na confirmação:', e); }
    res.json({ success: true, message: 'Recebimento confirmado! PDF gerado.' });

        // ✅ NOTIFICAÇÃO: Avisar gestores que técnico confirmou
        try {
          const tecConfirmou = await db('usuarios').where('id', req.user.id).first();
          await notificationService.enviarParaGestores(
            db, req.user.tenant_id,
            '📦 Recebimento Confirmado',
            `${tecConfirmou.nome} confirmou o recebimento dos EPIs.`,
            { route: '/seguranca/gestao', tipo: 'recebimento_confirmado', referencia_id: String(req.params.id) }
          );
        } catch (notifErr) { console.warn('⚠️ Falha ao notificar gestores:', notifErr.message); }

      } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao confirmar recebimento' }); }
});

router.get('/tecnicos', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const lista = await db('usuarios').where('tenant_id', req.user.tenant_id).where('ativo', true)
      .whereIn('tipo_usuario', ['tecnico', 'administrador']).select('id', 'nome', 'email', 'tipo_usuario').orderBy('nome');
    res.json({ tecnicos: lista });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar técnicos' }); }
});

router.get('/tecnicos/:id/perfil', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const tecnicoId = req.params.id;
    const usuario = await db('usuarios').where('id', tecnicoId).where('tenant_id', req.user.tenant_id)
      .select('id', 'nome', 'email', 'tipo_usuario', 'foto_perfil', 'assinatura_admissao', 'data_criacao', 'ultimo_login').first();
    if (!usuario) return res.status(404).json({ error: 'Técnico não encontrado' });
    const tenant = await db('tenants').where('id', req.user.tenant_id).first();
    const stats = await db('requisicoes_epi').where('tecnico_id', tecnicoId).where('tenant_id', req.user.tenant_id)
      .select(db.raw('COUNT(*) as total'), db.raw("COUNT(*) FILTER (WHERE status = 'concluida') as concluidas"),
        db.raw("COUNT(*) FILTER (WHERE status = 'aprovada' OR status = 'aguardando_confirmacao') as aprovadas"),
        db.raw("COUNT(*) FILTER (WHERE status = 'pendente') as pendentes"),
        db.raw("COUNT(*) FILTER (WHERE status = 'recusada') as recusadas")).first();
    const requisicoes = await db('requisicoes_epi as r').leftJoin('usuarios as g', 'g.id', 'r.gestor_id')
      .where('r.tecnico_id', tecnicoId).where('r.tenant_id', req.user.tenant_id)
      .select('r.id', 'r.status', 'r.epis_solicitados', 'r.itens_ixc', 'r.id_requisicao_ixc',
        'r.data_criacao', 'r.data_resposta', 'r.data_entrega', 'r.data_confirmacao_recebimento',
        'r.observacao_gestor', 'r.registro_manual', 'r.pdf_base64', 'r.assinatura_recebimento_base64',
        'r.foto_recebimento_base64', 'r.devolucoes', 'g.nome as gestor_nome').orderBy('r.data_criacao', 'desc');
    res.json({ usuario: { ...usuario, empresa: tenant?.nome }, stats, requisicoes });
  } catch (err) { console.error('❌ Erro ao buscar perfil do técnico:', err); res.status(500).json({ error: 'Erro ao buscar perfil do técnico' }); }
});

router.get('/tecnicos/:id/ficha-epi', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const tecnicoId = req.params.id;
    const tecnico = await db('usuarios').where('id', tecnicoId).where('tenant_id', req.user.tenant_id).first();
    if (!tecnico) return res.status(404).json({ error: 'Técnico não encontrado' });
    const requisicoes = await db('requisicoes_epi').where('tecnico_id', tecnicoId).where('tenant_id', req.user.tenant_id)
      .whereIn('status', ['concluida', 'aprovada', 'aguardando_confirmacao']).orderBy('data_criacao', 'asc');
    const produtosEpi = await db('produtos_epi').where('tenant_id', req.user.tenant_id).where('ativo', true);
    const tenant = await db('tenants').where('id', req.user.tenant_id).first();
    const pdfBuffer = await gerarFichaEPI(tecnico, requisicoes, produtosEpi, tenant);
    res.json({ pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}` });
  } catch (err) { console.error('❌ Erro ao gerar ficha EPI:', err); res.status(500).json({ error: 'Erro ao gerar ficha de EPI' }); }
});

router.put('/tecnicos/:id/assinatura-admissao', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { assinatura_base64 } = req.body;
    if (!assinatura_base64) return res.status(400).json({ error: 'Assinatura obrigatória' });
    await db('usuarios').where('id', req.params.id).where('tenant_id', req.user.tenant_id).update({ assinatura_admissao: assinatura_base64 });
    res.json({ success: true, message: 'Assinatura de admissão salva!' });
  } catch (err) { res.status(500).json({ error: 'Erro ao salvar assinatura' }); }
});

router.put('/requisicoes/:id/devolucoes', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { devolucoes } = req.body;
    await db('requisicoes_epi').where('id', req.params.id).where('tenant_id', req.user.tenant_id)
      .update({ devolucoes: devolucoes ? JSON.stringify(devolucoes) : null });
    const requisicao = await db('requisicoes_epi').where('id', req.params.id).first();
    if (requisicao && ['concluida', 'aprovada'].includes(requisicao.status)) {
      try {
        const tecnico = await db('usuarios').where('id', requisicao.tecnico_id).first();
        const gestor = requisicao.gestor_id ? await db('usuarios').where('id', requisicao.gestor_id).first() : null;
        const pdfBuffer = await gerarPDF(requisicao, tecnico, gestor);
        await db('requisicoes_epi').where('id', req.params.id).update({ pdf_base64: `data:application/pdf;base64,${pdfBuffer.toString('base64')}` });
      } catch (e) { console.error('⚠️ PDF regen falhou:', e.message); }
    }
    res.json({ success: true, message: 'Devoluções atualizadas!' });
  } catch (err) { console.error('❌ Erro devoluções:', err); res.status(500).json({ error: 'Erro ao atualizar' }); }
});

router.get('/almoxarifados-colaboradores', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const integracao = await db('integracao_ixc').where('tenant_id', req.user.tenant_id).where('ativo', true).first();
    if (!integracao) return res.json({ almoxarifados: [] });
    const IXCService = require('../services/IXCService');
    const ixc = new IXCService(integracao.url_api, integracao.token_api);
    const IDS_COLABORADORES = [25,26,27,28,29,30,31,32,33,35,36,37,38,39,40,41,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,76,97,102,107,116];
    const body = { qtype: 'almox.id', query: '1', oper: '>=', page: '1', rp: '200', sortname: 'almox.descricao', sortorder: 'asc' };
    const response = await ixc.clientAlterar.post('/almox', body, { headers: { 'ixcsoft': 'listar' } });
    const todos = response.data.registros || [];
    const filtrados = todos.filter(a => IDS_COLABORADORES.includes(parseInt(a.id)) && a.ativo === 'S').map(a => ({ id: a.id, descricao: a.descricao }));
    res.json({ almoxarifados: filtrados });
  } catch (err) { console.error('❌ Erro almoxarifados:', err.message); res.status(500).json({ error: 'Erro ao buscar almoxarifados' }); }
});

router.get('/produtos-epi', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const produtos = await db('produtos_epi').where('tenant_id', req.user.tenant_id).where('ativo', true).orderBy('nome', 'asc');
    const mapeamento = produtos.map(p => ({ epi: p.nome, id_produto: p.id_produto_ixc, descricao_ixc: p.descricao_ixc, tamanhos: p.tamanhos, ca: p.ca, fornecedor: p.fornecedor }));
    res.json({ mapeamento });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar produtos EPI' }); }
});

router.get('/produtos-epi-cadastro', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const produtos = await db('produtos_epi').where('tenant_id', req.user.tenant_id).where('ativo', true).orderBy('nome', 'asc');
    res.json({ produtos });
  } catch (err) { console.error('❌ Erro produtos EPI:', err); res.status(500).json({ error: 'Erro ao buscar produtos' }); }
});

router.put('/produtos-epi-cadastro/:id', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { ca, fornecedor, tamanhos } = req.body;
    const produto = await db('produtos_epi').where('id', req.params.id).where('tenant_id', req.user.tenant_id).first();
    if (!produto) return res.status(404).json({ error: 'Produto não encontrado' });
    const updateData = { data_atualizacao: new Date() };
    if (ca !== undefined) updateData.ca = ca;
    if (fornecedor !== undefined) updateData.fornecedor = fornecedor;
    if (tamanhos !== undefined) updateData.tamanhos = JSON.stringify(tamanhos);
    await db('produtos_epi').where('id', req.params.id).update(updateData);
    res.json({ success: true, message: 'Produto atualizado!' });
  } catch (err) { console.error('❌ Erro atualizar produto:', err); res.status(500).json({ error: 'Erro ao atualizar' }); }
});

router.post('/produtos-epi-cadastro', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { nome, id_produto_ixc, descricao_ixc, ca, fornecedor, tamanhos } = req.body;
    if (!nome) return res.status(400).json({ error: 'Nome obrigatório' });
    const existe = await db('produtos_epi').where('tenant_id', req.user.tenant_id).where('nome', nome).first();
    if (existe) return res.status(400).json({ error: 'Produto já cadastrado' });
    const [inserted] = await db('produtos_epi').insert({
      tenant_id: req.user.tenant_id, nome, id_produto_ixc: id_produto_ixc || null,
      descricao_ixc: descricao_ixc || null, ca: ca || 'N/A', fornecedor: fornecedor || '',
      tamanhos: tamanhos ? JSON.stringify(tamanhos) : null,
    }).returning('*');
    res.status(201).json({ success: true, message: 'Produto cadastrado!', produto: inserted });
  } catch (err) { console.error('❌ Erro cadastrar produto:', err); res.status(500).json({ error: 'Erro ao cadastrar' }); }
});

router.delete('/produtos-epi-cadastro/:id', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    await db('produtos_epi').where('id', req.params.id).where('tenant_id', req.user.tenant_id).update({ ativo: false, data_atualizacao: new Date() });
    res.json({ success: true, message: 'Produto removido!' });
  } catch (err) { res.status(500).json({ error: 'Erro ao remover' }); }
});

// GET /api/seguranca/epis-duplicados — verifica quais EPIs o técnico já tem
router.get('/epis-duplicados', authMiddleware, async (req, res) => {
  try {
    const reqsAtivas = await db('requisicoes_epi')
      .where('tecnico_id', req.user.id)
      .where('tenant_id', req.user.tenant_id)
      .whereIn('status', ['aprovada', 'aguardando_confirmacao', 'concluida'])
      .select('id', 'epis_solicitados', 'data_entrega', 'data_resposta');

    const episAtivos = {};
    for (const r of reqsAtivas) {
      const epis = Array.isArray(r.epis_solicitados) ? r.epis_solicitados : JSON.parse(r.epis_solicitados || '[]');
      for (const epi of epis) {
        const nomeLimpo = epi.replace(/\s*\(Tam\.\s*\w+\)/, '').replace(/\s*x\d+$/, '').trim();
        // Verifica se já tem devolução aprovada para este item
        const devolvido = await db('devolucoes_epi')
          .where('requisicao_original_id', r.id)
          .where('epi_nome', epi)
          .where('status', 'aprovada')
          .first();
        if (!devolvido) {
          episAtivos[nomeLimpo] = { requisicao_id: r.id, epi_completo: epi, data: r.data_entrega || r.data_resposta };
        }
      }
    }
    res.json({ epis_ativos: episAtivos });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao verificar EPIs' }); }
});

// POST /api/seguranca/devolucoes — técnico assina devolução de EPI
router.post('/devolucoes', authMiddleware, async (req, res) => {
  try {
    const { requisicao_original_id, epi_nome, assinatura_base64 } = req.body;
    if (!requisicao_original_id || !epi_nome) return res.status(400).json({ error: 'Dados obrigatórios' });
    if (!assinatura_base64) return res.status(400).json({ error: 'Assinatura obrigatória' });

    // Verifica se já existe devolução pendente
    const existe = await db('devolucoes_epi')
      .where('requisicao_original_id', requisicao_original_id)
      .where('epi_nome', epi_nome)
      .whereIn('status', ['pendente', 'aprovada'])
      .first();
    if (existe) return res.status(400).json({ error: 'Devolução já registrada para este item' });

    const [inserted] = await db('devolucoes_epi').insert({
      tenant_id: req.user.tenant_id,
      tecnico_id: req.user.id,
      requisicao_original_id,
      epi_nome,
      status: 'pendente',
      assinatura_devolucao: assinatura_base64,
      data_devolucao: new Date(),
    }).returning('*');

    res.status(201).json({ success: true, message: 'Devolução registrada! Aguardando aprovação do gestor.', id: inserted.id });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao registrar devolução' }); }
});

// GET /api/seguranca/devolucoes/pendentes — gestor vê devoluções pendentes
router.get('/devolucoes/pendentes', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const lista = await db('devolucoes_epi as d')
      .join('usuarios as t', 't.id', 'd.tecnico_id')
      .join('requisicoes_epi as r', 'r.id', 'd.requisicao_original_id')
      .where('d.tenant_id', req.user.tenant_id)
      .where('d.status', 'pendente')
      .select('d.*', 't.nome as tecnico_nome', 'r.data_entrega as data_entrega_original')
      .orderBy('d.data_criacao', 'asc');
    res.json({ devolucoes: lista });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao buscar devoluções' }); }
});

// POST /api/seguranca/devolucoes/:id/aprovar — gestor aprova devolução
router.post('/devolucoes/:id/aprovar', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { codigo_subst } = req.body;
    if (!codigo_subst) return res.status(400).json({ error: 'Código de substituição obrigatório' });

    const devolucao = await db('devolucoes_epi').where('id', req.params.id).where('tenant_id', req.user.tenant_id).first();
    if (!devolucao) return res.status(404).json({ error: 'Devolução não encontrada' });
    if (devolucao.status !== 'pendente') return res.status(400).json({ error: 'Devolução já processada' });

    await db('devolucoes_epi').where('id', req.params.id).update({
      status: 'aprovada',
      codigo_subst,
      gestor_id: req.user.id,
      data_resposta: new Date(),
    });

    // Atualiza o campo devolucoes na requisição original (para o PDF da ficha)
    const reqOriginal = await db('requisicoes_epi').where('id', devolucao.requisicao_original_id).first();
    if (reqOriginal) {
      let devolucoes = reqOriginal.devolucoes ? (Array.isArray(reqOriginal.devolucoes) ? reqOriginal.devolucoes : JSON.parse(reqOriginal.devolucoes || '[]')) : [];
      // Remove entrada anterior do mesmo EPI se existir
      devolucoes = devolucoes.filter(d => d.epi !== devolucao.epi_nome);
      // Adiciona nova
      devolucoes.push({
        epi: devolucao.epi_nome,
        codigo_subst,
        data_devolucao: formatarDataBR(devolucao.data_devolucao || new Date(), false),
        assinatura_devolucao: devolucao.assinatura_devolucao,
      });
      await db('requisicoes_epi').where('id', devolucao.requisicao_original_id).update({
        devolucoes: JSON.stringify(devolucoes),
      });
    }

    res.json({ success: true, message: 'Devolução aprovada!' });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao aprovar devolução' }); }
});

// POST /api/seguranca/devolucoes/:id/recusar — gestor recusa (devedor)
router.post('/devolucoes/:id/recusar', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { observacao } = req.body;

    await db('devolucoes_epi').where('id', req.params.id).where('tenant_id', req.user.tenant_id).update({
      status: 'recusada',
      gestor_id: req.user.id,
      observacao_gestor: observacao || 'Devolução não confirmada pelo gestor.',
      data_resposta: new Date(),
    });

    res.json({ success: true, message: 'Devolução recusada. Técnico marcado como devedor.' });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao recusar' }); }
});

// GET /api/seguranca/devolucoes/devedores — lista técnicos devedores
router.get('/devolucoes/devedores', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const lista = await db('devolucoes_epi as d')
      .join('usuarios as t', 't.id', 'd.tecnico_id')
      .leftJoin('usuarios as g', 'g.id', 'd.gestor_id')
      .where('d.tenant_id', req.user.tenant_id)
      .where('d.status', 'recusada')
      .select('d.*', 't.nome as tecnico_nome', 'g.nome as gestor_nome')
      .orderBy('d.data_resposta', 'desc');
    res.json({ devedores: lista });
  } catch (err) { console.error(err); res.status(500).json({ error: 'Erro ao buscar devedores' }); }
});

// GET /api/seguranca/devolucoes/minhas — técnico vê suas devoluções
router.get('/devolucoes/minhas', authMiddleware, async (req, res) => {
  try {
    const lista = await db('devolucoes_epi')
      .where('tecnico_id', req.user.id)
      .where('tenant_id', req.user.tenant_id)
      .orderBy('data_criacao', 'desc');
    res.json({ devolucoes: lista });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar devoluções' }); }
});

router.get('/perfil', authMiddleware, async (req, res) => {
  try {
    const usuario = await db('usuarios').where('id', req.user.id)
      .select('id', 'nome', 'email', 'tipo_usuario', 'foto_perfil', 'assinatura_admissao', 'data_criacao').first();
    const tenant = await db('tenants').where('id', req.user.tenant_id).first();
    const stats = await db('requisicoes_epi').where('tecnico_id', req.user.id).where('tenant_id', req.user.tenant_id)
      .select(db.raw('COUNT(*) as total'), db.raw("COUNT(*) FILTER (WHERE status = 'aprovada') as aprovadas"),
        db.raw("COUNT(*) FILTER (WHERE status = 'pendente') as pendentes"),
        db.raw("COUNT(*) FILTER (WHERE status = 'recusada') as recusadas")).first();
    res.json({ usuario: { ...usuario, empresa: tenant?.nome }, stats });
  } catch (err) { res.status(500).json({ error: 'Erro ao buscar perfil' }); }
});

router.put('/perfil/foto', authMiddleware, async (req, res) => {
  try {
    const { foto_base64 } = req.body;
    if (!foto_base64) return res.status(400).json({ error: 'Foto obrigatória' });
    await db('usuarios').where('id', req.user.id).update({ foto_perfil: foto_base64 });
    res.json({ success: true, message: 'Foto atualizada!' });
  } catch (err) { res.status(500).json({ error: 'Erro ao atualizar foto' }); }
});

router.get('/relatorio-epi/:tecnico_id', authMiddleware, async (req, res) => {
  try {
    if (!isGestorOuAdmin(req.user.tipo_usuario)) return res.status(403).json({ error: 'Sem permissão' });
    const { tecnico_id } = req.params;
    const { mes, ano } = req.query;
    const tenantId = req.user.tenant_id;

    const tecnico = await db('usuarios').where('id', tecnico_id).first();
    if (!tecnico) return res.status(404).json({ error: 'Técnico não encontrado' });

    let query = db('requisicoes_epi')
      .where('tecnico_id', tecnico_id)
      .where('tenant_id', tenantId)
      .whereIn('status', ['concluida', 'aprovada', 'aguardando_confirmacao'])
      .orderBy('data_criacao', 'desc');

    if (ano) query = query.whereRaw('EXTRACT(YEAR FROM data_criacao) = ?', [ano]);
    if (mes) query = query.whereRaw('EXTRACT(MONTH FROM data_criacao) = ?', [mes]);

    const requisicoes = await query;
    const produtosEpi = await db('produtos_epi').where('tenant_id', tenantId).where('ativo', true);
    const tenant = await db('tenants').where('id', tenantId).first();

    // Adiciona label do período no título
    const meses = ['','Janeiro','Fevereiro','Março','Abril','Maio','Junho',
      'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    const periodoLabel = mes && ano ? `${meses[parseInt(mes)]} ${ano}` : ano ? `Ano ${ano}` : 'Histórico Completo';

    // Usa gerarFichaEPI já existente, passando as requisições filtradas
    const pdfBuffer = await gerarFichaEPI(
      { ...tecnico, _periodoLabel: periodoLabel },
      requisicoes,
      produtosEpi,
      tenant
    );

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=EPI_${tecnico.nome.replace(/ /g, '_')}_${periodoLabel.replace(/ /g, '_')}.pdf`);
    res.send(pdfBuffer);
  } catch (err) {
    console.error('❌ Erro relatorio EPI:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;