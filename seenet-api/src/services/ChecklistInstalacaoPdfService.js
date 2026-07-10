// src/services/ChecklistInstalacaoPdfService.js
// PDF do checklist de fechamento da INSTALAÇÃO FTTH (assunto 60) — anexado ao
// campo de arquivos da OS no IXC junto com os demais arquivos.
const PDFDocument = require('pdfkit');
const { db } = require('../config/database');

const MARGEM  = 40;
const LARGURA = 515;
const COR_AZUL   = '#1a3a5c';
const COR_ESCURO = '#333333';
const COR_CINZA  = '#666666';
const COR_VERDE  = '#0a7d3c';
const COR_VERM   = '#b3261e';
const COR_LINHA  = '#cccccc';

class ChecklistInstalacaoPdfService {

  static async gerar(os, chk, tecnicoNome, tenantId) {
    let tenant = null;
    try { tenant = await db('tenants').where('id', tenantId).first(); } catch (_) {}
    return this._criar(os, chk, tecnicoNome || 'Técnico', tenant);
  }

  static _criar(os, chk, tecnicoNome, tenant) {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument({
          size: 'A4',
          margins: { top: MARGEM, bottom: MARGEM, left: MARGEM, right: MARGEM },
          info: {
            Title: `Checklist Instalação OS ${os.numero_os}`,
            Author: tenant?.nome || 'SeeNet',
          },
        });

        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end',  () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        const nomeEmpresa = tenant?.nome || 'BBnet Up';
        const agora = new Date().toLocaleString('pt-BR',
          { dateStyle: 'short', timeStyle: 'short' });

        // Cabeçalho
        doc.rect(MARGEM, MARGEM, LARGURA, 46).fill(COR_AZUL);
        doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(15)
           .text('CHECKLIST DE INSTALAÇÃO FTTH', MARGEM + 14, MARGEM + 9);
        doc.font('Helvetica').fontSize(9)
           .text(nomeEmpresa, MARGEM + 14, MARGEM + 29);

        let y = MARGEM + 66;

        // Dados da OS
        doc.fillColor(COR_ESCURO).font('Helvetica-Bold').fontSize(10);
        doc.text(`OS Nº ${os.numero_os}`, MARGEM, y);
        doc.font('Helvetica').fillColor(COR_CINZA).fontSize(9);
        doc.text(`Cliente: ${os.cliente_nome || 'N/A'}`, MARGEM, y + 16);
        doc.text(`Técnico: ${tecnicoNome}`, MARGEM, y + 30);
        doc.text(`Data/hora: ${agora}`, MARGEM, y + 44);
        y += 70;

        this._linha(doc, y); y += 14;

        // Item 1 — Atendido por (texto)
        doc.font('Helvetica-Bold').fillColor(COR_ESCURO).fontSize(10)
           .text('1 - ATENDIDO POR:', MARGEM, y);
        doc.font('Helvetica').fillColor(COR_ESCURO)
           .text(chk.atendido_por || '—', MARGEM + 130, y);
        y += 24;

        // Itens SIM/NÃO
        const itens = [
          ['4 - HABILITOU ACESSO REMOTO', chk.acesso_remoto],
          ['5 - MUDOU SENHA PADRÃO',      chk.senha_padrao],
          ['6 - ATIVOU IPV6',             chk.ipv6],
          ['7 - CLIENTE ASSINA',          chk.cliente_assina],
        ];

        for (const [titulo, valor] of itens) {
          const sim = !!valor;
          doc.font('Helvetica-Bold').fillColor(COR_ESCURO).fontSize(10)
             .text(`${titulo}:`, MARGEM, y, { width: 300 });

          // (X) SIM
          doc.font('Helvetica-Bold').fontSize(10);
          doc.fillColor(sim ? COR_VERDE : COR_CINZA)
             .text(`( ${sim ? 'X' : ' '} ) SIM`, MARGEM + 320, y);
          // (X) NÃO
          doc.fillColor(!sim ? COR_VERM : COR_CINZA)
             .text(`( ${!sim ? 'X' : ' '} ) NÃO`, MARGEM + 420, y);
          y += 22;
        }

        y += 6;
        this._linha(doc, y); y += 16;

        doc.font('Helvetica-Oblique').fillColor(COR_CINZA).fontSize(8)
           .text('Documento gerado automaticamente no fechamento da OS via SeeNet.',
                 MARGEM, y, { width: LARGURA });

        doc.end();
      } catch (e) {
        reject(e);
      }
    });
  }

  static _linha(doc, y) {
    doc.moveTo(MARGEM, y).lineTo(MARGEM + LARGURA, y)
       .lineWidth(0.5).strokeColor(COR_LINHA).stroke();
  }
}

module.exports = ChecklistInstalacaoPdfService;
