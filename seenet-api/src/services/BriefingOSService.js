const axios = require('axios');
const crypto = require('crypto');

/**
 * 🤖 Briefing da OS — o que o técnico precisa saber ANTES de bater na porta.
 *
 * Junta o que já temos espalhado (mensagem do atendente, sinal da ONU, status de
 * conexão, caixa FTTH e histórico do cliente) e devolve: provável causa, ordem de
 * verificação e material pra levar.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * DIVISÃO DE TRABALHO (o ponto mais importante deste arquivo)
 *
 *   CÓDIGO  → calcula os NÚMEROS e os FATOS (sinal, faixa, quantas OS o cliente
 *             teve, há quantos dias foi a última). Determinístico, sempre igual.
 *   IA      → só ESCREVE o texto em cima desses fatos.
 *
 * A IA nunca produz um número. Ela recebe "-27,96 dBm, faixa crítica" pronto e
 * interpreta. Isso é o oposto da tentativa de ler a metragem do drop por foto
 * (ago/2026), que falhou justamente porque a IA tinha que PRODUZIR o valor — e
 * errava com confiança alta, de forma diferente a cada tentativa.
 *
 * E se a IA falhar (rate limit, fora do ar, JSON quebrado), `gerar()` devolve a
 * parte determinística assim mesmo. O briefing fica mais seco, nunca vazio.
 * ─────────────────────────────────────────────────────────────────────────────
 */
class BriefingOSService {
  // Limites de potência óptica (dBm). MESMOS valores do app
  // (OrdemServico.sinalCritico / sinalAtencao / sinalForteDemais).
  // ⚠️ Se mudar aqui, mudar lá também — são duas cópias de propósito, porque o
  // app precisa classificar offline, sem chamar o servidor.
  static SINAL_CRITICO = -27.0;
  static SINAL_ATENCAO = -25.0;
  static SINAL_FORTE_DEMAIS = -8.0;

  /** Acima disto a medição é velha demais pra sustentar diagnóstico. */
  static HORAS_SINAL_VALIDO = 24;

  /** Janela em que uma nova OS do mesmo cliente conta como RETORNO. */
  static DIAS_RECORRENCIA = 45;

  constructor() {
    this.apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
    // Modelo de TEXTO (não repetir a aposta em visão, que já se provou não
    // funcionar aqui). ⚠️ A Groq APOSENTA modelo sem aviso: `llama-3.3-70b-versatile`
    // sumiu da conta e derrubou este briefing E o diagnóstico do checklist, em
    // silêncio. Dos que existem hoje, só o gpt-oss-120b aceita esta chamada —
    // `qwen/qwen3.6-27b` e `openai/gpt-oss-20b` devolvem 400 (testado 19/ago).
    // Se um dia parar: rodar `GET /openai/v1/models` pra ver o que existe.
    this.model = process.env.GROQ_BRIEFING_MODEL || 'openai/gpt-oss-120b';
    this.timeoutMs = 20000;
    this.maxTexto = 400; // corta texto livre do IXC (alguns vêm gigantes)
  }

  get apiKey() {
    return process.env.GROQ_API_KEY;
  }

  // ───────────────────────── PARTE DETERMINÍSTICA ─────────────────────────

  /** Faixa do sinal. Espelha a regra do app. */
  classificarSinal(rx) {
    if (rx === null || rx === undefined || Number.isNaN(rx)) return 'desconhecido';
    if (rx > BriefingOSService.SINAL_FORTE_DEMAIS) return 'critico';
    if (rx < BriefingOSService.SINAL_CRITICO) return 'critico';
    if (rx < BriefingOSService.SINAL_ATENCAO) return 'atencao';
    return 'bom';
  }

  /** Frase pronta sobre o sinal — usada com IA e sem IA. */
  textoSinal(rx, nivel) {
    switch (nivel) {
      case 'bom':
        return `Sinal em ${this._dbm(rx)}, dentro do esperado. O problema provavelmente não é o nível óptico.`;
      case 'atencao':
        return `Sinal em ${this._dbm(rx)}, na borda. Costuma cair de forma intermitente e piora com chuva.`;
      case 'critico':
        return rx > BriefingOSService.SINAL_FORTE_DEMAIS
          ? `Sinal em ${this._dbm(rx)}, FORTE DEMAIS. Falta atenuação e isso pode danificar a ONU.`
          : `Sinal em ${this._dbm(rx)}, FORA da faixa de operação. Explica queda e lentidão por si só.`;
      default:
        return 'Sem medição de sinal no IXC para este login.';
    }
  }

  _dbm(v) {
    return `${Number(v).toFixed(2).replace('.', ',')} dBm`;
  }

