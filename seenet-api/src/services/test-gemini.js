// test-gemini.js - SCRIPT STANDALONE PARA TESTAR TOKEN GEMINI
// Execute com: node test-gemini.js

require('dotenv').config();
const axios = require('axios');

async function testarGemini() {
  console.log('\n🧪 === TESTE DO TOKEN GEMINI ===\n');
  
  // 1. Verificar se token está configurado
  const apiKey = process.env.GEMINI_API_KEY;
  
  if (!apiKey) {
    console.error('❌ ERRO: GEMINI_API_KEY não encontrada no .env');
    console.log('\n💡 Configure o token no arquivo .env:');
    console.log('   GEMINI_API_KEY=sua_chave_aqui');
    console.log('\n🔑 Obtenha sua chave em:');
    console.log('   https://makersuite.google.com/app/apikey');
    return false;
  }
  
  console.log(`✅ Token encontrado: ${apiKey.substring(0, 8)}...${apiKey.slice(-4)}`);
  console.log(`📏 Tamanho: ${apiKey.length} caracteres`);
  
  // 2. Validar formato do token
  if (apiKey.length < 30) {
    console.warn('⚠️ Token parece muito curto (esperado ~39 caracteres)');
  }
  
  if (!apiKey.startsWith('AIza')) {
    console.warn('⚠️ Token não começa com "AIza" (formato esperado do Google)');
  }
  
  // 3. Testar modelos disponíveis
  console.log('\n📋 Testando listagem de modelos...');
  
  try {
    const modelsUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
    const modelsResponse = await axios.get(modelsUrl, {
      params: { key: apiKey },
      timeout: 10000
    });
    
    console.log('✅ Listagem de modelos bem-sucedida!');
    console.log(`📊 ${modelsResponse.data.models?.length || 0} modelos disponíveis`);
    
    if (modelsResponse.data.models) {
      console.log('\n🤖 Modelos Gemini disponíveis:');
      modelsResponse.data.models
        .filter(m => m.name.includes('gemini'))
        .slice(0, 5)
        .forEach(model => {
          console.log(`   • ${model.name.split('/').pop()}`);
        });
    }
    
  } catch (error) {
    console.error('❌ Erro ao listar modelos:', error.response?.status, error.message);
    
    if (error.response?.status === 403) {
      console.log('\n💡 Erro 403 indica:');
      console.log('   1. Token inválido ou expirado');
      console.log('   2. API não habilitada no projeto');
      console.log('\n🔧 Soluções:');
      console.log('   1. Gere novo token em: https://makersuite.google.com/app/apikey');
      console.log('   2. Habilite a API em: https://console.cloud.google.com/apis/library');
    }
    
    return false;
  }
  
  // 4. Testar geração de conteúdo
  console.log('\n🧠 Testando geração de conteúdo...');
  
  const testUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
  
  const requestBody = {
    contents: [{
      parts: [{
        text: 'Teste de conectividade. Responda apenas: "Gemini funcionando!"'
      }]
    }]
  };
  
  try {
    const startTime = Date.now();
    
    const response = await axios.post(testUrl, requestBody, {
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey
      },
      timeout: 30000
    });
    
    const duration = Date.now() - startTime;
    
    console.log(`✅ Resposta recebida em ${duration}ms`);
    console.log(`📊 Status: ${response.status}`);
    
    if (response.data.candidates && response.data.candidates.length > 0) {
      const text = response.data.candidates[0].content.parts[0].text;
      console.log(`\n📝 Resposta do Gemini:\n`);
      console.log(`   "${text}"\n`);
      
      if (text.toLowerCase().includes('funcionando')) {
        console.log('✅✅✅ TESTE COMPLETO: Token Gemini está funcionando perfeitamente! ✅✅✅');
        return true;
      } else {
        console.log('⚠️ Gemini respondeu, mas não como esperado');
        return true; // Ainda funciona, só resposta inesperada
      }
    } else {
      console.log('⚠️ Resposta sem candidates:', JSON.stringify(response.data, null, 2));
      return false;
    }
    
  } catch (error) {
    console.error('\n❌ ERRO ao gerar conteúdo:', error.message);
    
    if (error.response) {
      console.log('\n📄 Detalhes do erro:');
      console.log(`   Status: ${error.response.status}`);
      console.log(`   Status Text: ${error.response.statusText}`);
      
      if (error.response.data) {
        console.log(`   Mensagem: ${JSON.stringify(error.response.data, null, 2)}`);
      }
      
      // Interpretar erros comuns
      switch (error.response.status) {
        case 400:
          console.log('\n💡 Erro 400 (Bad Request):');
          console.log('   - Request body malformado');
          console.log('   - Verifique formato do JSON');
          break;
          
        case 403:
          console.log('\n💡 Erro 403 (Forbidden):');
          console.log('   - Token inválido ou expirado');
          console.log('   - API não habilitada no projeto Google Cloud');
          console.log('   - Projeto suspenso ou sem billing');
          console.log('\n🔧 Soluções:');
          console.log('   1. Gere novo token: https://makersuite.google.com/app/apikey');
          console.log('   2. Habilite a API: https://console.cloud.google.com/apis/library');
          console.log('   3. Verifique billing: https://console.cloud.google.com/billing');
          break;
          
        case 404:
          console.log('\n💡 Erro 404 (Not Found):');
          console.log('   - Modelo não encontrado');
          console.log('   - URL do endpoint incorreta');
          console.log(`   - Atual: ${testUrl}`);
          break;
          
        case 429:
          console.log('\n💡 Erro 429 (Rate Limit):');
          console.log('   - Limite de requisições excedido (15/min no plano grátis)');
          console.log('   - Aguarde 1 minuto e tente novamente');
          console.log('   - Considere upgrade de plano para mais quota');
          break;
          
        case 500:
        case 503:
          console.log('\n💡 Erro 5xx (Servidor):');
          console.log('   - Problema temporário no Google');
          console.log('   - Tente novamente em alguns minutos');
          break;
          
        default:
          console.log(`\n💡 Erro ${error.response.status} não mapeado`);
      }
    } else if (error.code === 'ECONNREFUSED') {
      console.log('\n💡 Conexão recusada:');
      console.log('   - Sem acesso à internet');
      console.log('   - Firewall bloqueando conexão');
      console.log('   - Proxy não configurado');
    } else if (error.code === 'ETIMEDOUT') {
      console.log('\n💡 Timeout:');
      console.log('   - Conexão muito lenta');
      console.log('   - Gemini demorando muito para responder');
      console.log('   - Tente aumentar timeout');
    } else {
      console.log('\n💡 Erro de rede/conexão:', error.code || 'desconhecido');
    }
    
    return false;
  }
}

