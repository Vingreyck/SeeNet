// test_auth_flow.dart - Arquivo temporário para debug
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthFlowDebugger {
  static Future<void> testarFluxoCompleto() async {
    print('\n🧪 === TESTE DE FLUXO DE AUTENTICAÇÃO ===\n');
    
    final api = ApiService.instance;
    final auth = Get.find<AuthService>();
    
    // 1. Testar antes do login
    print('1️⃣ Testando ANTES do login:');
    try {
      await api.get('/admin/stats/quick', requireAuth: true);
      print('   ❌ ERRO: Deveria falhar sem auth');
    } catch (e) {
      print('   ✅ Falhou como esperado: $e');
    }
    
    // 2. Fazer login
    print('\n2️⃣ Fazendo login...');
    bool loginOk = await auth.login(
      'admin@seenet.com',
      'admin123',
      'DEMO2024',
    );
    
    if (loginOk) {
      print('   ✅ Login bem-sucedido');
    } else {
      print('   ❌ Falha no login');
      return;
    }
    
    // 3. Testar após o login
    print('\n3️⃣ Testando APÓS o login:');
    try {
      final response = await api.get('/admin/stats/quick', requireAuth: true);
      if (response['success']) {
        print('   ✅ Requisição autenticada funcionou!');
        print('   📊 Dados: ${response['data']}');
      } else {
        print('   ❌ Requisição retornou erro: ${response['error']}');
      }
    } catch (e) {
      print('   ❌ Erro na requisição: $e');
    }
    
    // 4. Testar endpoint de logs
    print('\n4️⃣ Testando endpoint de logs:');
    try {
      final response = await api.get(
        '/admin/logs',
        queryParams: {'limite': '10', 'offset': '0'},
        requireAuth: true,
      );
      
      if (response['success']) {
        print('   ✅ Endpoint de logs funcionou!');
        var logs = response['data'];
        print('   📊 Estrutura: ${logs.keys}');
      } else {
        print('   ❌ Erro: ${response['error']}');
      }
    } catch (e) {
      print('   ❌ Erro na requisição: $e');
    }
    
    print('\n========================================\n');
  }
}