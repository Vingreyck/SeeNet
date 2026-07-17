// src/services/OSPdfService.js
const PDFDocument = require('pdfkit');
const { db } = require('../config/database');

const MARGEM           = 40;
const LARGURA          = 515;
const COR_AZUL         = '#1a3a5c';
const COR_CINZA_ESCURO = '#333333';
const COR_CINZA        = '#666666';
const COR_CINZA_CLARO  = '#eeeeee';
const COR_LINHA        = '#cccccc';

class OSPdfService {

  static async gerarPdfOSDireto(os, dados, tecnicoNome, tenantId) {
    const tenant = await db('tenants').where('id', tenantId).first();

    const dadosIxc = os.dados_ixc
      ? (typeof os.dados_ixc === 'string' ? JSON.parse(os.dados_ixc) : os.dados_ixc)
      : {};

    let clienteIxc   = null;
    let mensagensIxc = [];

    try {
      const integracao = await db('integracao_ixc')
        .where('tenant_id', tenantId).where('ativo', true).first();

      if (integracao) {
        const IXCService = require('./IXCService');
        const ixc = new IXCService(integracao.url_api, integracao.token_api);

        if (os.cliente_id_externo) {
          try { clienteIxc = await ixc.buscarCliente(os.cliente_id_externo); } catch (_) {}
        }
        if (os.id_externo) {
          try { mensagensIxc = await ixc.buscarMensagensOS(os.id_externo); } catch (_) {}
        }
      }
    } catch (e) {
      console.warn('⚠️ PDF OS: erro ao buscar dados IXC:', e.message);
    }

    return await this._criarPdf(os, tenant, dados, tecnicoNome, dadosIxc, clienteIxc, mensagensIxc);
  }

  static _linha(doc, y, cor = COR_LINHA, esp = 0.5) {
    doc.moveTo(MARGEM, y).lineTo(MARGEM + LARGURA, y)
       .lineWidth(esp).strokeColor(cor).stroke();
  }

