// src/services/OSPdfService.js
// Gera PDF de OS no padrão do relatório IXC (Chamado Técnico)
const PDFDocument = require('pdfkit');
const { db } = require('../config/database');

const MARGEM   = 40;
const LARGURA  = 515; // A4 595 - 2*40
const COR_AZUL = '#1a3a5c';
const COR_CINZA_ESCURO = '#333333';
const COR_CINZA = '#666666';
const COR_CINZA_CLARO = '#eeeeee';
const COR_LINHA = '#cccccc';

class OSPdfService {

  static async gerarPdfOS(osId, tenantId) {
    // ── 1. Buscar dados da OS ──────────────────────────────────
    const os = await db('ordem_servico as o')
      .join('usuarios as u', 'u.id', 'o.tecnico_id')
      .where('o.id', osId)
      .where('o.tenant_id', tenantId)
      .select('o.*', 'u.nome as tecnico_nome')
      .first();

    if (!os) throw new Error('OS não encontrada');

    // ── 2. Buscar tenant/empresa ───────────────────────────────
    const tenant = await db('tenants').where('id', tenantId).first();

    // ── 3. Buscar itens de estoque salvos na OS ────────────────
    // Os itens ficam no campo dados_ixc ou podemos buscar do IXC
    // Usamos os dados que foram enviados na finalização
    const dadosIxc = os.dados_ixc ? JSON.parse(os.dados_ixc) : {};

    return await this._criarPdf(os, tenant, dadosIxc);
  }

  // ── Gera PDF a partir de dados diretos (chamado durante finalização) ──
  static async gerarPdfOSDireto(os, dados, tecnicoNome, tenantId) {
    const tenant = await db('tenants').where('id', tenantId).first();
    return await this._criarPdf(os, tenant, dados, tecnicoNome);
  }

  static _linha(doc, y, cor = COR_LINHA, espessura = 0.5) {
    doc.moveTo(MARGEM, y).lineTo(MARGEM + LARGURA, y)
       .lineWidth(espessura).strokeColor(cor).stroke();
    return y;
  }