  _num(v) {
    if (v === null || v === undefined || v === '') return null;
    const n = parseFloat(v);
    return (Number.isNaN(n) || n === 0) ? null : n;
  }

  /**
   * ⏰ Converte data do IXC ("2026-08-19 09:02:44") em epoch.
   *
   * O IXC grava em horário de BRASÍLIA e SEM indicar fuso. `new Date(s)` usa o
   * fuso do servidor — e o Railway roda em **UTC**, então a medição sairia 3h
   * mais VELHA do que é (uma leitura de 1h atrás viraria "há 4 h"). Mesma
   * armadilha do `IXCService.formatarDataIXC`.
   *
   * Montamos o epoch à mão somando as 3h: não depende do fuso do servidor nem
   * de dados de fuso (ICU), então dá o mesmo resultado em qualquer máquina.
   */
  _epochDataIXC(data) {
    if (!data) return null;
    if (data instanceof Date) return Number.isNaN(data.getTime()) ? null : data.getTime();

    const s = String(data).trim();

    // Se a string JÁ diz o fuso (ISO com Z ou ±hh:mm), ela é inequívoca —
    // somar 3h aqui deslocaria um horário que já está correto.
    if (/(?:Z|[+-]\d{2}:?\d{2})$/i.test(s)) {
      const t = new Date(s).getTime();
      return Number.isNaN(t) ? null : t;
    }

    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/);
    if (!m) {
      const t = new Date(s).getTime();
      return Number.isNaN(t) ? null : t;
    }
    const [, ano, mes, dia, hora, min, seg] = m.map(Number);
    if (ano < 2000) return null; // '0000-00-00' do IXC = nunca medido
    return Date.UTC(ano, mes - 1, dia, hora + 3, min, seg);
  }

  _horasDesde(data) {
    const t = this._epochDataIXC(data);
    if (t === null) return null;
    return Math.floor((Date.now() - t) / 36e5);
  }

  _idade(horas) {
    if (horas === null) return 'sem data';
    if (horas < 1) return 'agora há pouco';
    if (horas < 24) return `há ${horas} h`;
    const d = Math.floor(horas / 24);
    return `há ${d} ${d === 1 ? 'dia' : 'dias'}`;
  }

  _cortar(texto) {
    if (!texto) return null;
    const s = String(texto).replace(/\s+/g, ' ').trim();
    if (!s) return null;
    return s.length > this.maxTexto ? s.slice(0, this.maxTexto) + '…' : s;
  }

  /**
   * Extrai do registro da OS tudo que interessa, já normalizado.
   * Toda a "inteligência numérica" acontece aqui, não na IA.
   */
  montarContexto(os, historico = []) {
    let d = {};
    try {
      d = typeof os.dados_ixc === 'string' ? JSON.parse(os.dados_ixc) : (os.dados_ixc || {});
    } catch (_) { d = {}; }

    const rx = this._num(d.sn_sinal_rx);
    const nivel = this.classificarSinal(rx);
    const horasSinal = this._horasDesde(d.sn_sinal_data);
    const sinalVelho = horasSinal === null || horasSinal >= BriefingOSService.HORAS_SINAL_VALIDO;

    // Histórico: só o que é FATO contável.
    const anteriores = (historico || []).filter(h => String(h.id) !== String(os.id));
    const limite = Date.now() - BriefingOSService.DIAS_RECORRENCIA * 864e5;
    const recentes = anteriores.filter(h => {
      const t = h.data_abertura ? new Date(h.data_abertura).getTime() : NaN;
      return !Number.isNaN(t) && t >= limite;
    });

    return {
      assunto: os.tipo_servico || null,
      pedido: this._cortar(os.observacoes),
      cliente: os.cliente_nome || null,
      login: d.login || null,
      onu: d.sn_onu_tipo || null,
      caixa: d.caixa_ftth || null,
      porta: d.porta_ftth || null,
      online: typeof d.sn_online === 'boolean' ? d.sn_online : null,
      ultimaConexao: d.sn_ultima_conexao || null,
      sinal: rx === null ? null : {
        rx,
        nivel,
        texto: this.textoSinal(rx, nivel),
        idade: this._idade(horasSinal),
        velho: sinalVelho,
      },
      historico: {
        total: anteriores.length,
        recentes: recentes.length,
        // só os campos que a IA precisa ler, e curtos
        ultimas: anteriores.slice(0, 4).map(h => ({
          assunto: h.tipo_servico || 'OS',
          quando: h.data_abertura
            ? new Date(h.data_abertura).toISOString().slice(0, 10)
            : null,
          pedido: this._cortar(h.observacoes),
        })),
      },
    };
  }

  /**
   * O que dá pra afirmar SEM nenhuma IA. É isto que aparece se a Groq falhar —
   * por isso não é um "fallback pobre", é a base do briefing.
   */
  resumoDeterministico(ctx) {
    const alertas = [];

    if (ctx.sinal) {
      alertas.push(
        ctx.sinal.velho
          ? `${ctx.sinal.texto} (medição ${ctx.sinal.idade} — confirme no local)`
          : `${ctx.sinal.texto} (medido ${ctx.sinal.idade})`
      );
    }

    if (ctx.online === false) {
      const quando = ctx.ultimaConexao ? ` Última conexão: ${ctx.ultimaConexao}.` : '';
      alertas.push(`Login estava OFFLINE na última sincronização.${quando}`);
    }

    if (ctx.historico.recentes > 0) {
      alertas.push(
        `Cliente já teve ${ctx.historico.recentes} ` +
        `${ctx.historico.recentes === 1 ? 'OS' : 'OS'} nos últimos ` +
        `${BriefingOSService.DIAS_RECORRENCIA} dias — é retorno, não primeira visita.`
      );
    }

    return {
      alertas,
      sinal: ctx.sinal
        ? { rx: ctx.sinal.rx, nivel: ctx.sinal.nivel, idade: ctx.sinal.idade, velho: ctx.sinal.velho }
        : null,
      caixa: ctx.caixa || null,
      porta: ctx.porta || null,
    };
  }

  /**
   * Impressão digital das ENTRADAS do briefing.
   *
   * É o que dispensa rotina de expiração: enquanto mensagem, sinal, conexão e
   * histórico forem os mesmos, o briefing cacheado continua válido. Quando o
   * IXC remede a ONU ou entra uma OS nova no histórico, o hash muda e o
   * briefing é regerado sozinho.
   *
   * A IDADE da medição fica DE FORA de propósito: ela muda a cada minuto e
   * invalidaria o cache o tempo todo sem mudar o diagnóstico. O que importa é
   * o valor medido (e o carimbo de quando foi medido), não quanto tempo passou.
   */
  hashContexto(ctx) {
    const chave = JSON.stringify({
      assunto: ctx.assunto,
      pedido: ctx.pedido,
      rx: ctx.sinal ? ctx.sinal.rx : null,
      nivel: ctx.sinal ? ctx.sinal.nivel : null,
      online: ctx.online,
      caixa: ctx.caixa,
      porta: ctx.porta,
      onu: ctx.onu,
      hist: ctx.historico.total,
      histRecentes: ctx.historico.recentes,
      modelo: this.model,
    });
    return crypto.createHash('sha256').update(chave).digest('hex');
  }

  // ─────────────────────────────── IA ───────────────────────────────

  _prompt(ctx) {
    const linhas = [];
    linhas.push(`SERVIÇO: ${ctx.assunto || 'não informado'}`);
    if (ctx.pedido) linhas.push(`PEDIDO DO ATENDENTE: "${ctx.pedido}"`);
    if (ctx.sinal) {
      linhas.push(`SINAL DA ONU: ${this._dbm(ctx.sinal.rx)} — faixa ${ctx.sinal.nivel.toUpperCase()} (medido ${ctx.sinal.idade})`);
    } else {
      linhas.push('SINAL DA ONU: sem medição disponível');
    }
    if (ctx.onu) linhas.push(`MODELO DA ONU: ${ctx.onu}`);
    if (ctx.online !== null) linhas.push(`CONEXÃO: ${ctx.online ? 'online' : 'OFFLINE'} na última sincronização`);
    if (ctx.caixa) linhas.push(`CAIXA FTTH: ${ctx.caixa}${ctx.porta ? ` / porta ${ctx.porta}` : ''}`);

    if (ctx.historico.total > 0) {
      linhas.push(`HISTÓRICO: ${ctx.historico.total} OS anteriores deste cliente ` +
        `(${ctx.historico.recentes} nos últimos ${BriefingOSService.DIAS_RECORRENCIA} dias)`);
      ctx.historico.ultimas.forEach(h => {
        linhas.push(`  - ${h.quando || 's/data'}: ${h.assunto}${h.pedido ? ` — "${h.pedido}"` : ''}`);
      });
    } else {
      linhas.push('HISTÓRICO: nenhuma OS anterior deste cliente');
    }

    return linhas.join('\n');
  }

  async _chamarIA(ctx) {
    if (!this.apiKey) throw new Error('GROQ_API_KEY não configurada');

    const system = `Você é um técnico SÊNIOR de provedor de internet (fibra óptica/FTTH) orientando um técnico de campo que está indo atender.

REGRAS OBRIGATÓRIAS:
1. Use SOMENTE os dados que eu fornecer. NÃO invente medições, números, modelos ou endereços.
2. NUNCA escreva um valor de sinal diferente do que eu informei. Se eu não informei sinal, não fale de sinal como se soubesse.
3. Se o sinal estiver na faixa CRÍTICA, ele é a principal suspeita — mesmo que o pedido do atendente fale de wifi ou roteador, porque nível óptico ruim derruba tudo depois dele.
4. Seja curto e prático. Frases de campo, sem enrolação e sem saudação.
5. Escreva em português do Brasil.

Responda APENAS com JSON válido, sem markdown, sem crase, neste formato exato:
{
  "causa_provavel": "1 ou 2 frases dizendo o que provavelmente está acontecendo",
  "verificar": ["passo curto 1", "passo curto 2", "passo curto 3"],
  "levar": ["material 1", "material 2"],
  "atencao": "1 frase de alerta, ou null se não houver nada relevante"
}

"verificar": no máximo 4 passos, na ordem que o técnico deve seguir, do mais provável para o menos.
"levar": no máximo 4 itens, só o que faz sentido para esse caso.`;

    const resp = await axios.post(
      this.apiUrl,
      {
        model: this.model,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: this._prompt(ctx) },
        ],
        max_tokens: 700,
        temperature: 0.3, // baixa: queremos consistência, não criatividade
        response_format: { type: 'json_object' },
      },
      {
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        timeout: this.timeoutMs,
      }
    );

    const texto = resp.data?.choices?.[0]?.message?.content;
    if (!texto) throw new Error('resposta vazia da Groq');
    return this._extrairJson(texto);
  }

  /**
   * Parsing defensivo. Mesmo com response_format json_object o modelo às vezes
   * embrulha em ```json ... ``` ou emenda texto antes/depois — lição da
   * tentativa do drop, onde confiar no formato prometido custou várias rodadas.
   */
  _extrairJson(texto) {
    let s = String(texto).trim();
    s = s.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();

    let obj = null;
    try {
      obj = JSON.parse(s);
    } catch (_) {
      const ini = s.indexOf('{');
      const fim = s.lastIndexOf('}');
      if (ini >= 0 && fim > ini) {
        try { obj = JSON.parse(s.slice(ini, fim + 1)); } catch (_) { /* desiste */ }
      }
    }
    if (!obj || typeof obj !== 'object') throw new Error('JSON inválido da IA');

    const lista = (v, max) => {
      if (!Array.isArray(v)) return [];
      return v
        .filter(x => typeof x === 'string' && x.trim())
        .map(x => x.trim())
        .slice(0, max);
    };
    const frase = (v) => (typeof v === 'string' && v.trim()) ? v.trim() : null;

    return {
      causa_provavel: frase(obj.causa_provavel),
      verificar: lista(obj.verificar, 4),
      levar: lista(obj.levar, 4),
      atencao: frase(obj.atencao),
    };
  }

  // ───────────────────────────── ENTRADA ─────────────────────────────

  /**
   * Gera o briefing. NUNCA lança: se a IA falhar, devolve só a parte
   * determinística com `com_ia: false`.
   */
  async gerar(os, historico = []) {
    const ctx = this.montarContexto(os, historico);
    const base = this.resumoDeterministico(ctx);
    base.contexto_hash = this.hashContexto(ctx);

    try {
      const ia = await this._chamarIA(ctx);
      // Se a IA respondeu mas sem nada aproveitável, trata como falha —
      // melhor mostrar só os fatos do que um card com campos vazios.
      const vazio = !ia.causa_provavel && !ia.verificar.length && !ia.levar.length;
      if (vazio) throw new Error('IA respondeu sem conteúdo útil');

      return {
        ...base,
        ...ia,
        com_ia: true,
        modelo: this.model,
        gerado_em: new Date().toISOString(),
      };
    } catch (e) {
      // O nome do modelo vai no log DE PROPÓSITO: quando a Groq aposentar este
      // também, a causa fica óbvia na primeira linha em vez de virar caçada.
      console.warn(`⚠️ [BRIEFING] IA indisponível [${this.model}] (${e.message}) — devolvendo só os fatos`);
      return {
        ...base,
        causa_provavel: null,
        verificar: [],
        levar: [],
        atencao: null,
        com_ia: false,
        gerado_em: new Date().toISOString(),
      };
    }
  }
}

module.exports = new BriefingOSService();
module.exports.BriefingOSService = BriefingOSService;
