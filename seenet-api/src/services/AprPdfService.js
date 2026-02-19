// src/services/AprPdfService.js
const PDFDocument = require('pdfkit');
const { db } = require('../config/database');

// ─── Cores ───────────────────────────────────────────────────────────────────
const COR_PRIMARIA   = '#1A237E';
const COR_SECUNDARIA = '#283593';
const COR_ACENTO     = '#E53935';
const COR_HEADER_TAB = '#E8EAF6';
const COR_LINHA_PAR  = '#F5F5F5';
const COR_SIM        = '#2E7D32';
const COR_NAO        = '#C62828';
const COR_TEXTO      = '#212121';
const COR_SUBTEXTO   = '#616161';
const MARGEM         = 50;
const LARGURA        = 495;

class AprPdfService {

  static async gerarPdfApr(osId, tenantId) {
    try {
      const os = await db('ordem_servico as o')
        .join('usuarios as u', 'u.id', 'o.tecnico_id')
        .where('o.id', osId)
        .where('o.tenant_id', tenantId)
        .select('o.*', 'u.nome as tecnico_nome')
        .first();

      if (!os) throw new Error('OS não encontrada');

      const respostas = await db.raw(`
        SELECT
          c.id   AS categoria_id,
          c.nome AS categoria_nome,
          c.ordem AS categoria_ordem,
          p.pergunta,
          p.tipo_resposta,
          r.resposta,
          r.justificativa,
          p.ordem AS pergunta_ordem
        FROM respostas_apr r
        INNER JOIN checklist_perguntas_apr p ON p.id = r.pergunta_id
        INNER JOIN checklist_categorias_apr c ON c.id = p.categoria_id
        WHERE r.ordem_servico_id = ?
        ORDER BY c.ordem, p.ordem
      `, [osId]);

      if (respostas.rows.length === 0)
        throw new Error('APR não preenchido para esta OS');

      const epis = await db.raw(`
        SELECT o.opcao
        FROM respostas_apr_epis re
        INNER JOIN checklist_opcoes_apr o ON o.id = re.opcao_id
        INNER JOIN respostas_apr r       ON r.id  = re.resposta_apr_id
        WHERE r.ordem_servico_id = ?
        ORDER BY o.ordem
      `, [osId]);

      const assinaturaRow = await db('ordem_servico')
        .where('id', osId)
        .select('assinatura_cliente')
        .first();

      const assinaturaBase64 = assinaturaRow ? assinaturaRow.assinatura_cliente : null;

      const categorias = {};
      respostas.rows.forEach(r => {
        if (!categorias[r.categoria_id]) {
          categorias[r.categoria_id] = {
            nome: r.categoria_nome,
            ordem: r.categoria_ordem,
            perguntas: []
          };
        }
        categorias[r.categoria_id].perguntas.push({
          pergunta: r.pergunta,
          tipo: r.tipo_resposta,
          resposta: r.resposta,
          justificativa: r.justificativa
        });
      });

      return await this._criarPdf(os, categorias, epis.rows, assinaturaBase64);

    } catch (error) {
      console.error('❌ Erro ao gerar PDF APR:', error);
      throw error;
    }
  }

  static _hr(doc, y, cor = '#CCCCCC', espessura = 0.5) {
    doc.moveTo(MARGEM, y)
       .lineTo(MARGEM + LARGURA, y)
       .lineWidth(espessura)
       .strokeColor(cor)
       .stroke();
  }

  static _sectionHeader(doc, texto, y) {
    doc.rect(MARGEM, y, LARGURA, 18).fill(COR_SECUNDARIA);
    doc.fontSize(9).font('Helvetica-Bold')
       .fillColor('white')
       .text(texto.toUpperCase(), MARGEM + 6, y + 4, { width: LARGURA - 12 });
    return y + 18;
  }

  static _tableRow(doc, questao, resposta, yPos, isEven) {
    const colQ = LARGURA * 0.68;
    const colR = LARGURA * 0.32;

    const alturaQ = doc.heightOfString(questao,  { width: colQ - 10, fontSize: 8 });
    const alturaR = doc.heightOfString(resposta, { width: colR - 10, fontSize: 8 });
    const altura  = Math.max(alturaQ, alturaR) + 10;

    if (isEven) {
      doc.rect(MARGEM, yPos, LARGURA, altura).fill(COR_LINHA_PAR);
    }

    doc.rect(MARGEM, yPos, LARGURA, altura)
       .lineWidth(0.3).strokeColor('#BDBDBD').stroke();

    doc.moveTo(MARGEM + colQ, yPos)
       .lineTo(MARGEM + colQ, yPos + altura)
       .lineWidth(0.3).strokeColor('#BDBDBD').stroke();

    doc.fontSize(8).font('Helvetica').fillColor(COR_TEXTO)
       .text(questao, MARGEM + 5, yPos + 5, { width: colQ - 10 });

    let corResp  = COR_TEXTO;
    let fontResp = 'Helvetica';
    const upper  = resposta.toUpperCase();
    if (upper === 'SIM')                        { corResp = COR_SIM; fontResp = 'Helvetica-Bold'; }
    if (upper === 'NÃO' || upper === 'NAO' ||
        upper.startsWith('NÃO\n') || upper.startsWith('NAO\n'))
                                                 { corResp = COR_NAO; fontResp = 'Helvetica-Bold'; }

    doc.fontSize(8).font(fontResp).fillColor(corResp)
       .text(resposta, MARGEM + colQ + 5, yPos + 5, { width: colR - 10 });

    return yPos + altura;
  }

