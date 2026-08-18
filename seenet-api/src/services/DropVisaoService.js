const axios = require('axios');

/**
 * Lê a METRAGEM do cabo drop a partir das fotos que o técnico tirou.
 *
 * Como funciona na prática: o cabo drop de fibra tem a metragem impressa ao
 * longo dele, em números sequenciais seguidos de "M" (ex.: "1175 M"). O técnico
 * fotografa a marcação no começo e no fim do trecho usado; a diferença entre os
 * dois números é quanto cabo ele gastou (1175 - 1075 = 100 metros).
 *
 * ⚠️ Por que a DESCRIÇÃO da foto entra junto na mesma chamada: quando a foto
 * sai borrada/escura o técnico digita o número na descrição da foto. Mandando
 * foto + descrição de uma vez, o modelo usa a descrição como rede de segurança
 * sem custar uma segunda chamada — e, se a IA falhar por completo, ainda há um
 * fallback por regex em cima só das descrições (`_lerDasDescricoes`).
 *
 * NADA aqui grava no banco nem no IXC: só devolve o número pro app mostrar ao
 * técnico, que confirma ou corrige antes de virar quantidade de material.
 */
class DropVisaoService {
  constructor() {
    this.apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

    // Modelos de visão em ordem de preferência. Se o primeiro não existir na
    // conta (ou for aposentado pela Groq), cai pro próximo em vez de quebrar —
    // a Groq troca de modelo com frequência e não dá pra depender de um só.
    this.modelos = (process.env.GROQ_VISION_MODELS ||
      'qwen/qwen3.6-27b,meta-llama/llama-4-maverick-17b-128e-instruct,meta-llama/llama-4-scout-17b-16e-instruct')
      .split(',').map((m) => m.trim()).filter(Boolean);

    // A Groq aceita no máximo 5 imagens por requisição.
    this.maxImagensPorChamada = 5;
    // Teto de chamadas por OS: 3 lotes = até 15 fotos. Evita que uma OS com
    // muita foto vire uma conta cara/lenta sem ninguém perceber.
    this.maxLotes = 3;
    this.timeoutMs = 45000;
  }

  get apiKey() {
    return process.env.GROQ_API_KEY;
  }

  get disponivel() {
    return !!this.apiKey;
  }

  _prompt(descricoes) {
    const contexto = descricoes.length
      ? `\nO técnico escreveu estas descrições para as fotos (use como APOIO quando a foto estiver ilegível):\n${descricoes.join('\n')}\n`
      : '';

    return `Você está vendo fotos de um cabo drop de fibra óptica tiradas por um técnico de campo.

O cabo tem a METRAGEM impressa ao longo dele: números sequenciais seguidos da letra M (exemplos: "1175 M", "1075M", "0842 M"). O técnico fotografa a marcação no início e no fim do trecho instalado.
${contexto}
Tarefa: leia o número de metragem impresso NO CABO em cada foto.

Responda SOMENTE com JSON válido, sem texto antes ou depois:
{
  "leituras": [
    {"foto": 1, "numero": 1175, "texto_lido": "1175 M", "confianca": "alta", "obs": ""}
  ],
  "observacao": ""
}

Regras obrigatórias:
- "foto" é o número da imagem na ordem em que foi enviada, começando em 1.
- Se a foto NÃO tiver marcação de metragem legível, use "numero": null e diga o motivo em "obs".
- NUNCA invente número. Prefira "numero": null com confianca "baixa" a chutar um valor.
- "confianca" só pode ser "alta" se os dígitos estiverem nítidos e sem ambiguidade.
- Se a foto estiver ilegível MAS a descrição do técnico trouxer o número, use esse número e marque "obs": "lido da descrição".`;
  }

