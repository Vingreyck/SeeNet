const axios = require('axios');

const IXC_URL = 'https://ixc.bbnetup.com.br/webservice/v1';
const IXC_TOKEN = '122:c4865552439b671842f0c3d34fcf6e5213a7d5ad2b029964d042426f157ddad2';

const endpoints = [
  'su_oss_chamado',
  'su_os',
  'su_ordem_servico', 
  'ordem_servico',
  'ordens_servico',
  'os',
  'oss',
  'su_chamados',
  'chamado',
  'chamados',
  'atendimento',
  'atendimentos',
  'cliente',
  'su_atendimento'
];

async function testarEndpoints() {
  console.log('='.repeat(60));
  console.log('TESTANDO ENDPOINTS COM POST (MÉTODO CORRETO)');
  console.log('='.repeat(60) + '\n');
  
  let encontrados = [];
  
  for (const endpoint of endpoints) {
    try {
      process.stdout.write(`📡 ${endpoint.padEnd(25)}`);
      
      // USAR POST COM URLSearchParams (CORRETO!)
      const params = new URLSearchParams({
        qtype: 'id',
        query: '',
        oper: '!=',
        page: '1',
        rp: '5'
      });
      
      const response = await axios.post(`${IXC_URL}/${endpoint}`, params.toString(), {
        headers: {
          'Authorization': `Basic ${Buffer.from(IXC_TOKEN).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
          'ixcsoft': 'listar'
        },
        timeout: 8000
      });
      
      const qtd = response.data.registros?.length || 0;
      const total = response.data.total || 0;
      
      console.log(`✅ OK! (${qtd} registros / ${total} total)`);
      
      if (qtd > 0) {
        encontrados.push({
          endpoint,
          qtd,
          total,
          primeiro: response.data.registros[0]
        });
      }
      
    } catch (error) {
      if (error.response?.status === 404) {
        console.log(`❌ Não existe`);
      } else if (error.response?.status === 401 || error.response?.status === 403) {
        console.log(`🔒 Sem permissão`);
      } else if (error.code === 'ECONNABORTED') {
        console.log(`⏱️ Timeout`);
      } else {
        console.log(`⚠️ Erro: ${error.message}`);
      }
    }
    
    // Pequena pausa entre requests
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  console.log('\n' + '='.repeat(60));
  console.log('ENDPOINTS QUE RETORNARAM DADOS:');
  console.log('='.repeat(60));
  
  if (encontrados.length === 0) {
    console.log('\n❌ Nenhum endpoint retornou dados!');
    console.log('\n💡 Possíveis causas:');
    console.log('   1. Token sem permissão para OSs');
    console.log('   2. Não existem OSs no sistema');
    console.log('   3. Endpoint tem nome diferente');
    console.log('   4. Filtros de setor/funcionário bloqueando');
  } else {
    encontrados.forEach((item, index) => {
      console.log(`\n${index + 1}. 📋 Endpoint: ${item.endpoint}`);
      console.log(`   Total: ${item.total} registros`);
      console.log(`   Campos disponíveis: ${Object.keys(item.primeiro).join(', ')}`);
      console.log(`   Exemplo ID: ${item.primeiro.id}`);
    });
  }
  
  console.log('\n' + '='.repeat(60));
}

testarEndpoints()
  .then(() => console.log('\n✅ Teste concluído!\n'))
  .catch(err => console.error('\n❌ Erro fatal:', err.message));