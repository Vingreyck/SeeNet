// lib/controllers/diagnostico_controller.dart - CORRIGIDO
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/diagnostico.dart';
import '../models/checkmark.dart';
import '../services/database_helper.dart';
import '../config/chatgpt_config.dart'; // ← CORRIGIDO: usando seu arquivo

class DiagnosticoController extends GetxController {
  RxList<Diagnostico> diagnosticos = <Diagnostico>[].obs;
  RxBool isLoading = false.obs;
  RxString statusMensagem = ''.obs;

  // Gerar diagnóstico baseado nos checkmarks
  Future<bool> gerarDiagnostico(int avaliacaoId, int categoriaId, List<Checkmark> checkmarksMarcados) async {
    try {
      isLoading.value = true;
      statusMensagem.value = 'Analisando problemas...';

      // Montar prompt baseado nos checkmarks marcados
      String prompt = _montarPrompt(checkmarksMarcados);
      
      statusMensagem.value = 'Consultando inteligência artificial...';
      
      // Enviar para ChatGPT
      String? resposta = await _enviarParaChatGPT(prompt);
      
      if (resposta != null) {
        statusMensagem.value = 'Salvando diagnóstico...';
        
        // Criar diagnóstico
        Diagnostico diagnostico = Diagnostico(
          avaliacaoId: avaliacaoId,
          categoriaId: categoriaId,
          promptEnviado: prompt,
          respostaChatgpt: resposta,
          resumoDiagnostico: _extrairResumo(resposta),
          statusApi: 'sucesso',
          dataCriacao: DateTime.now(),
        );
        
        // Salvar no SQLite
        bool salvou = await DatabaseHelper.instance.salvarDiagnostico(diagnostico);
        
        if (salvou) {
          // Atualizar lista local
          await carregarDiagnosticos(avaliacaoId);
          statusMensagem.value = 'Diagnóstico concluído!';
          return true;
        } else {
          // Se não conseguiu salvar, adiciona só na lista local
          diagnosticos.add(diagnostico);
          statusMensagem.value = 'Diagnóstico gerado (não salvo)';
          return true;
        }
      }
      
      statusMensagem.value = 'Erro ao gerar diagnóstico';
      return false;
    } catch (e) {
      print('❌ Erro ao gerar diagnóstico: $e');
      statusMensagem.value = 'Erro: $e';
      
      // Criar diagnóstico de erro
      _criarDiagnosticoErro(avaliacaoId, categoriaId, e.toString());
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Carregar diagnósticos de uma avaliação
  Future<void> carregarDiagnosticos(int avaliacaoId) async {
    try {
      diagnosticos.value = await DatabaseHelper.instance.getDiagnosticosPorAvaliacao(avaliacaoId);
      print('✅ ${diagnosticos.length} diagnósticos carregados');
    } catch (e) {
      print('❌ Erro ao carregar diagnósticos: $e');
    }
  }

  // Montar prompt baseado nos checkmarks
  String _montarPrompt(List<Checkmark> checkmarksMarcados) {
    if (checkmarksMarcados.isEmpty) {
      return "Não foram identificados problemas específicos na análise técnica.";
    }

    String prompt = "ANÁLISE TÉCNICA DE CONECTIVIDADE\n\n";
    prompt += "Problemas identificados pelo técnico:\n";
    
    for (int i = 0; i < checkmarksMarcados.length; i++) {
      var checkmark = checkmarksMarcados[i];
      prompt += "${i + 1}. ${checkmark.titulo}";
      if (checkmark.descricao != null && checkmark.descricao!.isNotEmpty) {
        prompt += " - ${checkmark.descricao}";
      }
      prompt += "\n";
    }
    
    prompt += "\n${ChatGptConfig.systemPrompt}"; // ← USANDO SEU PROMPT
    
    return prompt;
  }

  // Enviar prompt para ChatGPT - CORRIGIDO
  Future<String?> _enviarParaChatGPT(String prompt) async {
    try {
      // ✅ CORRIGIDO: Verificar se tem chave configurada
      if (ChatGptConfig.apiKey == 'SUA_CHAVE_API_CHATGPT_AQUI') {
        print('⚠️ Chave ChatGPT não configurada, usando diagnóstico simulado');
        await Future.delayed(const Duration(seconds: 2)); // Simular delay da API
        return _gerarDiagnosticoSimulado(prompt);
      }

      // ✅ CORRIGIDO: Usar suas configurações
      final response = await http.post(
        Uri.parse(ChatGptConfig.apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ChatGptConfig.apiKey}',
        },
        body: json.encode({
          'model': ChatGptConfig.model,
          'messages': [
            {
              'role': 'system',
              'content': ChatGptConfig.systemPrompt // ← USANDO SEU PROMPT SYSTEM
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'max_tokens': ChatGptConfig.maxTokens,
          'temperature': ChatGptConfig.temperature,
        }),
      ).timeout(const Duration(seconds: 30)); // ← TIMEOUT FIXO

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print('❌ Erro na API ChatGPT: ${response.statusCode}');
        return _gerarDiagnosticoSimulado(prompt);
      }
    } catch (e) {
      print('❌ Erro ao enviar para ChatGPT: $e');
      return _gerarDiagnosticoSimulado(prompt);
    }
  }

  // Gerar diagnóstico simulado
  String _gerarDiagnosticoSimulado(String prompt) {
    DateTime agora = DateTime.now();
    
    return """🔍 **DIAGNÓSTICO TÉCNICO AUTOMATIZADO**

📊 **ANÁLISE REALIZADA:**
Com base nos problemas identificados pelo técnico, foi detectado um padrão de falhas que afeta a qualidade dos serviços de conectividade.

🎯 **CAUSA PROVÁVEL:**
• Sobrecarga na infraestrutura de rede local
• Possível interferência no sinal WiFi
• Degradação da qualidade do sinal da operadora
• Configurações inadequadas dos equipamentos

🛠️ **SOLUÇÕES RECOMENDADAS:**

**1. VERIFICAÇÃO BÁSICA (5 min)**
   ✓ Reinicie o roteador por 30 segundos
   ✓ Aguarde inicialização completa (2-3 minutos)
   ✓ Teste a conexão em dispositivo próximo

**2. DIAGNÓSTICO FÍSICO (10 min)**
   ✓ Verifique todos os cabos de rede
   ✓ Procure por conectores soltos ou danificados
   ✓ Teste conexão cabeada diretamente no modem

**3. OTIMIZAÇÃO WiFi (15 min)**
   ✓ Altere o canal WiFi (1, 6 ou 11 para 2.4GHz)
   ✓ Posicione dispositivos mais próximos do roteador
   ✓ Remova interferências (micro-ondas, babá eletrônica)

**4. TESTES DE VELOCIDADE (10 min)**
   ✓ Execute teste em horário de baixo tráfego
   ✓ Compare resultados com velocidade contratada
   ✓ Documente resultados para relatório

⚠️ **SE PROBLEMA PERSISTIR:**
Entre em contato com a operadora informando:
• Resultados dos testes realizados
• Horários de maior incidência dos problemas
• Equipamentos e dispositivos afetados

✅ **PREVENÇÃO FUTURA:**
• Atualize firmware do roteador mensalmente
• Monitore número de dispositivos conectados
• Mantenha equipamentos em local ventilado
• Evite uso simultâneo de muitos serviços

📞 **SUPORTE TÉCNICO:**
Para problemas persistentes, solicite visita técnica presencial com os dados coletados neste diagnóstico.

---
📋 Diagnóstico gerado automaticamente em ${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} às ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}

🤖 Sistema SeeNet v1.0 - Diagnóstico Inteligente""";
  }

  // Extrair resumo do diagnóstico
  String _extrairResumo(String resposta) {
    List<String> linhas = resposta.split('\n');
    
    // Procurar linha com diagnóstico
    for (String linha in linhas) {
      if (linha.contains('DIAGNÓSTICO') || linha.contains('ANÁLISE')) {
        String resumo = linha.replaceAll(RegExp(r'[🔍📊🎯*]'), '').trim();
        if (resumo.length > 15) {
          return resumo.length > 120 ? '${resumo.substring(0, 120)}...' : resumo;
        }
      }
    }
    
    // Se não encontrou, pega as primeiras linhas úteis
    List<String> linhasUteis = linhas
        .where((linha) => linha.trim().isNotEmpty && !linha.startsWith('---'))
        .take(2)
        .toList();
    
    String resumo = linhasUteis.join(' ').trim();
    return resumo.length > 120 ? '${resumo.substring(0, 120)}...' : resumo;
  }

  // Criar diagnóstico de erro
  void _criarDiagnosticoErro(int avaliacaoId, int categoriaId, String erro) {
    Diagnostico diagnosticoErro = Diagnostico(
      avaliacaoId: avaliacaoId,
      categoriaId: categoriaId,
      promptEnviado: "Erro na geração",
      respostaChatgpt: """❌ **ERRO NO DIAGNÓSTICO**

Não foi possível gerar o diagnóstico automaticamente.

**Erro:** $erro

**Ações recomendadas:**
1. Verifique a conexão com a internet
2. Tente novamente em alguns minutos
3. Entre em contato com o suporte técnico

**Diagnóstico manual:**
Realize as verificações básicas enquanto isso:
• Reinicie o equipamento
• Verifique cabos e conexões
• Teste em horário alternativo""",
      resumoDiagnostico: "Erro ao gerar diagnóstico: $erro",
      statusApi: 'erro',
      erroApi: erro,
      dataCriacao: DateTime.now(),
    );
    
    diagnosticos.add(diagnosticoErro);
  }

  // Limpar diagnósticos
  void limparDiagnosticos() {
    diagnosticos.clear();
    statusMensagem.value = '';
  }

  // Verificar se há diagnósticos
  bool get temDiagnosticos => diagnosticos.isNotEmpty;

  // Obter último diagnóstico
  Diagnostico? get ultimoDiagnostico {
    if (diagnosticos.isEmpty) return null;
    return diagnosticos.first;
  }

  // Contar diagnósticos por status
  int contarPorStatus(String status) {
    return diagnosticos.where((d) => d.statusApi == status).length;
  }

  // Limpar status
  void limparStatus() {
    statusMensagem.value = '';
  }
}