  /**
   * @param {Array<{base64: string, descricao?: string}>} fotos
   * @returns {Promise<{ok, metros, maior, menor, confianca, fonte, leituras, aviso}>}
   */
  async analisar(fotos) {
    const validas = (fotos || []).filter((f) => f && f.base64);

    if (validas.length < 2) {
      return this._semResultado('São necessárias pelo menos 2 fotos para calcular o drop.');
    }

    if (!this.disponivel) {
      // Sem chave de IA ainda dá pra salvar o dia se o técnico digitou os
      // números nas descrições — é literalmente o caso "a foto não ficou boa".
      const porTexto = this._lerDasDescricoes(validas);
      if (porTexto) return porTexto;
      return this._semResultado('IA não configurada (GROQ_API_KEY ausente).');
    }

    const descricoes = validas
      .map((f, i) => (f.descricao || '').trim())
      .map((d, i) => (d ? `Foto ${i + 1}: ${d}` : null))
      .filter(Boolean);

    const lotes = [];
    for (let i = 0; i < validas.length && lotes.length < this.maxLotes; i += this.maxImagensPorChamada) {
      lotes.push(validas.slice(i, i + this.maxImagensPorChamada));
    }

    const leituras = [];
    let modeloUsado = null;
    let ultimoErro = null;

    for (let l = 0; l < lotes.length; l++) {
      const deslocamento = l * this.maxImagensPorChamada;
      let respostaLote = null;

      // Um lote só precisa de UM modelo que funcione. Fixa o que deu certo em
      // lote anterior pra não ficar testando a cadeia inteira de novo — mas só
      // "fixa" um modelo que realmente ACHOU algo (ver comentário abaixo).
      const tentar = modeloUsado ? [modeloUsado] : this.modelos;

      for (const modelo of tentar) {
        try {
          const resultado = await this._chamarModelo(modelo, lotes[l], descricoes);
          if (resultado.length > 0) {
            respostaLote = resultado;
            modeloUsado = modelo;
            break;
          }
          // ⚠️ O modelo RESPONDEU (sem erro) mas não achou nenhuma marcação
          // legível. Isso pode ser a foto mesmo estar ilegível — ou pode ser
          // ESTE modelo que é ruim em OCR de números pequenos. Como não dá
          // pra saber qual dos dois é, tenta o próximo modelo da cadeia antes
          // de desistir do lote. Antes esse caso "travava" no 1º modelo pra
          // sempre (o `break` rodava mesmo com `resultado: []`), desperdiçando
          // os outros 2 modelos da lista de propósito.
          console.warn(`⚠️ [DROP] modelo ${modelo} não achou marcação legível — tentando próximo`);
        } catch (e) {
          ultimoErro = e;
          const status = e.response?.status;
          console.warn(`⚠️ [DROP] modelo ${modelo} falhou (${status || e.message}) — tentando próximo`);
        }
      }

      if (!respostaLote) continue;

      for (const leitura of respostaLote) {
        // O modelo numera as fotos dentro do lote; reindexa pro número global.
        const indiceGlobal = (Number(leitura.foto) || 0) + deslocamento;
        leituras.push({ ...leitura, foto: indiceGlobal });
      }
    }

    if (!leituras.length) {
      const porTexto = this._lerDasDescricoes(validas);
      if (porTexto) return porTexto;
      const motivo = ultimoErro
        ? `A IA não conseguiu ler as fotos (${ultimoErro.response?.status || ultimoErro.message}).`
        : 'A IA não encontrou marcação de metragem nas fotos.';
      return this._semResultado(motivo);
    }

    return this._calcular(leituras, modeloUsado, validas);
  }

  async _chamarModelo(modelo, lote, descricoes) {
    const conteudo = [{ type: 'text', text: this._prompt(descricoes) }];
    for (const foto of lote) {
      conteudo.push({
        type: 'image_url',
        image_url: { url: this._dataUrl(foto.base64) },
      });
    }

    const { data } = await axios.post(
      this.apiUrl,
      {
        model: modelo,
        messages: [{ role: 'user', content: conteudo }],
        temperature: 0,
        max_tokens: 800,
      },
      {
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        timeout: this.timeoutMs,
      },
    );

    const texto = data?.choices?.[0]?.message?.content || '';
    return this._extrairLeituras(texto);
  }

  _dataUrl(base64) {
    // O app manda base64 puro; alguns caminhos mandam já com o prefixo data:.
    if (typeof base64 === 'string' && base64.startsWith('data:')) return base64;
    return `data:image/jpeg;base64,${base64}`;
  }

  /** Aceita JSON cru, JSON dentro de ```json e JSON com texto em volta. */
  _extrairLeituras(texto) {
    if (!texto) return [];
    const limpo = texto.replace(/```json/gi, '').replace(/```/g, '').trim();

    let dados = null;
    try {
      dados = JSON.parse(limpo);
    } catch {
      const inicio = limpo.indexOf('{');
      const fim = limpo.lastIndexOf('}');
      if (inicio === -1 || fim <= inicio) return [];
      try {
        dados = JSON.parse(limpo.slice(inicio, fim + 1));
      } catch {
        return [];
      }
    }

    if (!dados || !Array.isArray(dados.leituras)) return [];

    return dados.leituras
      .map((l) => ({
        foto: Number(l.foto) || 0,
        numero: this._numeroValido(l.numero),
        textoLido: (l.texto_lido || '').toString().slice(0, 40),
        confianca: ['alta', 'media', 'baixa'].includes(l.confianca) ? l.confianca : 'baixa',
        obs: (l.obs || '').toString().slice(0, 200),
      }))
      .filter((l) => l.numero !== null);
  }

