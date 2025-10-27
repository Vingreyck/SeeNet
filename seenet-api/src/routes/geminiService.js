// routes/geminiService.js - VERSÃO CORRIGIDA COM LOGS DETALHADOS
const axios = require('axios');
const logger = require('../config/logger');

class GeminiService {
  constructor() {
    this.apiKey = process.env.GEMINI_API_KEY;
    this.apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
    this.maxRetries = 3;
    this.retryDelay = 2000;
    
    // Validar configuração na inicialização
    this.validateConfig();
  }

  validateConfig() {
    if (!this.apiKey) {
      logger.error('❌ GEMINI_API_KEY não configurada no ambiente!');
      logger.error('Configure a variável de ambiente GEMINI_API_KEY');
      return false;
    }

    if (this.apiKey.length < 30) {
      logger.warn('⚠️ GEMINI_API_KEY parece inválida (muito curta)');
      return false;
    }

    if (!this.apiKey.startsWith('AIza')) {
      logger.warn('⚠️ GEMINI_API_KEY não começa com "AIza" (formato esperado)');
    }

    logger.info('✅ Gemini Service configurado');
    logger.info(`   API Key: ${this.apiKey.substring(0, 8)}...${this.apiKey.slice(-4)}`);
    logger.info(`   URL: ${this.apiUrl}`);
    
    return true;
  }

