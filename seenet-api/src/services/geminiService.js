const axios = require('axios');
const logger = require('../config/logger');

class GeminiService {
  constructor() {
    this.apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
    this.model = 'llama-3.3-70b-versatile';
    this.maxRetries = 3;
    this.retryDelay = 1000;
  }

  // Getter que lê sempre na hora certa
  get apiKey() {
    return process.env.GROQ_API_KEY;
  }

  get apiKey() {
    const key = process.env.GROQ_API_KEY;
    console.log('🔑 GROQ_API_KEY:', key ? key.substring(0, 15) + '...' : 'UNDEFINED');
    console.log('🔑 Todas as vars:', Object.keys(process.env).filter(k => k.includes('GROQ') || k.includes('API')));
    return key;
  }

  async gerarDiagnostico(prompt) {
    console.log('\n🤖 === INICIANDO CHAMADA GROQ ===');

    if (!this.apiKey) {
      console.error('❌ Chave da API Groq não configurada (GROQ_API_KEY)');
      throw new Error('Chave da API Groq não configurada');
    }

    console.log('✅ API Key configurada:', this.apiKey.substring(0, 10) + '...');
    console.log('🌐 Modelo:', this.model);

    const systemPrompt = `Você é técnico sênior em internet/IPTV. Sua missão é guiar técnicos de campo de forma ultra-objetiva.

    ---
    ### 🧠 REGRAS DE COMPORTAMENTO (IMPORTANTE):
    1. SE o usuário iniciar um problema ou enviar um checkmark: Use OBRIGATORIAMENTE o "FORMATO ESTRUTURADO" abaixo.
    2. SE o usuário estiver apenas tirando uma dúvida ou comentando sobre a resposta anterior: NÃO use o formato estruturado. Responda de forma direta e conversacional e que seja breve.
    3. CONTEXTO: Fale APENAS sobre tecnologia, redes, roteadores, IPTV, equipamentos e coisas relacionados a provedora seja aparelhos/EPI e etc. Se o assunto fugir disso, peça para focar no trabalho.

    ---
    ### 📋 REGRAS DE FORMATAÇÃO (Para novos diagnósticos):
    1. PASSOS NUMERADOS curtos e objetivos (máximo 1 linha cada).
    2. Máximo 3-6 passos por bloco.
    3. Linguagem simples e clara.
    4. Comece SEMPRE com a solução mais rápida.
    5. Use emojis para tornar mais visual.

    ---
    ### 🔧 FORMATO ESTRUTURADO OBRIGATÓRIO:

    🔧 **SOLUÇÃO RÁPIDA (2 min):**
    1. [ação]
    2. [ação]
    3. [resultado]

    🔧 **SE NÃO RESOLVER (5 min):**
    1. [ação]
    2. [ação]
    3. [ação]
    4. [ação]
    3. [resultado]

    ⚠️ **AINDA COM PROBLEMA:**
    "Ligue para o gerente informando o problema"

    ✅ **DICA RÁPIDA:**
    [dica curta]`;

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        console.log(`\n🚀 Tentativa ${attempt}/${this.maxRetries} - Enviando para Groq...`);

        const response = await axios.post(
          this.apiUrl,
          {
            model: this.model,
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: prompt }
            ],
            max_tokens: 1024,
            temperature: 0.7,
          },
          {
            headers: {
              'Authorization': `Bearer ${this.apiKey}`,
              'Content-Type': 'application/json',
            },
            timeout: 30000
          }
        );

        if (response.status === 200) {
          const resposta = response.data?.choices?.[0]?.message?.content;

          if (resposta) {
            logger.info(`✅ Diagnóstico gerado com sucesso (tentativa ${attempt})`);
            logger.info('📝 Conteúdo:', resposta.substring(0, 200) + '...');
            return resposta;
          } else {
            logger.warn('⚠️ Resposta sem texto válido');
          }
        }

        throw new Error('Resposta inválida da API');

      } catch (error) {
        console.error(`\n❌ FALHA GROQ - Tentativa ${attempt}/${this.maxRetries}`);
        console.error('📍 Mensagem:', error.message);

        if (error.response) {
          console.error('   Status:', error.response.status);
          console.error('   Data:', JSON.stringify(error.response.data, null, 2));

          // 429 = rate limit — aguarda mais tempo
          if (error.response.status === 429) {
            console.warn('⏳ Rate limit atingido, aguardando...');
            await new Promise(resolve => setTimeout(resolve, this.retryDelay * attempt * 2));
            continue;
          }
        }

        if (attempt === this.maxRetries) {
          logger.error('❌ Todas as tentativas falharam');
          const finalError = new Error(`Falha na API Groq após ${this.maxRetries} tentativas`);
          finalError.originalError = error;
          throw finalError;
        }

        await new Promise(resolve => setTimeout(resolve, this.retryDelay * attempt));
      }
    }
  }

  async chatDiagnostico(mensagem, historico, contexto) {
    const key = this.apiKey;
    if (!key) throw new Error('Chave da API Groq não configurada');

    const messages = [
      {
        role: 'system',
        content: `Você é um técnico sênior de redes/ISP. Responda de forma direta e conversacional.
  Fale APENAS sobre redes. Se o assunto fugir disso, redirecione para o problema técnico. Use emojis pontualmente.

  CONTEXTO DO DIAGNÓSTICO ATUAL:
  ${contexto}`
      },
      ...historico.map(m => ({
        role: m.role === 'user' ? 'user' : 'assistant',
        content: m.content
      })),
      { role: 'user', content: mensagem }
    ];

    const response = await axios.post(
      this.apiUrl,
      { model: this.model, messages, max_tokens: 512, temperature: 0.7 },
      {
        headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
        timeout: 30000
      }
    );

    return response.data?.choices?.[0]?.message?.content;
  }

  async testarConexao() {
    try {
      const resposta = await this.gerarDiagnostico('Teste simples. Responda apenas: "Groq funcionando!"');
      return resposta && resposta.toLowerCase().includes('funcionando');
    } catch (error) {
      logger.error('Teste de conexão Groq falhou:', error);
      return false;
    }
  }

  getInfo() {
    return {
      nome: 'Groq — Llama 3.3 70B',
      configurado: !!this.apiKey,
      modelo: this.model,
      limite: '1.000 req/dia (gratuito)',
      status: this.apiKey ? 'Configurado' : 'Não configurado'
    };
  }
}

module.exports = new GeminiService();