  /**
   * Marcação de drop tem no máximo ~5 dígitos e não é negativa. Isso descarta
   * o modelo confundir número de série / MAC / telefone com metragem.
   */
  _numeroValido(valor) {
    // ⚠️ Number(null) é 0 (não NaN), assim como Number('') e Number(false).
    // Sem esta guarda, a leitura "não consegui ler" (numero: null) virava 0 e
    // entrava na subtração como número legítimo — daria "1175 - 0 = 1175
    // metros de drop". Por isso o tipo é checado ANTES da conversão.
    if (valor === null || valor === undefined || typeof valor === 'boolean') return null;
    if (typeof valor === 'string' && valor.trim() === '') return null;

    const n = Number(valor);
    if (!Number.isFinite(n)) return null;
    const inteiro = Math.round(n);
    // Marcação de drop começa em 1: "0 M" não existe no cabo, é leitura ruim.
    if (inteiro < 1 || inteiro > 99999) return null;
    return inteiro;
  }

  /** Rede de segurança sem IA: procura "1175 M" / "1175m" nas descrições. */
  _lerDasDescricoes(fotos) {
    const achados = [];
    fotos.forEach((f, i) => {
      const texto = (f.descricao || '').toString();
      const regex = /(\d{2,5})\s*m\b/gi;
      let m;
      while ((m = regex.exec(texto)) !== null) {
        const n = this._numeroValido(m[1]);
        if (n !== null) {
          achados.push({
            foto: i + 1,
            numero: n,
            textoLido: m[0].trim(),
            confianca: 'media',
            obs: 'lido da descrição escrita pelo técnico',
          });
        }
      }
    });

    if (achados.length < 2) return null;
    return this._calcular(achados, null, fotos, 'descricao');
  }

  _calcular(leituras, modelo, fotos, fonteForcada) {
    const numeros = leituras.map((l) => l.numero).filter((n) => n !== null);

    if (numeros.length < 2) {
      return this._semResultado(
        'Só consegui ler a metragem em uma das fotos. Confira as fotos ou digite os metros na mão.',
        leituras,
      );
    }

    const maior = Math.max(...numeros);
    const menor = Math.min(...numeros);
    const metros = maior - menor;

    // Deu zero = leu o mesmo número duas vezes (provavelmente duas fotos da
    // mesma marcação). Não é resultado válido, e é melhor dizer isso do que
    // devolver "0 metros de drop" e o técnico aceitar sem ler.
    if (metros <= 0) {
      return this._semResultado(
        'Os dois números lidos são iguais — parece que as duas fotos são da mesma marcação.',
        leituras,
      );
    }

    const fonte = fonteForcada
      || (leituras.some((l) => /descri/i.test(l.obs)) ? 'foto+descricao' : 'foto');

    // Confiança final = a PIOR das duas leituras usadas: de nada adianta um
    // número nítido se o outro foi chute, porque o resultado é a subtração.
    const usadas = leituras.filter((l) => l.numero === maior || l.numero === menor);
    const ordem = { baixa: 0, media: 1, alta: 2 };
    const confianca = usadas.reduce(
      (pior, l) => (ordem[l.confianca] < ordem[pior] ? l.confianca : pior),
      'alta',
    );

    // Trecho de drop absurdo quase sempre é dígito lido errado (ex.: 1175 virou
    // 175). Não bloqueia — só avisa, porque existe instalação longa de verdade.
    let aviso = null;
    if (metros > 500) {
      aviso = `${metros} metros é bem acima do normal — confira se os números estão certos.`;
    }

    console.log(
      `📏 [DROP] ${maior} - ${menor} = ${metros}m (fonte: ${fonte}, confiança: ${confianca}${modelo ? `, modelo: ${modelo}` : ''})`,
    );

    return {
      ok: true,
      metros,
      maior,
      menor,
      confianca,
      fonte,
      modelo,
      leituras,
      aviso,
      totalFotos: fotos.length,
    };
  }

  _semResultado(motivo, leituras = []) {
    console.warn(`⚠️ [DROP] sem resultado: ${motivo}`);
    return {
      ok: false,
      metros: null,
      maior: null,
      menor: null,
      confianca: null,
      fonte: null,
      leituras,
      aviso: motivo,
    };
  }
}

module.exports = new DropVisaoService();
