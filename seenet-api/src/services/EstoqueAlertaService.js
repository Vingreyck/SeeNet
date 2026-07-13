const { db } = require('../config/database');
const IXCService = require('./IXCService');
const { enviarTelegram, telegramConfigurado } = require('./telegramService');

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Alerta de estoque baixo por loja → Telegram, EVENT-DRIVEN.
 * Só avisa quando um equipamento (ONT/roteador) CAI abaixo do mínimo numa loja
 * (ou piora enquanto já está baixo). Guarda o último saldo na tabela
 * `estoque_estado` (persistente) — por isso:
 *   • não repete o mesmo item a cada checagem;
 *   • NÃO dispara ao subir deploy (o estado salvo não mudou);
 *   • no 1º run cria um baseline SILENCIOSO (sem alertar o que já está baixo).
 *
 * Env: ESTOQUE_MINIMO_ONT (padrão 3), ESTOQUE_CHECK_MIN (padrão 60 min).
 */
class EstoqueAlertaService {
  constructor() {
    this.minimo = parseInt(process.env.ESTOQUE_MINIMO_ONT || '3', 10);
    this.intervaloMin = parseInt(process.env.ESTOQUE_CHECK_MIN || '60', 10);
    this.regexEquip = /ONT|ONU|ROTEADOR/i;
    this.intervalId = null;
  }

  iniciar() {
    if (!telegramConfigurado()) {
      console.log('📴 Alerta de estoque: Telegram não configurado (TELEGRAM_BOT_TOKEN/CHAT_ID) — desativado.');
      return;
    }
    console.log(`📦 Alerta de estoque (event-driven) ATIVO — mínimo ${this.minimo}, checa a cada ${this.intervaloMin}min`);
    setTimeout(() => this.verificar().catch(() => {}), 20000);
    this.intervalId = setInterval(() => this.verificar().catch(() => {}), this.intervaloMin * 60 * 1000);
  }

  async verificar() {
    const integracoes = await db('integracao_ixc').where('ativo', true)
      .select('tenant_id', 'url_api', 'token_api');
    for (const integ of integracoes) {
      try { await this._verificarEmpresa(integ); }
      catch (e) { console.error(`⚠️ Alerta de estoque (tenant ${integ.tenant_id}):`, e.message); }
    }
  }

  // Estoque atual de equipamento por loja: [{almox, nome, produtos: Map(id→{desc,saldo})}]
  async _coletar(integ) {
    const rows = await db('mapeamento_tecnicos_ixc')
      .where('tenant_id', integ.tenant_id).where('ativo', true)
      .whereNotNull('id_almoxarifado').select('id_almoxarifado');
    const almoxIds = [...new Set(rows.map((r) => r.id_almoxarifado).filter(Boolean))];
    if (!almoxIds.length) return [];
    const ixc = new IXCService(integ.url_api, integ.token_api);
    const lojas = [];
    for (const almox of almoxIds) {
      let estoque = [];
      try { estoque = await ixc.buscarSaldoAlmoxarifado(almox); } catch (_) { continue; }
      const produtos = new Map();
      let nome = `Almox ${almox}`;
      for (const r of estoque || []) {
        if (r.almox_descricao) nome = r.almox_descricao;
        if (r.produto_ativo === 'N') continue;
        if (!this.regexEquip.test(r.produto_descricao || '')) continue;
        // Colapsa filiais: soma o saldo do mesmo produto no almox.
        const cur = produtos.get(r.id_produto) || { desc: r.produto_descricao, saldo: 0 };
        cur.saldo += parseFloat(r.saldo || '0');
        produtos.set(r.id_produto, cur);
      }
      lojas.push({ almox, nome, produtos });
    }
    return lojas;
  }

