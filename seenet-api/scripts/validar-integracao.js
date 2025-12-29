const axios = require('axios');

const BASE_URL = 'https://seenet-production.up.railway.app';

async function validarIntegracao() {
  console.log('🧪 === VALIDAÇÃO DE INTEGRAÇÃO IXC ===\n');
  
  const testes = [];
  
  // Teste 1: IP atual
  try {
    const r1 = await axios.get(`${BASE_URL}/api/debug/meu-ip-agora`);
    testes.push({ 
      teste: '1. IP Railway', 
      status: '✅ PASSOU',
      ip: r1.data.ip_atual_railway 
    });
  } catch (e) {
    testes.push({ teste: '1. IP Railway', status: '❌ FALHOU', erro: e.message });
  }
  
  // Teste 2: Conexão IXC
  try {
    const r2 = await axios.get(`${BASE_URL}/api/debug/test-ixc-listar-modulos`);
    testes.push({ 
      teste: '2. Conexão IXC', 
      status: r2.data.total_colaboradores > 0 ? '✅ PASSOU' : '⚠️ VAZIO',
      detalhes: `${r2.data.total_colaboradores} colaboradores`
    });
  } catch (e) {
    testes.push({ teste: '2. Conexão IXC', status: '❌ FALHOU', erro: e.message });
  }
  
  // Teste 3: OSs disponíveis
  try {
    const r3 = await axios.get(`${BASE_URL}/api/debug/test-ixc-todas-os`);
    testes.push({ 
      teste: '3. OSs no IXC', 
      status: r3.data.total > 0 ? '✅ PASSOU' : '⚠️ VAZIO',
      detalhes: `${r3.data.total} OSs encontradas`
    });
  } catch (e) {
    testes.push({ teste: '3. OSs no IXC', status: '❌ FALHOU', erro: e.message });
  }
  
  console.log('\n📊 RESULTADOS:\n');
  testes.forEach(t => {
    console.log(`${t.status} ${t.teste}`);
    if (t.detalhes) console.log(`   ${t.detalhes}`);
    if (t.erro) console.log(`   Erro: ${t.erro}`);
  });
  
  const passou = testes.filter(t => t.status === '✅ PASSOU').length;
  const total = testes.length;
  
  console.log(`\n${passou}/${total} testes passaram`);
  
  if (passou === total) {
    console.log('\n🎉 INTEGRAÇÃO 100% FUNCIONAL!');
  } else {
    console.log('\n⚠️ Alguns testes falharam. Revise a configuração.');
  }
}

validarIntegracao();