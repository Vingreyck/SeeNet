const axios = require('axios');
const logger = require('../config/logger');

class GeminiService {
  constructor() {
    this.apiKey = process.env.GEMINI_API_KEY;
    this.apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
    this.maxRetries = 3;
    this.retryDelay = 2000; // 2 segundos
  }

  async gerarDiagnostico(prompt) {
    if (!this.apiKey) {
      throw new Error('Chave da API Gemini não configurada');
    }

    const systemPrompt = `Você é um técnico especialista em internet/IPTV. Suas respostas devem ser EXTREMAMENTE DIRETAS e PRÁTICAS.

REGRAS OBRIGATÓRIAS:
1. Use apenas PASSOS NUMERADOS curtos e objetivos
2. Máximo 3-5 passos por solução
3. Linguagem simples e clara (não seja técnico demais)
4. Comece SEMPRE com a solução mais rápida
5. Cada passo deve ter no máximo 1 linha
6. Use emojis para facilitar visualização

FORMATO OBRIGATÓRIO:

🔧 **SOLUÇÃO RÁPIDA (2 min):**
1. [ação específica]
2. [ação específica]
3. [resultado esperado]

🔧 **SE NÃO RESOLVER (5 min):**
1. [próxima ação]
2. [próxima ação]
3. [testar resultado]

⚠️ **AINDA COM PROBLEMA:**
"Ligue para a operadora informando: [info específica]"

✅ **DICA RÁPIDA:**
[uma dica preventiva em 1 linha]

IMPORTANTE: Seja direto, prático e focado na solução imediata.`;

    const requestBody = {
      contents: [{
        parts: [{
          text: `${systemPrompt}\n\n${prompt}`
        }]
      }]
    };

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        logger.info(`🚀 Tentativa ${attempt}/${this.maxRetries} - Enviando para Gemini...`);

        const response = await axios.post(this.apiUrl, requestBody, {
          headers: {
            'Content-Type': 'application/json',
            'X-goog-api-key': this.apiKey
          },
          timeout: 30000 // 30 segundos
        });

        if (response.status === 200 && response.data.candidates) {
          const resposta = response.data.candidates[0]?.content?.parts?.[0]?.text;
          
          if (resposta) {
            logger.info(`✅ Diagnóstico gerado com sucesso (tentativa ${attempt})`);
            return resposta;
          }
        }

        throw new Error('Resposta inválida da API');

      } catch (error) {
        logger.warn(`⚠️ Tentativa ${attempt} falhou:`, error.message);

        if (attempt === this.maxRetries) {
          logger.error('❌ Todas as tentativas falharam');
          throw new Error(`Falha na API Gemini após ${this.maxRetries} tentativas: ${error.message}`);
        }

        // Aguardar antes da próxima tentativa
        await new Promise(resolve => setTimeout(resolve, this.retryDelay * attempt));
      }
    }
  }

  async testarConexao() {
    try {
      const resposta = await this.gerarDiagnostico('Teste simples. Responda apenas: "Gemini funcionando!"');
      return resposta && resposta.includes('funcionando');
    } catch (error) {
      logger.error('Teste de conexão Gemini falhou:', error);
      return false;
    }
  }

  getInfo() {
    return {
      nome: 'Google Gemini 2.0 Flash',
      configurado: !!this.apiKey,
      modelo: 'gemini-2.0-flash',
      limite: '15 req/min (gratuito)',
      status: this.apiKey ? 'Configurado' : 'Não configurado'
    };
  }
}

module.exports = new GeminiService();