  async _verificarEmpresa(integ) {
    const lojas = await this._coletar(integ);
    if (!lojas.length) return;

    // Estado anterior (persistente).
    const prevRows = await db('estoque_estado')
      .where('tenant_id', integ.tenant_id)
      .select('id_almoxarifado', 'id_produto', 'saldo');
    const prev = new Map();
    for (const r of prevRows) prev.set(`${r.id_almoxarifado}|${r.id_produto}`, parseFloat(r.saldo));
    const primeiraVez = prevRows.length === 0; // 1º run → baseline silencioso

    const alertas = [];
    const upserts = [];
    for (const loja of lojas) {
      for (const [idProduto, p] of loja.produtos) {
        const antes = prev.has(`${loja.almox}|${idProduto}`) ? prev.get(`${loja.almox}|${idProduto}`) : null;
        const agora = p.saldo;
        if (!primeiraVez && antes !== null) {
          const cruzou = antes >= this.minimo && agora < this.minimo; // ex: 3 → 2
          const piorou = agora < antes && agora < this.minimo;        // ex: 2 → 1
          if (cruzou || piorou) alertas.push({ loja: loja.nome, desc: p.desc, saldo: agora, de: antes });
        }
        // produto novo / 1º run → só registra baseline, não alerta
        upserts.push({ tenant_id: integ.tenant_id, id_almoxarifado: loja.almox, id_produto: idProduto, saldo: agora });
      }
    }

    if (upserts.length) {
      await db('estoque_estado')
        .insert(upserts.map((u) => ({ ...u, atualizado_em: db.fn.now() })))
        .onConflict(['tenant_id', 'id_almoxarifado', 'id_produto'])
        .merge(['saldo', 'atualizado_em']);
    }

    if (primeiraVez) {
      console.log(`📦 Estoque: baseline inicial gravado (${upserts.length} itens) — sem alerta no 1º run.`);
      return;
    }
    if (alertas.length) {
      await this._enviarBlocos(alertas, '⚠️ <b>ESTOQUE BAIXOU</b>', 'com queda abaixo de');
      console.log(`📦 Alerta de estoque enviado — ${alertas.length} queda(s).`);
    }
  }

  // Snapshot atual (on-demand) — usado pelo comando /baixo e pela rota de debug.
  async digestParaGrupo() {
    const integracoes = await db('integracao_ixc').where('ativo', true)
      .select('tenant_id', 'url_api', 'token_api');
    for (const integ of integracoes) {
      const lojas = await this._coletar(integ);
      const alertas = [];
      for (const loja of lojas) {
        for (const [, p] of loja.produtos) {
          if (p.saldo > 0 && p.saldo < this.minimo) alertas.push({ loja: loja.nome, desc: p.desc, saldo: p.saldo });
        }
      }
      if (alertas.length) await this._enviarBlocos(alertas, '📦 <b>ESTOQUE BAIXO</b> (agora)', 'abaixo de');
      else await enviarTelegram('✅ Nenhum equipamento abaixo do mínimo agora.');
    }
  }

  // Cabeçalho + 1 bloco (mensagem) por loja.
  async _enviarBlocos(alertas, titulo, frase) {
    const porLoja = {};
    for (const a of alertas) (porLoja[a.loja] = porLoja[a.loja] || []).push(a);
    const cidades = Object.keys(porLoja).sort();
    const agora = new Date().toLocaleString('pt-BR', {
      day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
    });

    await enviarTelegram(`${titulo}  ·  ${agora}\n<i>${cidades.length} loja(s) ${frase} ${this.minimo} un.</i> 👇`);
    await sleep(400);

    for (const loja of cidades) {
      const itens = porLoja[loja];
      const onts = itens.filter((i) => /ONT|ONU/i.test(i.desc)).sort((a, b) => a.saldo - b.saldo);
      const rotas = itens.filter((i) => /ROTEADOR/i.test(i.desc)).sort((a, b) => a.saldo - b.saldo);
      const outros = itens.filter((i) => !/ONT|ONU|ROTEADOR/i.test(i.desc)).sort((a, b) => a.saldo - b.saldo);

      let m = `🏬 <b>${esc(loja)}</b>\n`;
      m += this._secao('📡 <b>ONT</b>', onts, /^\s*(ONT|ONU)[-\s]*/i);
      m += this._secao('📶 <b>Roteador</b>', rotas, /^\s*ROTEADOR[-\s]*/i);
      m += this._secao('📦 <b>Outros</b>', outros, null);

      await enviarTelegram(m.trimEnd());
      await sleep(400);
    }
  }

  // 🔴 = 1 un (crítico), 🟠 = 2. Mostra "(era X)" quando é queda (event-driven).
  _secao(titulo, itens, prefixo) {
    if (!itens.length) return '';
    let s = `\n${titulo}\n`;
    for (const i of itens) {
      const nome = prefixo ? i.desc.replace(prefixo, '').trim() : i.desc;
      const marca = i.saldo <= 1 ? '🔴' : '🟠';
      const era = (i.de != null) ? ` <i>(era ${i.de})</i>` : '';
      s += `${marca} ${esc(nome)} — <b>${i.saldo}</b>${era}\n`;
    }
    return s;
  }
}

module.exports = EstoqueAlertaService;