  static _caixaTexto(doc, label, valor, x, y, largLabel, largValor) {
    doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA)
       .text(label, x, y, { width: largLabel });
    doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
       .text(valor || '', x + largLabel, y, { width: largValor });
  }

  static async _criarPdf(os, tenant, dados, tecnicoNome) {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument({
          size: 'A4',
          margins: { top: MARGEM, bottom: MARGEM, left: MARGEM, right: MARGEM },
          info: {
            Title: `Chamado Técnico ${os.numero_os}`,
            Author: tenant?.nome || 'SeeNet'
          }
        });

        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end',  () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        const tecnico = tecnicoNome || os.tecnico_nome || 'Técnico';
        const nomeEmpresa = tenant?.nome || 'BBnet Up';
        let y = MARGEM;

        // ── CABEÇALHO ──────────────────────────────────────────
        // Retângulo azul escuro no topo
        doc.rect(MARGEM - 10, 25, LARGURA + 20, 55).fill(COR_AZUL);

        // Nome da empresa (grande, branco)
        doc.fontSize(16).font('Helvetica-Bold').fillColor('white')
           .text(nomeEmpresa, MARGEM + 60, 32, { width: 260 });

        // Dados da empresa (pequeno, branco)
        const endEmpresa = tenant?.endereco || 'Rua João Pessoa, 104 - Centro';
        const telEmpresa = tenant?.telefone || '(79) 99976-4955';
        const emailEmpresa = tenant?.email || 'financeirobbnet@gmail.com';

        doc.fontSize(7).font('Helvetica').fillColor('#cce0ff')
           .text(`${endEmpresa}`, MARGEM + 60, 51, { width: 260 })
           .text(`Tel: ${telEmpresa}   E-mail: ${emailEmpresa}`, MARGEM + 60, 60, { width: 260 });

        // Dados do lado direito
        const dataAbertura = os.data_abertura
          ? new Date(os.data_abertura).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'medium' })
          : '';
        const dataAgenda = os.data_agendamento
          ? new Date(os.data_agendamento).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })
          : '';

        doc.fontSize(7).font('Helvetica-Bold').fillColor('#90caf9')
           .text('Atendente:', MARGEM + 330, 35, { width: 80 });
        doc.fontSize(7).font('Helvetica').fillColor('white')
           .text(tecnico, MARGEM + 375, 35, { width: 130 });

        doc.fontSize(7).font('Helvetica-Bold').fillColor('#90caf9')
           .text('Data da abertura:', MARGEM + 330, 46, { width: 90 });
        doc.fontSize(7).font('Helvetica').fillColor('white')
           .text(dataAbertura, MARGEM + 420, 46, { width: 90 });

        if (dataAgenda) {
          doc.fontSize(7).font('Helvetica-Bold').fillColor('#90caf9')
             .text('Data agendada:', MARGEM + 330, 57, { width: 90 });
          doc.fontSize(7).font('Helvetica').fillColor('white')
             .text(dataAgenda, MARGEM + 420, 57, { width: 90 });
        }

        y = 90;

        // ── TÍTULO DA OS ──────────────────────────────────────
        doc.fontSize(12).font('Helvetica-Bold').fillColor(COR_AZUL)
           .text(
             `Chamado Técnico: N° ${os.numero_os || ''} - Protocolo Nº ${os.protocolo_ixc || os.numero_os || ''}`,
             MARGEM, y, { width: LARGURA, align: 'center' }
           );

        y += 18;
        this._linha(doc, y, COR_AZUL, 1);
        y += 6;

        // ── DADOS DO CLIENTE ──────────────────────────────────
        // Linha 1: Cliente + CPF
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Cliente:', MARGEM, y);
        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(os.cliente_nome || '', MARGEM + 38, y, { width: 270 });

        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA)
           .text('CNPJ/CPF:', MARGEM + 320, y);
        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text('', MARGEM + 362, y);

        y += 14;

        // Linha 2: Endereço
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Endereço:', MARGEM, y);
        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(os.cliente_endereco || '', MARGEM + 42, y, { width: LARGURA - 42 });
        y += 14;

        // Linha 3: Telefone
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Fone:', MARGEM, y);
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Celular:', MARGEM + 60, y);
        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(os.cliente_telefone || '', MARGEM + 90, y, { width: 120 });
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Comercial:', MARGEM + 230, y);
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Ramal:', MARGEM + 370, y);
        y += 14;

        this._linha(doc, y);
        y += 5;

        // ── INFO TÉCNICA ──────────────────────────────────────
        // Consultor | Marcado por
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Consultor:', MARGEM, y);
        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(tecnico, MARGEM + 42, y, { width: 140 });
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA)
           .text('Marcado Por:', MARGEM + 210, y);
        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(`${tecnico} ${dataAbertura}`, MARGEM + 262, y, { width: 200 });
        y += 14;

        // Origem | Forma de pagamento
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Origem da Visita:', MARGEM, y);
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA)
           .text('Forma de Pagamento:', MARGEM + 210, y);
        y += 14;

        // Assunto | Colaborador
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Melhor horário:', MARGEM, y);
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text('Assunto:', MARGEM + 140, y);
        doc.fontSize(7.5).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(os.tipo_servico || '', MARGEM + 170, y, { width: 200 });
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA)
           .text('Colaborador responsável:', MARGEM + 380, y);
        doc.fontSize(7.5).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(tecnico, MARGEM + 383, y + 9, { width: 130 });
        y += 22;

        this._linha(doc, y);
        y += 6;

        // ── ASSUNTO / OBSERVAÇÕES ─────────────────────────────
        doc.rect(MARGEM - 5, y - 2, LARGURA + 10, 16).fill(COR_CINZA_CLARO);
        this._linha(doc, y - 2, COR_LINHA);
        this._linha(doc, y + 14, COR_LINHA);
        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text('Assunto:', MARGEM, y + 2);
        y += 18;

        const assunto = os.observacoes || os.tipo_servico || '';
        if (assunto) {
          doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
             .text(assunto, MARGEM, y, { width: LARGURA });
          y += doc.heightOfString(assunto, { width: LARGURA, fontSize: 8 }) + 6;
        }
        y += 4;

        this._linha(doc, y);
        y += 6;

        // ── OBS. DO TÉCNICO ───────────────────────────────────
        doc.rect(MARGEM - 5, y - 2, LARGURA + 10, 16).fill(COR_CINZA_CLARO);
        this._linha(doc, y - 2, COR_LINHA);
        this._linha(doc, y + 14, COR_LINHA);
        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text('Obs. do Técnico:', MARGEM, y + 2);
        y += 20;

        const problema = dados.relato_problema || '';
        const solucao  = dados.relato_solucao  || '';
        const obsTexto = [
          problema ? `Problema: ${problema}` : '',
          solucao  ? `Solução: ${solucao}`   : '',
          dados.observacoes ? `Observações: ${dados.observacoes}` : ''
        ].filter(Boolean).join('\n\n') || 'Sem observações';

        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO)
           .text(obsTexto, MARGEM, y, { width: LARGURA });
        y += doc.heightOfString(obsTexto, { width: LARGURA, fontSize: 8 }) + 10;

        // ── PRODUTOS / COMODATOS ──────────────────────────────
        const itens = dados.itens_estoque || [];
        if (itens.length > 0) {
          if (y > 650) { doc.addPage(); y = MARGEM; }

          this._linha(doc, y, COR_AZUL, 1);
          y += 5;

          // Separa patrimônios de produtos normais
          const patrimonios = itens.filter(i => i.isPatrimonio || i.tipo_produto === 'P');
          const produtos     = itens.filter(i => !i.isPatrimonio && i.tipo_produto !== 'P');

          if (patrimonios.length > 0) {
            y = this._tabelaProdutos(doc, y, 'Comodatos', patrimonios);
          }
          if (produtos.length > 0) {
            y = this._tabelaProdutos(doc, y, 'Produtos Utilizados', produtos);
          }
        }

        // ── MENSAGENS / INTERAÇÕES ────────────────────────────
        if (y > 600) { doc.addPage(); y = MARGEM; }

        this._linha(doc, y, COR_AZUL, 1);
        y += 5;

        // Cabeçalho tabela
        doc.rect(MARGEM - 5, y, LARGURA + 10, 16).fill('#dce8f5');
        doc.fontSize(7.5).font('Helvetica-Bold').fillColor(COR_AZUL)
           .text('Mensagens/Interações', MARGEM, y + 4, { width: LARGURA, align: 'center' });
        y += 18;

        // Header das colunas
        doc.rect(MARGEM - 5, y, LARGURA + 10, 14).fill(COR_CINZA_CLARO);
        this._linha(doc, y, COR_LINHA);
        this._linha(doc, y + 14, COR_LINHA);

        const c1 = 100, c2 = 90, c3 = 80;
        const c4 = LARGURA - c1 - c2 - c3;
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text('Data/Hora',   MARGEM,            y + 3, { width: c1 })
           .text('Operador',    MARGEM + c1,        y + 3, { width: c2 })
           .text('Evento',      MARGEM + c1 + c2,   y + 3, { width: c3 })
           .text('Mensagem',    MARGEM + c1+c2+c3,  y + 3, { width: c4 });
        y += 16;

        // Linhas de mensagens
        const agora = new Date().toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'medium' });
        const mensagens = [
          {
            data: new Date(os.data_abertura || Date.now()).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'medium' }),
            operador: 'Sistema',
            evento: 'Abertura',
            mensagem: os.tipo_servico || 'OS criada'
          },
          {
            data: agora,
            operador: tecnico,
            evento: 'Execução',
            mensagem: problema ? `Problema: ${problema.substring(0, 100)}` : 'OS executada'
          },
          {
            data: agora,
            operador: tecnico,
            evento: 'Fechamento',
            mensagem: solucao ? solucao.substring(0, 120) : 'OS finalizada'
          }
        ];

        mensagens.forEach((msg, idx) => {
          if (y > 700) { doc.addPage(); y = MARGEM; }

          const altMsg = Math.max(
            doc.heightOfString(msg.mensagem, { width: c4, fontSize: 7 }) + 6,
            14
          );

          if (idx % 2 === 1) {
            doc.rect(MARGEM - 5, y, LARGURA + 10, altMsg).fill('#f9f9f9');
          }
          this._linha(doc, y + altMsg, COR_LINHA, 0.3);

          doc.fontSize(7).font('Helvetica').fillColor(COR_CINZA_ESCURO)
             .text(msg.data,      MARGEM,           y + 3, { width: c1 })
             .text(msg.operador,  MARGEM + c1,       y + 3, { width: c2 })
             .text(msg.evento,    MARGEM + c1 + c2,  y + 3, { width: c3 })
             .text(msg.mensagem,  MARGEM + c1+c2+c3, y + 3, { width: c4 });

          y += altMsg;
        });

        y += 14;

        // ── ASSINATURAS ───────────────────────────────────────
        if (y > 680) { doc.addPage(); y = MARGEM; }

        const assinLarg = 210;
        const assinAlt  = 60;
        const xTec     = MARGEM;
        const xCli     = MARGEM + LARGURA - assinLarg;

        // Box técnico
        doc.rect(xTec, y, assinLarg, assinAlt)
           .lineWidth(0.5).strokeColor(COR_LINHA).stroke();

        // Assinatura do técnico (se houver)
        if (os.assinatura_tecnico) {
          try {
            const buf = Buffer.from(os.assinatura_tecnico, 'base64');
            doc.image(buf, xTec + 5, y + 4, {
              fit: [assinLarg - 10, assinAlt - 8],
              align: 'center', valign: 'center'
            });
          } catch (_) {}
        }

        // Box cliente com assinatura
        doc.rect(xCli, y, assinLarg, assinAlt)
           .lineWidth(0.5).strokeColor(COR_LINHA).stroke();

        if (dados.assinatura) {
          try {
            const buf = Buffer.from(dados.assinatura, 'base64');
            doc.rect(xCli + 1, y + 1, assinLarg - 2, assinAlt - 2).fill('white');
            doc.image(buf, xCli + 5, y + 4, {
              fit: [assinLarg - 10, assinAlt - 8],
              align: 'center', valign: 'center'
            });
          } catch (_) {}
        }

        const legY = y + assinAlt + 4;

        // Labels
        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text(tecnico.toUpperCase(), xTec, legY,
                 { width: assinLarg, align: 'center' });
        doc.fontSize(7).font('Helvetica').fillColor(COR_CINZA)
           .text('COLABORADOR RESPONSÁVEL', xTec, legY + 10,
                 { width: assinLarg, align: 'center' });

        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text((os.cliente_nome || 'CLIENTE').toUpperCase(), xCli, legY,
                 { width: assinLarg, align: 'center' });
        doc.fontSize(7).font('Helvetica').fillColor(COR_CINZA)
           .text('CLIENTE', xCli, legY + 10,
                 { width: assinLarg, align: 'center' });

        // ── RODAPÉ ────────────────────────────────────────────
        const rodapeY = doc.page.height - 30;
        this._linha(doc, rodapeY - 6, COR_LINHA);
        doc.fontSize(6.5).font('Helvetica').fillColor(COR_CINZA)
           .text(
             `Documento gerado em ${agora} · SeeNet – Sistema de Gestão · ${nomeEmpresa}`,
             MARGEM, rodapeY, { width: LARGURA, align: 'center' }
           );

        doc.end();
      } catch (err) {
        reject(err);
      }
    });
  }

  // ── Renderiza tabela de produtos/comodatos ──────────────────
  static _tabelaProdutos(doc, y, titulo, itens) {
    // Título da seção
    doc.rect(MARGEM - 5, y, LARGURA + 10, 16).fill('#dce8f5');
    doc.fontSize(7.5).font('Helvetica-Bold').fillColor(COR_AZUL)
       .text(titulo, MARGEM, y + 4, { width: LARGURA, align: 'center' });
    y += 18;

    // Header
    const cID   = 40;
    const cDesc = LARGURA - cID - 70 - 60 - 70;
    const cUnit = 70;
    const cQtd  = 60;
    const cTot  = 70;

    doc.rect(MARGEM - 5, y, LARGURA + 10, 14).fill(COR_CINZA_CLARO);
    this._linha(doc, y + 14, COR_LINHA, 0.5);
    doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
       .text('ID',          MARGEM,                       y + 3, { width: cID })
       .text('Descrição',   MARGEM + cID,                 y + 3, { width: cDesc })
       .text('Valor Unit.', MARGEM + cID + cDesc,         y + 3, { width: cUnit, align: 'right' })
       .text('Quantidade',  MARGEM + cID + cDesc + cUnit, y + 3, { width: cQtd,  align: 'right' })
       .text('Valor Total', MARGEM + cID + cDesc + cUnit + cQtd, y + 3, { width: cTot, align: 'right' });
    y += 16;

    let totalGeral = 0;

    itens.forEach((item, idx) => {
      const alt = 14;
      if (idx % 2 === 1) {
        doc.rect(MARGEM - 5, y, LARGURA + 10, alt).fill('#f9f9f9');
      }
      this._linha(doc, y + alt, COR_LINHA, 0.3);

      const vUnit = parseFloat(item.valor_unitario || 0).toFixed(2);
      const qtd   = parseFloat(item.quantidade || 0).toFixed(2);
      const vTot  = parseFloat(item.valor_total || 0).toFixed(2);
      totalGeral += parseFloat(vTot);

      doc.fontSize(7.5).font('Helvetica').fillColor(COR_CINZA_ESCURO)
         .text(item.id_produto || '',  MARGEM,                       y + 3, { width: cID })
         .text(item.descricao  || '',  MARGEM + cID,                 y + 3, { width: cDesc })
         .text(vUnit,                  MARGEM + cID + cDesc,         y + 3, { width: cUnit, align: 'right' })
         .text(qtd,                    MARGEM + cID + cDesc + cUnit, y + 3, { width: cQtd,  align: 'right' })
         .text(vTot,                   MARGEM + cID + cDesc + cUnit + cQtd, y + 3, { width: cTot, align: 'right' });
      y += alt;
    });

    // Linha total
    doc.rect(MARGEM - 5, y, LARGURA + 10, 16).fill(COR_CINZA_CLARO);
    doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
       .text('Total:', MARGEM + cID + cDesc + cUnit, y + 4,
             { width: cQtd, align: 'right' })
       .text(totalGeral.toFixed(2), MARGEM + cID + cDesc + cUnit + cQtd, y + 4,
             { width: cTot, align: 'right' });
    y += 20;

    return y;
  }
}

module.exports = OSPdfService;