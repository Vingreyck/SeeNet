const { db } = require('../config/database');
const IXCService = require('./IXCService');
const { telegramConfigurado, apiTelegram, enviarPara, CHAT_ID } = require('./telegramService');

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
// normaliza pra comparar nome de loja sem acento/caixa
function norm(s) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Bot de COMANDOS do Telegram (consulta de estoque sob demanda), via long polling.
 * Só responde no grupo autorizado (TELEGRAM_CHAT_ID). Comandos:
 *   /comandos            — lista os comandos
 *   /lojas               — lista as lojas monitoradas
 *   /onts [loja]         — quantas ONT/ONU tem (todas, ou só a loja)
 *   /produtos <loja>     — estoque (todos os produtos com saldo) da loja
 */
class TelegramBotService {
  constructor() {
    this.offset = 0;
    this.rodando = false;
    this.regexOnt = /ONT|ONU/i;
    this.minimo = parseInt(process.env.ESTOQUE_MINIMO_ONT || '3', 10);
    this.cache = { ts: 0, lojas: [] }; // [{almox, nome, rows}]
    this.cacheTTL = 120000; // 2 min
  }

  // Semáforo pelo saldo: 🔴 ≤1 · 🟠 abaixo do mínimo · 🟢 ok
  _marca(saldo) {
    if (saldo <= 1) return '🔴';
    if (saldo < this.minimo) return '🟠';
    return '🟢';
  }

  // Envia mensagem longa quebrando por linha (limite do Telegram é ~4096).
  async _enviarLongo(chatId, texto) {
    const LIM = 3900;
    if (texto.length <= LIM) return enviarPara(chatId, texto);
    const linhas = texto.split('\n');
    let buf = '';
    for (const ln of linhas) {
      if (buf.length + ln.length + 1 > LIM) { await enviarPara(chatId, buf); buf = ''; }
      buf += (buf ? '\n' : '') + ln;
    }
    if (buf) await enviarPara(chatId, buf);
  }

  // Seção "• nome — saldo" (usada no /produtos), tirando o prefixo repetido.
  _secaoLista(titulo, itens, prefixo) {
    if (!itens.length) return '';
    let s = `\n${titulo}\n`;
    for (const i of itens) {
      const nome = prefixo ? i.desc.replace(prefixo, '').trim() : i.desc;
      s += `• ${esc(nome)} — <b>${i.saldo}</b>\n`;
    }
    return s;
  }

  async iniciar() {
    if (!telegramConfigurado()) return; // sem bot → não sobe
    if (this.rodando) return;
    this.rodando = true;
    // Pula updates antigos (não reprocessa comandos de antes de subir).
    try {
      const d = await apiTelegram('getUpdates', { offset: -1, timeout: 0 });
      const last = d?.result?.[d.result.length - 1];
      if (last) this.offset = last.update_id + 1;
    } catch (_) {}
    console.log('🤖 Bot Telegram (comandos) ativo — long polling');
    this._loop();
  }

  async _loop() {
    while (this.rodando) {
      const d = await apiTelegram('getUpdates', { offset: this.offset, timeout: 30 });
      if (!d || !d.ok) { await sleep(3000); continue; }
      for (const u of d.result || []) {
        this.offset = u.update_id + 1;
        try { await this._handle(u); } catch (e) { console.error('⚠️ Bot handle:', e.message); }
      }
    }
  }

  async _handle(u) {
    const msg = u.message || u.channel_post;
    if (!msg || !msg.text) return;
    // Só responde no grupo autorizado.
    if (String(msg.chat.id) !== String(CHAT_ID)) return;

    const text = msg.text.trim();
    if (!text.startsWith('/')) return;
    const partes = text.split(/\s+/);
    const cmd = partes[0].split('@')[0].toLowerCase(); // tira @nomedobot
    const arg = partes.slice(1).join(' ').trim();
    const chatId = msg.chat.id;

    if (['/start', '/comandos', '/help', '/ajuda'].includes(cmd)) return this._ajuda(chatId);
    if (cmd === '/lojas') return this._lojas(chatId);
    if (['/onts', '/ont', '/onus', '/onu'].includes(cmd)) return this._onts(chatId, arg);
    if (['/produtos', '/produto', '/estoque'].includes(cmd)) return this._produtos(chatId, arg);
    if (['/baixo', '/baixos', '/baixoestoque'].includes(cmd)) return this._baixo(chatId);
    return enviarPara(chatId, 'Comando não reconhecido. Use /comandos pra ver a lista.');
  }

  _ajuda(chatId) {
    const txt =
      '<b>🤖 Comandos</b>\n\n' +
      '/lojas — lista as lojas monitoradas\n' +
      '/onts [loja] — ONT/ONU + roteadores em estoque (todas, ou só a loja)\n' +
      '/produtos &lt;loja&gt; — estoque da loja (produtos com saldo)\n' +
      '/baixo — retrato de tudo que está abaixo do mínimo agora\n' +
      '/comandos — mostra esta ajuda\n\n' +
      '<i>Exemplos:</i> <code>/onts malhador</code> · <code>/produtos malhador</code>';
    return enviarPara(chatId, txt);
  }

  async _baixo(chatId) {
    await enviarPara(chatId, '🔎 Gerando o retrato do estoque baixo...');
    const EstoqueAlertaService = require('./EstoqueAlertaService');
    await new EstoqueAlertaService().digestParaGrupo();
  }

  async _integracao() {
    return db('integracao_ixc').where('ativo', true)
      .select('tenant_id', 'url_api', 'token_api').first();
  }

