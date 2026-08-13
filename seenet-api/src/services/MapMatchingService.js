const axios = require('axios');

/**
 * 🛣️ "Cola" a trilha do técnico nas ruas de verdade (map matching / snap-to-roads).
 *
 * Sem isto, a rota no mapa do admin é uma reta entre um ponto de GPS e o
 * próximo (~80m), o que corta curva e passa por cima de casa. O OSRM pega a
 * sequência de pontos e devolve o caminho pelas RUAS que melhor explica aquele
 * trajeto.
 *
 * ⚠️ O servidor padrão é o **público de demonstração** do projeto OSRM: é de
 * graça e não pede chave, mas não tem garantia de disponibilidade nem de
 * limite de uso. Por isso, TUDO aqui é best-effort: qualquer falha, timeout ou
 * recusa devolve `null`, e quem chamou desenha a trilha crua (o comportamento
 * de antes). O mapa nunca quebra por causa disto.
 *
 * Pra trocar por um OSRM próprio depois, é só setar `OSRM_URL` no Railway —
 * nenhuma mudança de código. `OSRM_ATIVO=false` desliga na hora.
 */
class MapMatchingService {
  constructor() {
    this.baseUrl = (process.env.OSRM_URL || 'https://router.project-osrm.org').replace(/\/$/, '');
    this.ativo = process.env.OSRM_ATIVO !== 'false';

    // O servidor público recusa acima de 100 coordenadas por chamada.
    this.maxPontosPorChamada = 90;
    // Teto de chamadas por trilha: evita que uma OS de dia inteiro vire 30
    // requisições no servidor público (e uma tela que demora a abrir).
    this.maxChamadas = 6;
    this.timeoutMs = 8000;

    // Cache em memória: o app recarrega a trilha a cada 30s, e sem isto cada
    // admin com o mapa aberto martelaria o OSRM de meio em meio minuto pelo
    // MESMO trajeto. A chave inclui a quantidade e o último horário, então
    // ponto novo invalida sozinho.
    this.cache = new Map();
    this.cacheTtlMs = 5 * 60 * 1000;
    this.cacheMax = 200;
  }

  /**
   * @param {Array<{latitude,longitude,precisao,criado_em}>} pontos - um trecho contínuo
   * @returns {Promise<Array<Array<{latitude,longitude}>>|null>} pedaços casados, ou null
   */
  async casar(pontos) {
    if (!this.ativo) return null;
    // Com menos de 3 pontos não há trajeto pra deduzir — a reta já é o que é.
    if (!Array.isArray(pontos) || pontos.length < 3) return null;

    const chave = this._chaveCache(pontos);
    const emCache = this.cache.get(chave);
    if (emCache && Date.now() - emCache.quando < this.cacheTtlMs) {
      return emCache.valor;
    }

    const lotes = this._dividirEmLotes(pontos);
    if (lotes.length > this.maxChamadas) {
      console.warn(`⚠️ [OSRM] trilha longa demais (${pontos.length} pontos) — usando só os ${this.maxChamadas} primeiros lotes`);
      lotes.length = this.maxChamadas;
    }

    const pedacos = [];
    for (const lote of lotes) {
      const casado = await this._casarLote(lote);
      // Um lote que falha não invalida os outros: o trecho dele sai cru.
      if (casado && casado.length) pedacos.push(...casado);
      else pedacos.push(lote.map((p) => ({ latitude: p.latitude, longitude: p.longitude })));
    }

    const resultado = pedacos.length ? pedacos : null;
    this._guardar(chave, resultado);
    return resultado;
  }

  async _casarLote(lote) {
    try {
      // ⚠️ O OSRM usa a ordem lon,lat (padrão GeoJSON) — invertido em relação
      // ao lat,lng que o resto do app usa. Trocar isso joga o trajeto no
      // oceano, e o erro é silencioso (ele "casa" em qualquer lugar).
      const coords = lote
        .map((p) => `${Number(p.longitude).toFixed(6)},${Number(p.latitude).toFixed(6)}`)
        .join(';');

      // Raio de busca por ponto. O padrão do OSRM é apertado demais pra GPS de
      // celular: sem isto ele desiste ("NoMatch") em rua paralela ou sinal ruim.
      const raios = lote
        .map((p) => {
          const precisao = Number(p.precisao);
          const r = Number.isFinite(precisao) && precisao > 0 ? precisao : 15;
          return Math.round(Math.min(Math.max(r, 10), 50));
        })
        .join(';');

      const url = `${this.baseUrl}/match/v1/driving/${coords}`;
      const { data } = await axios.get(url, {
        params: {
          geometries: 'geojson',
          overview: 'full',
          radiuses: raios,
          // Sem `timestamps` de propósito: o OSRM exige que sejam estritamente
          // crescentes e a trilha pode ter dois pontos no mesmo segundo, o que
          // derrubaria a chamada inteira com "Timestamps need to be increasing".
          tidy: 'true',
        },
        timeout: this.timeoutMs,
        headers: { 'User-Agent': 'SeeNet/1.0 (rastreamento de tecnico)' },
      });

      if (!data || data.code !== 'Ok' || !Array.isArray(data.matchings)) {
        console.warn(`⚠️ [OSRM] sem casamento (${data?.code || 'sem code'})`);
        return null;
      }

      // O OSRM devolve VÁRIOS "matchings" quando não consegue ligar tudo num
      // caminho só. Cada um vira um pedaço separado — juntá-los desenharia
      // justamente a reta atravessando que a gente está tentando eliminar.
      const pedacos = [];
      for (const m of data.matchings) {
        const linha = m?.geometry?.coordinates;
        if (!Array.isArray(linha) || linha.length < 2) continue;
        pedacos.push(linha.map(([lon, lat]) => ({ latitude: lat, longitude: lon })));
      }
      return pedacos.length ? pedacos : null;
    } catch (e) {
      const motivo = e.response?.status || e.code || e.message;
      console.warn(`⚠️ [OSRM] falhou (${motivo}) — trilha sai crua`);
      return null;
    }
  }

  /** Lotes com 1 ponto de sobreposição, pra as pontas não ficarem com buraco. */
  _dividirEmLotes(pontos) {
    if (pontos.length <= this.maxPontosPorChamada) return [pontos];
    const lotes = [];
    let i = 0;
    while (i < pontos.length) {
      lotes.push(pontos.slice(i, i + this.maxPontosPorChamada));
      i += this.maxPontosPorChamada - 1;
      if (pontos.length - i < 2) break;
    }
    return lotes;
  }

  _chaveCache(pontos) {
    const primeiro = pontos[0];
    const ultimo = pontos[pontos.length - 1];
    return `${pontos.length}|${primeiro.latitude},${primeiro.longitude}|${ultimo.latitude},${ultimo.longitude}|${ultimo.criado_em || ''}`;
  }

  _guardar(chave, valor) {
    // Limpeza simples: passou do teto, joga fora a entrada mais antiga. Sem
    // isto o Map cresceria pra sempre no processo do Railway.
    if (this.cache.size >= this.cacheMax) {
      const maisAntiga = this.cache.keys().next().value;
      this.cache.delete(maisAntiga);
    }
    this.cache.set(chave, { valor, quando: Date.now() });
  }
}

module.exports = new MapMatchingService();