// 5. Informações adicionais
function mostrarInfos() {
  console.log('\n📚 === INFORMAÇÕES ADICIONAIS ===\n');
  
  console.log('🔗 Links Úteis:');
  console.log('   • API Keys: https://makersuite.google.com/app/apikey');
  console.log('   • Docs: https://ai.google.dev/tutorials/rest_quickstart');
  console.log('   • Console: https://console.cloud.google.com/');
  console.log('   • Quota: https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas');
  
  console.log('\n💰 Limites do Plano Gratuito:');
  console.log('   • 15 requisições por minuto');
  console.log('   • 1,500 requisições por dia');
  console.log('   • 1 milhão tokens por mês');
  
  console.log('\n🔐 Segurança:');
  console.log('   • NUNCA commite tokens no Git');
  console.log('   • Use variáveis de ambiente (.env)');
  console.log('   • Adicione .env ao .gitignore');
  console.log('   • Revogue tokens expostos imediatamente');
  
  console.log('\n🐛 Debug:');
  console.log('   • Verifique logs com winston/morgan');
  console.log('   • Use request IDs para rastrear');
  console.log('   • Monitore quota no Google Console');
  console.log('   • Configure alertas de erro');
  
  console.log('\n════════════════════════════════════\n');
}

// Executar teste
(async () => {
  const sucesso = await testarGemini();
  mostrarInfos();
  
  if (sucesso) {
    console.log('🎉 SUCESSO TOTAL! Token Gemini está configurado e funcionando.\n');
    process.exit(0);
  } else {
    console.log('❌ FALHA! Corrija os problemas acima antes de continuar.\n');
    process.exit(1);
  }
})();