const axios = require('axios');
const logger = require('../config/logger');

class GeminiService {
  constructor() {
    this.apiKey = process.env.GEMINI_API_KEY;
    this.apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
    this.maxRetries = 1;
    this.retryDelay = 1000;
  }

  
  async gerarDiagnostico(prompt) {
    console.log('\n🤖 === INICIANDO CHAMADA GEMINI ===');
    
    if (!this.apiKey) {
      console.error('❌ Chave da API Gemini não configurada');
      throw new Error('Chave da API Gemini não configurada');
    }
    
    console.log('✅ API Key configurada:', this.apiKey.substring(0, 10) + '...');
    console.log('🌐 URL da API:', this.apiUrl);
    
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

    const requestBody = {
      contents: [{
        parts: [{
          text: `${systemPrompt}\n\n${prompt}`
        }]
      }]
    };

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        console.log(`\n🚀 Tentativa ${attempt}/${this.maxRetries} - Enviando para Gemini...`);
        console.log('📦 Request body:', JSON.stringify(requestBody, null, 2));
        
        const headers = {
          'Content-Type': 'application/json',
          'X-goog-api-key': this.apiKey
        };
        
        console.log('🔤 Headers:', {
          ...headers,
          'X-goog-api-key': headers['X-goog-api-key'].substring(0, 10) + '...'
        });
        
        const response = await axios.post(this.apiUrl, requestBody, {
          headers,
          timeout: 60000 // 60 segundos
        });

        if (response.status === 200) {
          logger.info('📥 Resposta Gemini:', JSON.stringify(response.data, null, 2));
          
          if (response.data.candidates) {
            const resposta = response.data.candidates[0]?.content?.parts?.[0]?.text;
            
            if (resposta) {
              logger.info(`✅ Diagnóstico gerado com sucesso (tentativa ${attempt})`);
              logger.info('📝 Conteúdo:', resposta.substring(0, 200) + '...');
              return resposta;
            } else {
              logger.warn('⚠️ Resposta sem texto válido');
              logger.warn('📦 Candidates:', JSON.stringify(response.data.candidates, null, 2));
            }
          } else {
            logger.warn('⚠️ Resposta sem candidates');
          }
        }

        throw new Error('Resposta inválida da API');

      } catch (error) {
  // ===== LOGS DETALHADOS =====
  console.error('\n❌ ========================================');
  console.error(`❌ FALHA GEMINI - Tentativa ${attempt}/${this.maxRetries}`);
  console.error('❌ ========================================');
  console.error('📍 Tipo:', error.constructor.name);
  console.error('📍 Mensagem:', error.message);
  console.error('📍 Código:', error.code || 'N/A');
  
  // Se tiver resposta HTTP
  if (error.response) {
    console.error('\n🔴 RESPOSTA HTTP DE ERRO:');
    console.error('   Status:', error.response.status);
    console.error('   Status Text:', error.response.statusText);
    console.error('   Headers:', JSON.stringify(error.response.headers, null, 2));
    console.error('   Data (body):', JSON.stringify(error.response.data, null, 2));
  } else if (error.request) {
    console.error('\n🔴 REQUEST FOI ENVIADO MAS SEM RESPOSTA:');
    console.error('   Request:', error.request);
  } else {
    console.error('\n🔴 ERRO ANTES DE ENVIAR REQUEST:');
    console.error('   Detalhes:', error.message);
  }
  
  console.error('\n📚 Stack trace:');
  console.error(error.stack);
  console.error('❌ ========================================\n');
  
  // Logs antigos do logger (manter)
  logger.warn('\n⚠️ === FALHA NA CHAMADA GEMINI ===');
  logger.warn(`Tentativa ${attempt}/${this.maxRetries}`);
  logger.warn('Tipo de erro:', error.constructor.name);
  logger.warn('Mensagem:', error.message);

  if (error.response) {
    logger.error('Detalhes da resposta de erro:');
    logger.error('Status:', error.response.status);
    logger.error('Status Text:', error.response.statusText);
    logger.error('Data:', JSON.stringify(error.response.data, null, 2));
    logger.error('Headers:', JSON.stringify(error.response.headers, null, 2));
  }

  if (attempt === this.maxRetries) {
    console.error('\n💥 ========================================');
    console.error('💥 TODAS AS 3 TENTATIVAS FALHARAM!');
    console.error('💥 ========================================');
    console.error('🔥 Último erro completo:', JSON.stringify({
      message: error.message,
      code: error.code,
      status: error.response?.status,
      statusText: error.response?.statusText,
      responseData: error.response?.data
    }, null, 2));
    console.error('💥 ========================================\n');
    
    logger.error('\n❌ === TODAS AS TENTATIVAS FALHARAM ===');
    logger.error('Stack trace:', error.stack);
    
    const finalError = new Error(`Falha na API Gemini após ${this.maxRetries} tentativas`);
    finalError.originalError = error;
    finalError.lastResponse = error.response;
    finalError.attempts = this.maxRetries;
    throw finalError;
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
      nome: 'Google Gemini 2.5 Flash',
      configurado: !!this.apiKey,
      modelo: 'gemini-2.5-flash',
      limite: '15 req/min (gratuito)',
      status: this.apiKey ? 'Configurado' : 'Não configurado'
    };
  }
}

module.exports = new GeminiService();