  async gerarDiagnostico(prompt) {
    const startTime = Date.now();
    
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
      }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 2048,
        topP: 0.8,
        topK: 40
      }
    };

    logger.info('📤 Preparando requisição para Gemini:', {
      promptLength: prompt.length,
      systemPromptLength: systemPrompt.length,
      totalLength: (systemPrompt + prompt).length
    });

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        logger.info(`🔄 Tentativa ${attempt}/${this.maxRetries} - Enviando para Gemini...`);
        
        const attemptStart = Date.now();
        
        const response = await axios.post(this.apiUrl, requestBody, {
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': this.apiKey  // ✅ Header correto conforme documentação Google
          },
          timeout: 30000,
          validateStatus: (status) => status < 500 // Aceitar todos os status < 500 para tratar manualmente
        });

        const attemptDuration = Date.now() - attemptStart;

        logger.info(`📥 Resposta recebida em ${attemptDuration}ms`, {
          status: response.status,
          statusText: response.statusText,
          headers: {
            'content-type': response.headers['content-type'],
            'content-length': response.headers['content-length']
          }
        });

        // Verificar status HTTP
        if (response.status !== 200) {
          const errorData = response.data;
          logger.error(`❌ Erro HTTP ${response.status}:`, errorData);
          
          // Interpretar erros específicos
          if (response.status === 400) {
            throw new Error(`Erro 400: Request inválido - ${errorData.error?.message || 'Verifique formato do request'}`);
          } else if (response.status === 403) {
            throw new Error(`Erro 403: API não habilitada ou token inválido - ${errorData.error?.message || 'Verifique token e permissões'}`);
          } else if (response.status === 404) {
            throw new Error(`Erro 404: Modelo não encontrado - ${errorData.error?.message || 'Verifique URL do endpoint'}`);
          } else if (response.status === 429) {
            throw new Error(`Erro 429: Rate limit excedido - ${errorData.error?.message || 'Aguarde e tente novamente'}`);
          } else {
            throw new Error(`Erro ${response.status}: ${errorData.error?.message || response.statusText}`);
          }
        }

        // Validar estrutura da resposta
        if (!response.data) {
          throw new Error('Resposta vazia da API');
        }

        logger.debug('📄 Estrutura da resposta:', {
          hasCandidates: !!response.data.candidates,
          candidatesLength: response.data.candidates?.length,
          keys: Object.keys(response.data)
        });

        if (!response.data.candidates || response.data.candidates.length === 0) {
          throw new Error('Resposta sem candidates');
        }

        const candidate = response.data.candidates[0];
        
        if (!candidate.content || !candidate.content.parts || candidate.content.parts.length === 0) {
          throw new Error('Candidate sem conteúdo válido');
        }

        const resposta = candidate.content.parts[0].text;

        if (!resposta || resposta.trim().length === 0) {
          throw new Error('Texto da resposta vazio');
        }

        const totalDuration = Date.now() - startTime;
        
        logger.info(`✅ Diagnóstico gerado com sucesso!`, {
          tentativa: attempt,
          duracao: `${totalDuration}ms`,
          comprimentoResposta: resposta.length,
          primeiraLinha: resposta.split('\n')[0].substring(0, 50)
        });

        return resposta;

      } catch (error) {
        const attemptDuration = Date.now() - startTime;
        
        logger.warn(`⚠️ Tentativa ${attempt} falhou após ${attemptDuration}ms:`, {
          error: error.message,
          type: error.constructor.name,
          code: error.code,
          status: error.response?.status
        });

        // Se erro de rede/timeout, vale a pena tentar novamente
        const isRetriable = 
          error.code === 'ECONNRESET' ||
          error.code === 'ETIMEDOUT' ||
          error.code === 'ENOTFOUND' ||
          error.message.includes('timeout') ||
          error.message.includes('network');

        // Se última tentativa ou erro não retriable, propagar erro
        if (attempt === this.maxRetries || !isRetriable) {
          const totalDuration = Date.now() - startTime;
          
          logger.error(`❌ Todas as tentativas falharam após ${totalDuration}ms`);
          
          throw new Error(
            `Falha na API Gemini após ${this.maxRetries} tentativas: ${error.message}`
          );
        }

        // Aguardar com backoff exponencial
        const delay = this.retryDelay * Math.pow(2, attempt - 1);
        logger.info(`⏳ Aguardando ${delay}ms antes da próxima tentativa...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  async testarConexao() {
    try {
      logger.info('🧪 Testando conexão com Gemini...');
      
      const resposta = await this.gerarDiagnostico(
        'Teste de conectividade. Responda apenas: "Gemini funcionando!"'
      );
      
      const sucesso = resposta && resposta.toLowerCase().includes('funcionando');
      
      if (sucesso) {
        logger.info('✅ Teste de conexão bem-sucedido!');
        logger.info(`Resposta: ${resposta.substring(0, 100)}`);
      } else {
        logger.warn('⚠️ Teste retornou resposta inesperada:', resposta);
      }
      
      return sucesso;
      
    } catch (error) {
      logger.error('❌ Teste de conexão falhou:', error.message);
      return false;
    }
  }

  getInfo() {
    return {
      nome: 'Google Gemini 2.0 Flash',
      configurado: !!this.apiKey && this.apiKey.length > 30,
      modelo: 'gemini-2.0-flash-exp',
      endpoint: this.apiUrl,
      limite: '15 req/min (gratuito)',
      maxRetries: this.maxRetries,
      retryDelay: `${this.retryDelay}ms`,
      status: this.apiKey ? 'Configurado' : 'Não configurado'
    };
  }

  debugConfig() {
    logger.info('\n🔍 === DEBUG GEMINI SERVICE ===');
    logger.info('Configurações:');
    logger.info(`  API Key configurada: ${!!this.apiKey}`);
    if (this.apiKey) {
      logger.info(`  API Key: ${this.apiKey.substring(0, 8)}...${this.apiKey.slice(-4)}`);
      logger.info(`  Tamanho: ${this.apiKey.length} caracteres`);
      logger.info(`  Formato válido: ${this.apiKey.startsWith('AIza')}`);
    }
    logger.info(`  URL: ${this.apiUrl}`);
    logger.info(`  Max Retries: ${this.maxRetries}`);
    logger.info(`  Retry Delay: ${this.retryDelay}ms`);
    logger.info('================================\n');
  }
}

module.exports = new GeminiService();