  // Carrega (com cache) as lojas monitoradas + o estoque cru de cada uma.
  async _carregarLojas() {
    if (this.cache.lojas.length && Date.now() - this.cache.ts < this.cacheTTL) return this.cache.lojas;
    const integ = await this._integracao();
    if (!integ) return [];
    const rows = await db('mapeamento_tecnicos_ixc')
      .where('tenant_id', integ.tenant_id).where('ativo', true)
      .whereNotNull('id_almoxarifado').select('id_almoxarifado');
    const almoxIds = [...new Set(rows.map((r) => r.id_almoxarifado).filter(Boolean))];
    const ixc = new IXCService(integ.url_api, integ.token_api);
    const lojas = [];
    for (const almox of almoxIds) {
      let stock = [];
      try { stock = await ixc.buscarSaldoAlmoxarifado(almox); } catch (_) {}
      lojas.push({ almox, nome: stock[0]?.almox_descricao || `Almox ${almox}`, rows: stock });
    }
    this.cache = { ts: Date.now(), lojas };
    return lojas;
  }

  _match(lojas, arg) {
    if (!arg) return lojas;
    const a = norm(arg);
    return lojas.filter((l) => norm(l.nome).includes(a));
  }

  // Colapsa filiais: soma saldo por produto, aplicando um filtro opcional.
  _resumo(rows, filtro) {
    const m = new Map();
    for (const r of rows || []) {
      if (r.produto_ativo === 'N') continue;
      if (filtro && !filtro.test(r.produto_descricao || '')) continue;
      const cur = m.get(r.id_produto) || { desc: r.produto_descricao, saldo: 0 };
      cur.saldo += parseFloat(r.saldo || '0');
      m.set(r.id_produto, cur);
    }
    return [...m.values()];
  }

  async _lojas(chatId) {
    const lojas = await this._carregarLojas();
    if (!lojas.length) return enviarPara(chatId, 'Nenhuma loja mapeada.');
    let txt = `🏬 <b>Lojas monitoradas</b> (${lojas.length})\n\n`;
    for (const l of [...lojas].sort((a, b) => a.nome.localeCompare(b.nome))) txt += `• ${esc(l.nome)}\n`;
    txt += '\n<i>Use:</i> <code>/onts malhador</code> <i>ou</i> <code>/produtos malhador</code>';
    return this._enviarLongo(chatId, txt);
  }

  async _onts(chatId, arg) {
    const lojas = this._match(await this._carregarLojas(), arg);
    if (!lojas.length) return enviarPara(chatId, `Não achei a loja "${esc(arg)}". Use /lojas.`);
    let txt = '📡 <b>Equipamentos em estoque</b>\n';
    for (const l of lojas) {
      const onts = this._resumo(l.rows, /ONT|ONU/i).filter((p) => p.saldo > 0).sort((a, b) => b.saldo - a.saldo);
      const rotas = this._resumo(l.rows, /ROTEADOR/i).filter((p) => p.saldo > 0).sort((a, b) => b.saldo - a.saldo);
      txt += `\n🏬 <b>${esc(l.nome)}</b>\n`;
      txt += this._blocoEquip('📡 ONT/ONU', onts, /^\s*(ONT|ONU)[-\s]*/i);
      txt += this._blocoEquip('📶 Roteador', rotas, /^\s*ROTEADOR[-\s]*/i);
      if (!onts.length && !rotas.length) txt += '<i>   nenhum em estoque</i>\n';
    }
    return this._enviarLongo(chatId, txt.trim());
  }

  // Bloco de uma categoria (ONT ou Roteador) com total + semáforo por item.
  _blocoEquip(titulo, itens, prefixo) {
    if (!itens.length) return '';
    const total = itens.reduce((s, p) => s + p.saldo, 0);
    let s = `<b>${titulo}</b> <i>(total ${total})</i>\n`;
    for (const p of itens) {
      const nome = p.desc.replace(prefixo, '').trim();
      s += `${this._marca(p.saldo)} ${esc(nome)} — <b>${p.saldo}</b>\n`;
    }
    return s;
  }

  async _produtos(chatId, arg) {
    if (!arg) return enviarPara(chatId, 'Informe a loja. Ex: <code>/produtos malhador</code> (veja /lojas).');
    const lojas = this._match(await this._carregarLojas(), arg);
    if (!lojas.length) return enviarPara(chatId, `Não achei a loja "${esc(arg)}". Use /lojas.`);
    for (const l of lojas) {
      const all = this._resumo(l.rows, null).filter((p) => p.saldo > 0);
      const onts = all.filter((p) => /ONT|ONU/i.test(p.desc)).sort((a, b) => a.desc.localeCompare(b.desc));
      const rotas = all.filter((p) => /ROTEADOR/i.test(p.desc)).sort((a, b) => a.desc.localeCompare(b.desc));
      const outros = all.filter((p) => !/ONT|ONU|ROTEADOR/i.test(p.desc)).sort((a, b) => a.desc.localeCompare(b.desc));

      let m = `📦 <b>Estoque — ${esc(l.nome)}</b>\n<i>${all.length} item(ns) com saldo</i>\n`;
      m += this._secaoLista('📡 <b>ONT</b>', onts, /^\s*(ONT|ONU)[-\s]*/i);
      m += this._secaoLista('📶 <b>Roteador</b>', rotas, /^\s*ROTEADOR[-\s]*/i);
      m += this._secaoLista('📦 <b>Outros</b>', outros, null);
      await this._enviarLongo(chatId, m.trim());
    }
  }
}

module.exports = TelegramBotService;