  static async _criarPdf(os, tenant, dados, tecnicoNome, dadosIxc, clienteIxc, mensagensIxc) {
    return new Promise((resolve, reject) => {
      try {
        const doc = new PDFDocument({
          size: 'A4',
          margins: { top: MARGEM, bottom: MARGEM, left: MARGEM, right: MARGEM },
          info: { Title: `Chamado Técnico ${os.numero_os}`, Author: tenant?.nome || 'SeeNet' }
        });

        const chunks = [];
        doc.on('data', c => chunks.push(c));
        doc.on('end',  () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);

        const tecnico     = tecnicoNome || os.tecnico_nome || 'Técnico';
        const nomeEmpresa = tenant?.nome || 'BBnet Up';

        // Campos extras do cliente
        const cpfCnpj     = clienteIxc?.cnpj_cpf   || clienteIxc?.cpf_cnpj || '';
        const complemento = dadosIxc?.complemento  || clienteIxc?.complemento || '';
        const cidade      = dadosIxc?.cidade        || clienteIxc?.cidade || '';
        const cep         = dadosIxc?.cep           || clienteIxc?.cep || '';
        const email       = clienteIxc?.email       || '';
        const login       = dadosIxc?.login         || clienteIxc?.login || '';
        const senha1      = dadosIxc?.senha_acesso  || dadosIxc?.senha_1 || clienteIxc?.senha_acesso || '';
        const senha2      = dadosIxc?.senha_acesso_2 || dadosIxc?.senha_2 || '';
        const senhaWifi   = dadosIxc?.ssid          || dadosIxc?.senha_wifi || clienteIxc?.ssid || '';

        // Assunto: usa descrição do IXC se existir, senão tipo_servico
        const assuntoTexto = dadosIxc?.mensagem && String(dadosIxc.mensagem).trim() !== ''
          ? String(dadosIxc.mensagem)
          : (os.tipo_servico || '');

        const dataAbertura = os.data_abertura
          ? new Date(os.data_abertura).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'medium' })
          : '';
        const dataAgenda = os.data_agendamento
          ? new Date(os.data_agendamento).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })
          : '';
        const agora = new Date().toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'medium' });

        const _L = (txt, x, y, w = 45) =>
          doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA).text(txt, x, y, { width: w });
        const _V = (txt, x, y, w = 200) =>
          doc.fontSize(7.5).font('Helvetica').fillColor(COR_CINZA_ESCURO).text(txt || '', x, y, { width: w });

        let y = MARGEM;

        // ── CABEÇALHO ─────────────────────────────────────────
        doc.rect(MARGEM - 10, 25, LARGURA + 20, 55).fill(COR_AZUL);
        doc.fontSize(16).font('Helvetica-Bold').fillColor('white')
           .text(nomeEmpresa, MARGEM + 60, 32, { width: 260 });
        doc.fontSize(7).font('Helvetica').fillColor('#cce0ff')
           .text(tenant?.endereco || 'Rua João Pessoa, 104 - Centro', MARGEM + 60, 51, { width: 260 })
           .text(`Tel: ${tenant?.telefone || '(79) 99976-4955'}   E-mail: ${tenant?.email || 'financeirobbnet@gmail.com'}`, MARGEM + 60, 60, { width: 260 });

        doc.fontSize(7).font('Helvetica-Bold').fillColor('#90caf9').text('Atendente:',       MARGEM + 330, 35, { width: 80 });
        doc.fontSize(7).font('Helvetica').fillColor('white').text(tecnico,                   MARGEM + 382, 35, { width: 130 });
        doc.fontSize(7).font('Helvetica-Bold').fillColor('#90caf9').text('Data da abertura:', MARGEM + 330, 46, { width: 90 });
        doc.fontSize(7).font('Helvetica').fillColor('white').text(dataAbertura,               MARGEM + 422, 46, { width: 90 });
        if (dataAgenda) {
          doc.fontSize(7).font('Helvetica-Bold').fillColor('#90caf9').text('Data agendada:', MARGEM + 330, 57, { width: 90 });
          doc.fontSize(7).font('Helvetica').fillColor('white').text(dataAgenda,              MARGEM + 422, 57, { width: 90 });
        }
        y = 90;

        // ── TÍTULO ────────────────────────────────────────────
        doc.fontSize(12).font('Helvetica-Bold').fillColor(COR_AZUL)
           .text(`Chamado Técnico: N° ${os.numero_os || ''} - Protocolo Nº ${os.protocolo_ixc || os.numero_os || ''}`,
                 MARGEM, y, { width: LARGURA, align: 'center' });
        y += 18;
        this._linha(doc, y, COR_AZUL, 1); y += 6;

        // ── DADOS DO CLIENTE ──────────────────────────────────
        _L('Cliente:', MARGEM, y, 42);      _V(os.cliente_nome, MARGEM + 44, y, 240);
        _L('CNPJ/CPF:', MARGEM + 320, y, 50); _V(cpfCnpj, MARGEM + 372, y, 145);
        y += 13;

        _L('Endereço:', MARGEM, y, 46);
        _V(os.cliente_endereco, MARGEM + 48, y, LARGURA - 48);
        y += 13;

        if (complemento) {
          _L('Compl.:', MARGEM, y, 40);
          _V(complemento, MARGEM + 42, y, LARGURA - 42);
          y += 13;
        }

        _L('Fone:', MARGEM, y, 30);
        _L('Celular:', MARGEM + 32, y, 38);
        _V(os.cliente_telefone, MARGEM + 72, y, 120);
        _L('Comercial:', MARGEM + 210, y, 55);
        _L('Ramal:', MARGEM + 370, y, 40);
        y += 13;

        if (cidade || cep || email) {
          _L('Cidade:', MARGEM, y, 36);
          _V(`${cidade}${cep ? '  CEP: ' + cep : ''}`, MARGEM + 38, y, 200);
          if (email) { _L('E-mail:', MARGEM + 250, y, 36); _V(email, MARGEM + 288, y, 220); }
          y += 13;
        }

        this._linha(doc, y); y += 5;

        // ── INFO TÉCNICA ──────────────────────────────────────
        _L('Consultor:', MARGEM, y, 52); _V(tecnico, MARGEM + 54, y, 130);
        _L('Marcado Por:', MARGEM + 210, y, 65);
        _V(`${tecnico} ${dataAbertura}`, MARGEM + 277, y, 230);
        y += 13;

        _L('Origem da Visita:', MARGEM, y, 90);
        _L('Forma de Pagamento:', MARGEM + 210, y, 110);
        y += 13;

        _L('Login:', MARGEM, y, 32);          _V(login, MARGEM + 34, y, 110);
        _L('Senha router 1:', MARGEM + 150, y, 66); _V(senha1, MARGEM + 218, y, 90);
        _L('Senha router 2:', MARGEM + 315, y, 66); _V(senha2, MARGEM + 383, y, 90);
        y += 13;

        _L('Melhor horário:', MARGEM, y, 72);
        _L('Assunto:', MARGEM + 140, y, 40);
        _V(os.tipo_servico || '', MARGEM + 182, y, 140);
        _L('Senha wifi:', MARGEM + 340, y, 50); _V(senhaWifi, MARGEM + 393, y, 120);
        y += 13;

        _L('Colaborador responsável:', MARGEM, y, 130);
        _V(tecnico, MARGEM + 132, y, 200);
        y += 16;

        this._linha(doc, y); y += 6;

        // ── ASSUNTO ───────────────────────────────────────────
        doc.rect(MARGEM - 5, y - 2, LARGURA + 10, 15).fill(COR_CINZA_CLARO);
        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO).text('Assunto:', MARGEM, y + 2);
        y += 18;
        if (assuntoTexto) {
          doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO).text(assuntoTexto, MARGEM, y, { width: LARGURA });
          y += doc.heightOfString(assuntoTexto, { width: LARGURA, fontSize: 8 }) + 6;
        }
        y += 4; this._linha(doc, y); y += 6;

        // ── OBS. DO TÉCNICO ───────────────────────────────────
        doc.rect(MARGEM - 5, y - 2, LARGURA + 10, 15).fill(COR_CINZA_CLARO);
        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO).text('Obs. do Técnico:', MARGEM, y + 2);
        y += 18;
        const problema = dados.relato_problema || '';
        const solucao  = dados.relato_solucao  || '';
        const obsTexto = [
          problema ? `Problema: ${problema}` : '',
          solucao  ? `Solução: ${solucao}` : '',
          dados.observacoes ? `Observações: ${dados.observacoes}` : ''
        ].filter(Boolean).join('\n\n') || 'Sem observações';
        doc.fontSize(8).font('Helvetica').fillColor(COR_CINZA_ESCURO).text(obsTexto, MARGEM, y, { width: LARGURA });
        y += doc.heightOfString(obsTexto, { width: LARGURA, fontSize: 8 }) + 10;

        // ── PRODUTOS / COMODATOS ──────────────────────────────
        const itens = dados.itens_estoque || [];
        if (itens.length > 0) {
          if (y > 620) { doc.addPage(); y = MARGEM; }
          this._linha(doc, y, COR_AZUL, 1); y += 5;
          const pats = itens.filter(i => i.isPatrimonio || i.tipo_produto === 'P');
          const prods = itens.filter(i => !i.isPatrimonio && i.tipo_produto !== 'P');
          if (pats.length > 0)  y = this._tabelaProdutos(doc, y, 'Comodatos', pats, true);
          if (prods.length > 0) y = this._tabelaProdutos(doc, y, 'Produtos Utilizados', prods, false);
        }

        // ── MENSAGENS / INTERAÇÕES ────────────────────────────
        if (y > 560) { doc.addPage(); y = MARGEM; }
        this._linha(doc, y, COR_AZUL, 1); y += 5;

        doc.rect(MARGEM - 5, y, LARGURA + 10, 16).fill('#dce8f5');
        doc.fontSize(7.5).font('Helvetica-Bold').fillColor(COR_AZUL)
           .text('Mensagens/Interações', MARGEM, y + 4, { width: LARGURA, align: 'center' });
        y += 18;

        const c1 = 95, c2 = 95, c3 = 75, c4 = LARGURA - 95 - 95 - 75;

        doc.rect(MARGEM - 5, y, LARGURA + 10, 14).fill(COR_CINZA_CLARO);
        this._linha(doc, y + 14, COR_LINHA, 0.5);
        doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text('Data/Hora', MARGEM,          y + 3, { width: c1 })
           .text('Operador',  MARGEM + c1,      y + 3, { width: c2 })
           .text('Evento',    MARGEM + c1 + c2, y + 3, { width: c3 })
           .text('Mensagem',  MARGEM + c1+c2+c3, y + 3, { width: c4 });
        y += 16;

        const eventoMap = {
          'A': 'Abertura', 'AG': 'Agendamento', 'RAG': 'Reagendamento',
          'EX': 'Execução', 'DS': 'Deslocamento', 'F': 'Fechamento', 'C': 'Cancelamento'
        };

        const linhas = mensagensIxc && mensagensIxc.length > 0
          ? mensagensIxc.map(m => {
              const nomeOperador = m.historico
                ? (m.historico.match(/Usuário ([^,]+),/)?.[1] || 'Sistema')
                : 'Sistema';
              return {
                data:     m.data || '',
                operador: nomeOperador,
                evento:   eventoMap[m.status] || m.status || 'Mensagem',
                mensagem: m.mensagem || ''
              };
            })
          : [
              { data: new Date(os.data_abertura || Date.now()).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'medium' }),
                operador: 'Sistema', evento: 'Abertura', mensagem: assuntoTexto || os.tipo_servico || 'OS criada' },
              { data: agora, operador: tecnico, evento: 'Execução',
                mensagem: problema ? `Problema: ${problema.substring(0, 120)}` : 'OS executada' },
              { data: agora, operador: tecnico, evento: 'Fechamento',
                mensagem: solucao ? solucao.substring(0, 120) : 'OS finalizada' }
            ];

        linhas.forEach((msg, idx) => {
          if (y > 700) { doc.addPage(); y = MARGEM; }
          const alt = Math.max(doc.heightOfString(String(msg.mensagem), { width: c4, fontSize: 7 }) + 6, 14);
          if (idx % 2 === 1) doc.rect(MARGEM - 5, y, LARGURA + 10, alt).fill('#f9f9f9');
          this._linha(doc, y + alt, COR_LINHA, 0.3);
          doc.fontSize(7).font('Helvetica').fillColor(COR_CINZA_ESCURO)
             .text(String(msg.data).substring(0, 20),     MARGEM,            y + 3, { width: c1 })
             .text(String(msg.operador).substring(0, 25), MARGEM + c1,       y + 3, { width: c2 })
             .text(String(msg.evento).substring(0, 20),   MARGEM + c1 + c2,  y + 3, { width: c3 })
             .text(String(msg.mensagem),                   MARGEM + c1+c2+c3, y + 3, { width: c4 });
          y += alt;
        });
        y += 14;

        // ── ASSINATURAS ───────────────────────────────────────
        if (y > 680) { doc.addPage(); y = MARGEM; }
        const assinLarg = 210, assinAlt = 60;
        const xTec = MARGEM, xCli = MARGEM + LARGURA - assinLarg;

        doc.rect(xTec, y, assinLarg, assinAlt).lineWidth(0.5).strokeColor(COR_LINHA).stroke();
        doc.rect(xCli, y, assinLarg, assinAlt).lineWidth(0.5).strokeColor(COR_LINHA).stroke();

        if (dados.assinatura) {
          try {
            const buf = Buffer.from(dados.assinatura, 'base64');
            doc.rect(xCli + 1, y + 1, assinLarg - 2, assinAlt - 2).fill('white');
            doc.image(buf, xCli + 5, y + 4, { fit: [assinLarg - 10, assinAlt - 8], align: 'center', valign: 'center' });
          } catch (_) {}
        }

        const legY = y + assinAlt + 4;
        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text(tecnico.toUpperCase(), xTec, legY, { width: assinLarg, align: 'center' });
        doc.fontSize(7).font('Helvetica').fillColor(COR_CINZA)
           .text('COLABORADOR RESPONSÁVEL', xTec, legY + 10, { width: assinLarg, align: 'center' });
        doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
           .text((os.cliente_nome || 'CLIENTE').toUpperCase(), xCli, legY, { width: assinLarg, align: 'center' });
        doc.fontSize(7).font('Helvetica').fillColor(COR_CINZA)
           .text('CLIENTE', xCli, legY + 10, { width: assinLarg, align: 'center' });

        // ── RODAPÉ ────────────────────────────────────────────
        const rodapeY = doc.page.height - 28;
        this._linha(doc, rodapeY - 5, COR_LINHA);
        doc.fontSize(6.5).font('Helvetica').fillColor(COR_CINZA)
           .text(`Documento gerado em ${agora} · SeeNet – Sistema de Gestão · ${nomeEmpresa}`,
                 MARGEM, rodapeY, { width: LARGURA, align: 'center' });

        doc.end();
      } catch (err) {
        reject(err);
      }
    });
  }

  static _tabelaProdutos(doc, y, titulo, itens, isComodato = false) {
    doc.rect(MARGEM - 5, y, LARGURA + 10, 16).fill('#dce8f5');
    doc.fontSize(7.5).font('Helvetica-Bold').fillColor(COR_AZUL)
       .text(titulo, MARGEM, y + 4, { width: LARGURA, align: 'center' });
    y += 18;

    const cID = 40, cUnit = 70, cQtd = 55, cTot = 70;
    const cDesc = LARGURA - cID - cUnit - cQtd - cTot;

    doc.rect(MARGEM - 5, y, LARGURA + 10, 14).fill(COR_CINZA_CLARO);
    this._linha(doc, y + 14, COR_LINHA, 0.5);
    doc.fontSize(7).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
       .text('ID',          MARGEM,                       y + 3, { width: cID })
       .text('Descrição',   MARGEM + cID,                 y + 3, { width: cDesc })
       .text('Valor Unit.', MARGEM + cID + cDesc,         y + 3, { width: cUnit, align: 'right' })
       .text('Quantidade',  MARGEM + cID + cDesc + cUnit, y + 3, { width: cQtd,  align: 'right' })
       .text('Valor Total', MARGEM + cID + cDesc + cUnit + cQtd, y + 3, { width: cTot, align: 'right' });
    y += 16;

    let total = 0;
    itens.forEach((item, idx) => {
      const serieMac = isComodato
        ? ['Série: ' + (item.numero_serie || '-'), 'MAC: ' + (item.mac || '-')].join('   ')
        : '';
      const altLinha = serieMac ? 22 : 14;
      if (idx % 2 === 1) doc.rect(MARGEM - 5, y, LARGURA + 10, altLinha).fill('#f9f9f9');
      this._linha(doc, y + altLinha, COR_LINHA, 0.3);
      const vUnit = parseFloat(item.valor_unitario || 0).toFixed(2);
      const qtd   = parseFloat(item.quantidade || 0).toFixed(2);
      const vTot  = parseFloat(item.valor_total || 0).toFixed(2);
      total += parseFloat(vTot);
      doc.fontSize(7.5).font('Helvetica').fillColor(COR_CINZA_ESCURO)
         .text(String(item.id_produto || ''), MARGEM,                       y + 3, { width: cID })
         .text(item.descricao || '',          MARGEM + cID,                 y + 3, { width: cDesc })
         .text(vUnit,                         MARGEM + cID + cDesc,         y + 3, { width: cUnit, align: 'right' })
         .text(qtd,                           MARGEM + cID + cDesc + cUnit, y + 3, { width: cQtd,  align: 'right' })
         .text(vTot,                          MARGEM + cID + cDesc + cUnit + cQtd, y + 3, { width: cTot, align: 'right' });
      if (serieMac) {
        doc.fontSize(6.5).font('Helvetica').fillColor(COR_CINZA)
           .text(serieMac, MARGEM + cID, y + 12, { width: cDesc });
      }
      y += altLinha;
    });

    doc.rect(MARGEM - 5, y, LARGURA + 10, 16).fill(COR_CINZA_CLARO);
    doc.fontSize(8).font('Helvetica-Bold').fillColor(COR_CINZA_ESCURO)
       .text('Total:', MARGEM + cID + cDesc + cUnit, y + 4, { width: cQtd, align: 'right' })
       .text(total.toFixed(2), MARGEM + cID + cDesc + cUnit + cQtd, y + 4, { width: cTot, align: 'right' });
    return y + 20;
  }
}

module.exports = OSPdfService;