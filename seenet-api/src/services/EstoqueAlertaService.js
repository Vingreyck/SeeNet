const { db } = require('../config/database');
const IXCService = require('./IXCService');
const { enviarTelegram, telegramConfigurado } = require('./telegramService');

// escapa pro parse_mode HTML do Telegram
function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Alerta de estoque baixo por loja → canal privado no Telegram.
 * Verifica os equipamentos (ONT/roteador) das lojas que os técnicos usam e avisa
 * quando um modelo está ACABANDO (tem estoque, mas abaixo do mínimo).
 *
 * Config (env, todas opcionais):
 *   ESTOQUE_MINIMO_ONT  = mínimo por modelo (padrão 3)
 *   ESTOQUE_CHECK_HORAS = de quanto em quanto tempo checa (padrão 12h)
 */
class EstoqueAlertaService {
  constructor() {
    this.minimo = parseInt(process.env.ESTOQUE_MINIMO_ONT || '3', 10);
    this.intervaloHoras = parseInt(process.env.ESTOQUE_CHECK_HORAS || '12', 10);
    // Equipamentos monitorados (o CPE que o técnico leva pro cliente).
    // Quer só ONT? troca por /ONT/i. Quer incluir mais? adiciona no regex.
    this.regexEquip = /ONT|ONU|ROTEADOR/i;
    this.intervalId = null;
  }

  iniciar() {
    if (!telegramConfigurado()) {
      console.log('📴 Alerta de estoque: Telegram não configurado (defina TELEGRAM_BOT_TOKEN e TELEGRAM_CHAT_ID) — desativado.');
      return;
    }
    console.log(`📦 Alerta de estoque baixo ATIVO — mínimo ${this.minimo}/modelo, checando a cada ${this.intervaloHoras}h`);
    // 1ª checagem ~20s após subir (deixa o banco/IXC prontos), depois no intervalo.
    setTimeout(() => this.verificar().catch(() => {}), 20000);
    this.intervalId = setInterval(
      () => this.verificar().catch(() => {}),
      this.intervaloHoras * 3600 * 1000
    );
  }

  async verificar() {
    const integracoes = await db('integracao_ixc')
      .where('ativo', true)
      .select('tenant_id', 'url_api', 'token_api');
    for (const integ of integracoes) {
      try {
        await this._verificarEmpresa(integ);
      } catch (e) {
        console.error(`⚠️ Alerta de estoque (tenant ${integ.tenant_id}):`, e.message);
      }
    }
  }

  async _verificarEmpresa(integ) {
    // Lojas monitoradas = almoxarifados que os técnicos usam (do mapeamento).
    const rows = await db('mapeamento_tecnicos_ixc')
      .where('tenant_id', integ.tenant_id)
      .where('ativo', true)
      .whereNotNull('id_almoxarifado')
      .select('id_almoxarifado');
    const lojas = [...new Set(rows.map((r) => r.id_almoxarifado).filter(Boolean))];
    if (!lojas.length) return;

    const ixc = new IXCService(integ.url_api, integ.token_api);
    const alertas = [];

    for (const almox of lojas) {
      let estoque;
      try {
        estoque = await ixc.buscarSaldoAlmoxarifado(almox);
      } catch (_) { continue; }

      // Colapsa filiais: o mesmo almox traz 1 linha por filial e a loja só tem
      // estoque real numa delas → soma o saldo por produto pra ter o total real.
      const porProduto = new Map();
      for (const r of estoque || []) {
        if (r.produto_ativo === 'N') continue;
        if (!this.regexEquip.test(r.produto_descricao || '')) continue;
        const cur = porProduto.get(r.id_produto) || {
          desc: r.produto_descricao,
          loja: r.almox_descricao || `almox ${almox}`,
          saldo: 0,
        };
        cur.saldo += parseFloat(r.saldo || '0');
        porProduto.set(r.id_produto, cur);
      }

      for (const p of porProduto.values()) {
        // "Acabando": tem estoque (>0) mas abaixo do mínimo. Os que estão em 0
        // são EXCLUÍDOS de propósito — a maioria é modelo que a loja nem usa
        // (fica sempre zerado) e viraria spam. O objetivo é REPOR antes de zerar.
        if (p.saldo > 0 && p.saldo < this.minimo) {
          alertas.push(p);
        }
      }
    }

    if (!alertas.length) return; // nada baixo → não manda nada (sem ruído)

    // Agrupa por loja e manda UM bloco (mensagem) por cidade — muito mais legível
    // no grupo do que um textão só. Cabeçalho + 1 card por loja.
    const porLoja = {};
    for (const a of alertas) (porLoja[a.loja] = porLoja[a.loja] || []).push(a);
    const cidades = Object.keys(porLoja).sort();

    const agora = new Date().toLocaleString('pt-BR', {
      day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
    });

    await enviarTelegram(
      `⚠️ <b>ESTOQUE BAIXO</b>  ·  ${agora}\n` +
      `<i>${cidades.length} loja(s) com equipamento abaixo de ${this.minimo} un.</i> 👇`
    );
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
      await sleep(400); // respeita o limite de mensagens/min do Telegram
    }

    console.log(`📦 Alerta de estoque enviado — ${alertas.length} item(ns) em ${cidades.length} loja(s)`);
  }

  // Monta uma seção (ONT / Roteador) do card da loja. 🔴 = 1 un (crítico), 🟠 = 2.
  // `prefixo` tira o "ONT "/"ROTEADOR " do nome (já está no título da seção).
  _secao(titulo, itens, prefixo) {
    if (!itens.length) return '';
    let s = `\n${titulo}\n`;
    for (const i of itens) {
      const nome = prefixo ? i.desc.replace(prefixo, '').trim() : i.desc;
      const marca = i.saldo <= 1 ? '🔴' : '🟠';
      s += `${marca} ${esc(nome)} — <b>${i.saldo}</b>\n`;
    }
    return s;
  }
}

module.exports = EstoqueAlertaService;