  static async _criarPdf(os, categorias, epis, assinaturaBase64 = null) {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument({
          size: 'A4',
          margins: { top: MARGEM, bottom: MARGEM, left: MARGEM, right: MARGEM },
          info: { Title: `APR - OS ${os.numero_os}`, Author: 'SeeNet' }
        });

        const chunks = [];
        doc.on('data', chunk => chunks.push(chunk));
        doc.on('end',  ()    => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        // ── CABEÇALHO ──────────────────────────────────────────────────────
        doc.rect(MARGEM - 10, 30, LARGURA + 20, 70).fill(COR_PRIMARIA);

        doc.fontSize(16).font('Helvetica-Bold').fillColor('white')
           .text('APR – ANÁLISE PRELIMINAR DE RISCO', MARGEM, 42, {
             width: LARGURA, align: 'center'
           });

        doc.fontSize(10).font('Helvetica').fillColor('#CFD8DC')
           .text('BBnet Up Telecomunicações', MARGEM, 62, {
             width: LARGURA, align: 'center'
           });

        doc.fontSize(8).fillColor('#90CAF9')
           .text('CNPJ 23.870.928/0001-22  ·  (79) 99976-4955  ·  www.bbnetup.com', MARGEM, 76, {
             width: LARGURA, align: 'center'
           });

        // ── DADOS GERAIS ───────────────────────────────────────────────────
        let y = 115;
        y = this._sectionHeader(doc, 'Dados Gerais', y);

        const dataOS  = new Date(os.data_criacao).toLocaleDateString('pt-BR');
        const horaOS  = new Date(os.data_criacao).toLocaleTimeString('pt-BR', {
          hour: '2-digit', minute: '2-digit'
        });

        const dadosGerais = [
          ['Técnico',  os.tecnico_nome      || 'N/A', 'O.S.',      os.numero_os       || 'N/A'],
          ['Cliente',  os.cliente_nome      || 'N/A', 'Protocolo', os.protocolo_ixc   || 'N/A'],
          ['Endereço', os.cliente_endereco  || 'N/A', 'Data/Hora', `${dataOS} ${horaOS}`],
          ['Assunto',  os.assunto           || 'N/A', 'Status',    os.status_execucao || 'Aberta'],
        ];

        const cL = LARGURA * 0.15;
        const cV = LARGURA * 0.35;
        const cL2= LARGURA * 0.15;
        const cV2= LARGURA * 0.35;

        dadosGerais.forEach((linha, i) => {
          if (i % 2 === 0) doc.rect(MARGEM, y, LARGURA, 16).fill('#F5F5F5');
          doc.rect(MARGEM, y, LARGURA, 16).lineWidth(0.3).strokeColor('#BDBDBD').stroke();

          doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_SUBTEXTO)
             .text(linha[0] + ':', MARGEM + 5, y + 4, { width: cL });
          doc.fontSize(8).font('Helvetica').fillColor(COR_TEXTO)
             .text(linha[1], MARGEM + cL + 5, y + 4, { width: cV });
          doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_SUBTEXTO)
             .text(linha[2] + ':', MARGEM + cL + cV + 5, y + 4, { width: cL2 });
          doc.fontSize(8).font('Helvetica').fillColor(COR_TEXTO)
             .text(linha[3], MARGEM + cL + cV + cL2 + 5, y + 4, { width: cV2 });

          y += 16;
        });

        y += 10;

        // ── RESPOSTAS POR CATEGORIA ────────────────────────────────────────
        const categoriasOrdenadas = Object.values(categorias)
          .sort((a, b) => a.ordem - b.ordem);

        categoriasOrdenadas.forEach(cat => {
          if (y > 700) { doc.addPage(); y = MARGEM; }

          y = this._sectionHeader(doc, `${cat.ordem}. ${cat.nome}`, y);

          // Cabeçalho tabela
          doc.rect(MARGEM, y, LARGURA, 16).fill(COR_HEADER_TAB);
          doc.rect(MARGEM, y, LARGURA, 16).lineWidth(0.5).strokeColor('#9FA8DA').stroke();
          doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_SECUNDARIA)
             .text('QUESTÃO', MARGEM + 5, y + 4, { width: LARGURA * 0.68 - 10 });
          doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_SECUNDARIA)
             .text('RESPOSTA', MARGEM + LARGURA * 0.68 + 5, y + 4, { width: LARGURA * 0.32 - 10 });
          y += 16;

          cat.perguntas.forEach((perg, idx) => {
            if (y > 720) { doc.addPage(); y = MARGEM; }

            let respostaTexto = perg.resposta || '';
            if (perg.justificativa) {
              respostaTexto += `\n(${perg.justificativa})`;
            }

            y = this._tableRow(doc, perg.pergunta, respostaTexto, y, idx % 2 === 1);
          });

          y += 8;
        });

        // ── EPIs ───────────────────────────────────────────────────────────
        if (epis.length > 0) {
          if (y > 680) { doc.addPage(); y = MARGEM; }

          y = this._sectionHeader(doc, 'Equipamentos de Proteção Utilizados (EPIs / EPCs)', y);

          const colEpi  = 3;
          const largEpi = Math.floor(LARGURA / colEpi);
          let colAtual  = 0;
          let xEpi = MARGEM;
          let yEpi = y;

          epis.forEach((epi, idx) => {
            if (colAtual === colEpi) { colAtual = 0; xEpi = MARGEM; yEpi += 18; }
            if (yEpi > 720) { doc.addPage(); yEpi = MARGEM; }

            doc.rect(xEpi, yEpi, largEpi - 4, 16)
               .fill(idx % 2 === 0 ? COR_LINHA_PAR : 'white');
            doc.rect(xEpi, yEpi, largEpi - 4, 16)
               .lineWidth(0.3).strokeColor('#BDBDBD').stroke();
            doc.fontSize(7.5).font('Helvetica').fillColor(COR_TEXTO)
               .text(`✓  ${epi.opcao}`, xEpi + 5, yEpi + 4, { width: largEpi - 14 });

            xEpi += largEpi;
            colAtual++;
          });

          y = yEpi + 18 + 10;
        }

        // ── TERMO DE RESPONSABILIDADE ──────────────────────────────────────
        if (y > 650) { doc.addPage(); y = MARGEM; }

        doc.rect(MARGEM, y, LARGURA, 16).fill('#FFEBEE');
        doc.rect(MARGEM, y, LARGURA, 16).lineWidth(0.5).strokeColor(COR_ACENTO).stroke();
        doc.fontSize(9).font('Helvetica-Bold').fillColor(COR_ACENTO)
           .text('TERMO DE RESPONSABILIDADE', MARGEM + 5, y + 4);
        y += 22;

        doc.fontSize(8.5).font('Helvetica').fillColor(COR_TEXTO)
           .text(
             'Declaro que as informações acima são verdadeiras e que me responsabilizo pela ' +
             'execução segura deste serviço, atendendo às Normas Regulamentadoras NR-10 e NR-35, ' +
             'conforme legislação vigente.',
             MARGEM, y, { width: LARGURA, align: 'justify' }
           );

        y += 40;

        // ── ASSINATURAS ────────────────────────────────────────────────────
        if (y > 680) { doc.addPage(); y = MARGEM; }

        const assinLarg = 200;
        const assinAlt  = 58;
        const assinX    = MARGEM;
        const clienteX  = MARGEM + 280;

        // Box técnico
        doc.rect(assinX, y, assinLarg, assinAlt)
           .lineWidth(0.5).strokeColor('#BDBDBD').stroke();

        // Assinatura (PNG transparente → fundo branco antes da imagem)
        if (assinaturaBase64) {
          try {
            const buf = Buffer.from(assinaturaBase64, 'base64');
            doc.rect(assinX + 1, y + 1, assinLarg - 2, assinAlt - 2).fill('white');
            doc.image(buf, assinX + 5, y + 4, {
              fit:    [assinLarg - 10, assinAlt - 8],
              align:  'center',
              valign: 'center'
            });
          } catch (e) {
            console.error('⚠️ Erro ao inserir assinatura:', e.message);
          }
        }

        // Box cliente
        doc.rect(clienteX, y, assinLarg, assinAlt)
           .lineWidth(0.5).strokeColor('#BDBDBD').stroke();

        const legY = y + assinAlt + 4;

        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_TEXTO)
           .text(os.tecnico_nome || 'Técnico', assinX, legY, { width: assinLarg, align: 'center' });
        doc.fontSize(7).font('Helvetica').fillColor(COR_SUBTEXTO)
           .text('Colaborador Responsável', assinX, legY + 11, { width: assinLarg, align: 'center' });

        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_TEXTO)
           .text(os.cliente_nome || 'Cliente', clienteX, legY, { width: assinLarg, align: 'center' });
        doc.fontSize(7).font('Helvetica').fillColor(COR_SUBTEXTO)
           .text('Cliente', clienteX, legY + 11, { width: assinLarg, align: 'center' });

        // ── RODAPÉ ─────────────────────────────────────────────────────────
        this._hr(doc, 768, '#BDBDBD');
        doc.fontSize(7).font('Helvetica').fillColor(COR_SUBTEXTO)
           .text(
             `Documento gerado em ${new Date().toLocaleString('pt-BR')} · SeeNet – Sistema de Gestão · BBnet Up Telecomunicações`,
             MARGEM, 772,
             { width: LARGURA, align: 'center' }
           );

        doc.end();

      } catch (error) {
        reject(error);
      }
    });
  }
}

module.exports = AprPdfService;