// lib/controllers/diagnostico_controller.dart - VERSÃO FINAL
import 'package:get/get.dart';
import '../models/diagnostico.dart';
import '../models/checkmark.dart';
import '../services/database_helper.dart';
import '../services/gemini_service.dart';

class DiagnosticoController extends GetxController {
  RxList<Diagnostico> diagnosticos = <Diagnostico>[].obs;
  RxBool isLoading = false.obs;
  RxString statusMensagem = ''.obs;

  // Gerar diagnóstico usando Google Gemini
  Future<bool> gerarDiagnostico(int avaliacaoId, int categoriaId, List<Checkmark> checkmarksMarcados) async {
    try {
      isLoading.value = true;
      statusMensagem.value = 'Analisando problemas selecionados...';

      // Montar prompt baseado nos checkmarks marcados
      String prompt = _montarPromptComCheckmarks(checkmarksMarcados);
      
      statusMensagem.value = 'Consultando Google Gemini IA...';
      
      // Tentar com Google Gemini primeiro
      String? resposta = await GeminiService.gerarDiagnosticoComRetry(prompt);
      
      if (resposta != null) {
        statusMensagem.value = 'Salvando diagnóstico...';
        
        // Adicionar cabeçalho indicando que foi gerado pelo Gemini
        String respostaFinal = "**🤖 Diagnóstico gerado por Google Gemini AI**\n\n$resposta";
        
        // Criar diagnóstico
        Diagnostico diagnostico = Diagnostico(
          avaliacaoId: avaliacaoId,
          categoriaId: categoriaId,
          promptEnviado: prompt,
          respostaChatgpt: respostaFinal,
          resumoDiagnostico: _extrairResumo(resposta),
          statusApi: 'sucesso',
          dataCriacao: DateTime.now(),
        );
        
        // Salvar no SQLite
        bool salvou = await DatabaseHelper.instance.salvarDiagnostico(diagnostico);
        
        if (salvou) {
          await carregarDiagnosticos(avaliacaoId);
          statusMensagem.value = 'Diagnóstico concluído com Google Gemini!';
          print('✅ Diagnóstico gerado com Google Gemini e salvo no banco');
          return true;
        } else {
          diagnosticos.add(diagnostico);
          statusMensagem.value = 'Diagnóstico gerado (erro ao salvar no banco)';
          print('⚠️ Diagnóstico gerado mas não salvo no banco SQLite');
          return true;
        }
      } else {
        // Se Gemini falhou, usar diagnóstico simulado
        print('⚠️ Google Gemini não disponível, criando diagnóstico simulado');
        statusMensagem.value = 'Gerando diagnóstico simulado...';
        _criarDiagnosticoSimulado(avaliacaoId, categoriaId, prompt);
        return true;
      }
      
    } catch (e) {
      print('❌ Erro geral ao gerar diagnóstico: $e');
      statusMensagem.value = 'Erro: ${e.toString()}';
      
      // Criar diagnóstico de erro como fallback
      _criarDiagnosticoErro(avaliacaoId, categoriaId, e.toString());
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Montar prompt otimizado para o Gemini
  String _montarPromptComCheckmarks(List<Checkmark> checkmarksMarcados) {
    if (checkmarksMarcados.isEmpty) {
      return "Não foram identificados problemas específicos na análise técnica. Forneça orientações gerais de manutenção preventiva.";
    }

    String prompt = "RELATÓRIO TÉCNICO DE PROBLEMAS IDENTIFICADOS:\n\n";
    
    for (int i = 0; i < checkmarksMarcados.length; i++) {
      var checkmark = checkmarksMarcados[i];
      prompt += "PROBLEMA ${i + 1}:\n";
      prompt += "• Título: ${checkmark.titulo}\n";
      
      if (checkmark.descricao != null && checkmark.descricao!.isNotEmpty) {
        prompt += "• Descrição: ${checkmark.descricao}\n";
      }
      
      // PONTO PRINCIPAL: Usar o prompt específico do checkmark
      if (checkmark.promptChatgpt.isNotEmpty) {
        prompt += "• Contexto técnico: ${checkmark.promptChatgpt}\n";
      }
      
      prompt += "\n";
    }
    
    prompt += "TAREFA:\n";
    prompt += "Analise os problemas listados acima e forneça um diagnóstico técnico completo. ";
    prompt += "Considere que pode haver correlação entre os problemas. ";
    prompt += "Forneça soluções práticas, começando pelas mais simples e eficazes.";
    
    return prompt;
  }

  // Criar diagnóstico simulado quando Gemini não está disponível
  void _criarDiagnosticoSimulado(int avaliacaoId, int categoriaId, String prompt) {
    String diagnosticoSimulado = _gerarDiagnosticoSimuladoInteligente(prompt);
    
    Diagnostico diagnostico = Diagnostico(
      avaliacaoId: avaliacaoId,
      categoriaId: categoriaId,
      promptEnviado: prompt,
      respostaChatgpt: diagnosticoSimulado,
      resumoDiagnostico: _extrairResumo(diagnosticoSimulado),
      statusApi: 'simulado',
      dataCriacao: DateTime.now(),
    );
    
    diagnosticos.add(diagnostico);
    statusMensagem.value = 'Diagnóstico simulado criado!';
    print('📋 Diagnóstico simulado criado como fallback');
  }

  // Gerar diagnóstico simulado inteligente baseado no prompt
  String _gerarDiagnosticoSimuladoInteligente(String prompt) {
    DateTime agora = DateTime.now();
    
    // Analisar o prompt para personalizar a resposta
    List<String> problemas = _extrairProblemasDoPrompt(prompt);
    String categoria = _identificarCategoriaDoPrompt(prompt);
    
    return """🔍 **DIAGNÓSTICO TÉCNICO SIMULADO - ${categoria.toUpperCase()}**

📊 **ANÁLISE REALIZADA:**
Sistema em modo simulado. Foram identificados ${problemas.length} problema(s): ${problemas.join(', ')}.

🎯 **CAUSA PROVÁVEL:**
${_gerarCausasPorCategoria(categoria)}

🛠️ **SOLUÇÕES RECOMENDADAS:**

${_gerarSolucoesPorCategoria(categoria)}

⚠️ **SE PROBLEMA PERSISTIR:**
${_gerarInstrucoesSuporte(categoria)}

✅ **PREVENÇÃO FUTURA:**
${_gerarDicasManutencao(categoria)}

📞 **PRÓXIMOS PASSOS:**
1. Execute as soluções na ordem apresentada
2. Documente os resultados de cada teste
3. Se nenhuma solução funcionar, entre em contato com suporte técnico
4. Mantenha este diagnóstico para referência futura

---
📋 Diagnóstico simulado gerado em ${_formatarDataHora(agora)}

💡 **Para diagnósticos reais com IA:**
Configure Google Gemini gratuitamente em: https://makersuite.google.com/app/apikey
• 15 requisições por minuto
• Qualidade profissional
• Análise personalizada dos seus problemas específicos

🤖 Sistema SeeNet v1.0 - Diagnóstico Técnico Inteligente""";
  }

  // Métodos auxiliares para o diagnóstico simulado
  List<String> _extrairProblemasDoPrompt(String prompt) {
    List<String> problemas = [];
    List<String> linhas = prompt.split('\n');
    
    for (String linha in linhas) {
      if (linha.contains('• Título:')) {
        String problema = linha.replaceAll('• Título:', '').trim();
        if (problema.isNotEmpty) {
          problemas.add(problema);
        }
      }
    }
    
    return problemas.isNotEmpty ? problemas : ['problemas gerais de conectividade'];
  }

  String _identificarCategoriaDoPrompt(String prompt) {
    String promptLower = prompt.toLowerCase();
    
    if (promptLower.contains('lentidão') || promptLower.contains('velocidade') || 
        promptLower.contains('ping') || promptLower.contains('latência')) {
      return 'lentidão';
    } else if (promptLower.contains('iptv') || promptLower.contains('canal') || 
               promptLower.contains('buffering') || promptLower.contains('tv')) {
      return 'iptv';
    } else if (promptLower.contains('aplicativo') || promptLower.contains('app') || 
               promptLower.contains('error code')) {
      return 'aplicativos';
    }
    
    return 'conectividade geral';
  }

  String _gerarCausasPorCategoria(String categoria) {
    switch (categoria) {
      case 'lentidão':
        return """• Sobrecarga na infraestrutura de rede local
• Interferência no sinal WiFi (canal 2.4GHz congestionado)
• Degradação na qualidade do sinal da operadora
• Configurações inadequadas do roteador ou modem
• Excesso de dispositivos conectados simultaneamente
• Problemas físicos nos cabos de rede""";
        
      case 'iptv':
        return """• Largura de banda insuficiente para streaming em alta qualidade
• Problemas na codificação ou transmissão dos canais
• Latência alta da rede causando perda de pacotes
• Configurações incorretas do decodificador ou Smart TV
• Interferência na transmissão de dados multicast
• Problemas no servidor de conteúdo da operadora""";
        
      case 'aplicativos':
        return """• Conectividade intermitente com servidores dos aplicativos
• Cache corrompido ou dados temporários inválidos
• Versões desatualizadas dos aplicativos instalados
• Bloqueios de firewall ou configurações incorretas de proxy
• Problemas na resolução de DNS impedindo acesso aos serviços
• Incompatibilidade entre app e sistema operacional""";
        
      default:
        return """• Problemas gerais na infraestrutura de conectividade
• Configurações de rede inadequadas ou desatualizadas
• Interferências externas afetando a qualidade do sinal
• Equipamentos de rede necessitando manutenção ou substituição
• Problemas na configuração de protocolos de rede""";
    }
  }

  String _gerarSolucoesPorCategoria(String categoria) {
    switch (categoria) {
      case 'lentidão':
        return """**1. TESTE INICIAL (5 minutos)**
   ✓ Execute teste de velocidade em speedtest.net
   ✓ Compare resultado com velocidade contratada
   ✓ Anote horário e resultado do teste

**2. REINICIALIZAÇÃO BÁSICA (5 minutos)**
   ✓ Desligue o roteador da tomada por 30 segundos
   ✓ Desligue o modem por 30 segundos (se separado)
   ✓ Ligue primeiro o modem, aguarde 2 minutos
   ✓ Ligue o roteador e aguarde inicialização completa

**3. OTIMIZAÇÃO WiFi (15 minutos)**
   ✓ Acesse configurações do roteador (192.168.1.1 ou 192.168.0.1)
   ✓ Altere canal WiFi 2.4GHz para 1, 6 ou 11
   ✓ Use rede 5GHz se disponível no seu dispositivo
   ✓ Aproxime dispositivo do roteador para teste
   ✓ Remova interferências (micro-ondas, babá eletrônica)

**4. VERIFICAÇÃO FÍSICA (10 minutos)**
   ✓ Confira todos os cabos de rede (RJ45, coaxial)
   ✓ Procure por conectores soltos ou danificados
   ✓ Teste conexão cabeada diretamente no modem
   ✓ Substitua cabo de rede se necessário""";
        
      case 'iptv':
        return """**1. VERIFICAÇÃO DE LARGURA DE BANDA (5 minutos)**
   ✓ Teste velocidade durante reprodução da IPTV
   ✓ Pause downloads e streaming em outros dispositivos
   ✓ Verifique quantos dispositivos estão usando a rede
   ✓ Reserve pelo menos 25Mbps para IPTV em HD

**2. REINICIALIZAÇÃO DOS EQUIPAMENTOS (10 minutos)**
   ✓ Desligue o decodificador da tomada por 1 minuto
   ✓ Reinicie a Smart TV ou dispositivo de reprodução
   ✓ Reinicie o roteador conforme instruções anteriores
   ✓ Aguarde sincronização completa de todos os equipamentos

**3. CONFIGURAÇÕES DE REDE (15 minutos)**
   ✓ Configure DNS nos dispositivos (8.8.8.8 e 8.8.4.4)
   ✓ Use conexão cabeada no decodificador se possível
   ✓ Configure QoS no roteador priorizando tráfego de vídeo
   ✓ Verifique configurações de multicast no roteador

**4. TESTES DE QUALIDADE (10 minutos)**
   ✓ Teste diferentes canais em diferentes horários
   ✓ Verifique nível de sinal na configuração da TV
   ✓ Documente horários com melhor/pior qualidade""";
        
      case 'aplicativos':
        return """**1. LIMPEZA E RESET BÁSICO (5 minutos)**
   ✓ Force fechamento dos aplicativos problemáticos
   ✓ Limpe cache dos apps nas configurações do dispositivo
   ✓ Reinicie o dispositivo (smartphone, tablet, Smart TV)
   ✓ Reabra os aplicativos e teste novamente

**2. VERIFICAÇÃO DE CONECTIVIDADE (10 minutos)**
   ✓ Teste acesso à internet em outros apps ou navegador
   ✓ Configure DNS manual (8.8.8.8 e 8.8.4.4)
   ✓ Teste usando dados móveis para comparação
   ✓ Verifique se outros dispositivos têm o mesmo problema

**3. ATUALIZAÇÃO E REINSTALAÇÃO (15 minutos)**
   ✓ Verifique atualizações disponíveis na loja de apps
   ✓ Atualize sistema operacional se disponível
   ✓ Desinstale e reinstale aplicativos problemáticos
   ✓ Verifique espaço de armazenamento disponível

**4. CONFIGURAÇÕES AVANÇADAS (10 minutos)**
   ✓ Desative VPN ou proxy temporariamente
   ✓ Verifique configurações de data e hora
   ✓ Configure permissões necessárias para os apps
   ✓ Teste em rede WiFi diferente se possível""";
        
      default:
        return """**1. DIAGNÓSTICO INICIAL (5 minutos)**
   ✓ Teste conectividade básica (ping, navegação)
   ✓ Reinicie todos os equipamentos de rede
   ✓ Verifique status dos LEDs nos equipamentos
   ✓ Teste em dispositivos diferentes

**2. CONFIGURAÇÕES DE REDE (15 minutos)**
   ✓ Configure DNS apropriado (8.8.8.8, 1.1.1.1)
   ✓ Verifique configurações de IP (automático vs manual)
   ✓ Teste conexão cabeada vs wireless
   ✓ Reinicie configurações de rede se necessário

**3. TESTES AVANÇADOS (20 minutos)**
   ✓ Execute teste de ping para gateway local
   ✓ Faça traceroute para servidores externos
   ✓ Monitore estabilidade da conexão por 10 minutos
   ✓ Documente todos os resultados obtidos""";
    }
  }

  String _gerarInstrucoesSuporte(String categoria) {
    switch (categoria) {
      case 'lentidão':
        return """Entre em contato com a operadora informando:
• Resultados completos dos testes de velocidade com horários
• Comparação detalhada entre conexão cabeada e WiFi
• Dispositivos específicos e locais da residência afetados
• Histórico de todas as soluções já testadas
• Horários do dia com melhor e pior performance""";
        
      case 'iptv':
        return """Entre em contato com suporte técnico da IPTV informando:
• Canais específicos com problema e horários de ocorrência
• Mensagens de erro exatas exibidas na tela
• Resultados dos testes de largura de banda
• Modelo e versão do firmware do decodificador/Smart TV
• Configurações de rede testadas (cabeada vs WiFi)""";
        
      case 'aplicativos':
        return """Entre em contato com suporte dos apps ou operadora informando:
• Lista específica de aplicativos afetados
• Códigos de erro exatos apresentados pelos apps
• Versões dos aplicativos e sistema operacional
• Resultados detalhados dos testes (cache, reinstalação)
• Comportamento em redes diferentes (WiFi vs dados móveis)""";
        
      default:
        return """Entre em contato com suporte técnico fornecendo:
• Descrição cronológica detalhada dos problemas
• Horários específicos e padrões de ocorrência
• Lista completa de equipamentos e dispositivos envolvidos
• Histórico detalhado de todos os testes e soluções tentados
• Resultados de ping, traceroute e testes de estabilidade""";
    }
  }

  String _gerarDicasManutencao(String categoria) {
    switch (categoria) {
      case 'lentidão':
        return """• Execute testes de velocidade semanalmente e mantenha histórico
• Atualize firmware do roteador a cada 2-3 meses
• Evite sobrecarga simultânea de muitos dispositivos
• Posicione roteador em local central, elevado e bem ventilado
• Use cabos Cat6 ou superiores para conexões críticas
• Monitore e gerencie dispositivos conectados à rede""";
        
      case 'iptv':
        return """• Reserve largura de banda dedicada para IPTV (mínimo 25Mbps)
• Configure QoS no roteador priorizando tráfego de vídeo/streaming
• Mantenha decodificador em ambiente bem ventilado
• Atualize firmware do decodificador mensalmente
• Prefira sempre conexão cabeada para dispositivos de IPTV
• Monitore qualidade dos canais em diferentes horários""";
        
      case 'aplicativos':
        return """• Mantenha aplicativos sempre atualizados para versões mais recentes
• Execute limpeza de cache dos apps semanalmente
• Evite instalar aplicativos de fontes não confiáveis
• Configure backup automático de configurações importantes
• Monitore e gerencie o consumo de dados e armazenamento
• Revise permissões dos aplicativos periodicamente""";
        
      default:
        return """• Execute manutenção preventiva trimestral em todos os equipamentos
• Monitore performance e estabilidade da rede semanalmente
• Mantenha documentação atualizada de todas as configurações
• Implemente rotinas de backup para configurações críticas
• Capacite usuários sobre uso adequado dos recursos de rede
• Mantenha inventário atualizado de equipamentos e versões""";
    }
  }

  // Carregar diagnósticos de uma avaliação
  Future<void> carregarDiagnosticos(int avaliacaoId) async {
    try {
      diagnosticos.value = await DatabaseHelper.instance.getDiagnosticosPorAvaliacao(avaliacaoId);
      print('✅ ${diagnosticos.length} diagnósticos carregados do banco');
    } catch (e) {
      print('❌ Erro ao carregar diagnósticos: $e');
    }
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
    
    // Se não encontrou, usar primeiras linhas úteis
    List<String> linhasUteis = linhas
        .where((linha) => linha.trim().isNotEmpty && 
               !linha.startsWith('---') && 
               !linha.startsWith('**🤖'))
        .take(2)
        .toList();
    
    String resumo = linhasUteis.join(' ').trim();
    return resumo.length > 120 ? '${resumo.substring(0, 120)}...' : resumo;
  }

  // Criar diagnóstico de erro
  void _criarDiagnosticoErro(int avaliacaoId, int categoriaId, String erro) {
    String diagnosticoErro = """❌ **ERRO NO SISTEMA DE DIAGNÓSTICO**

Não foi possível gerar o diagnóstico automaticamente devido a um erro técnico.

**Detalhes do erro:** $erro

**Ações recomendadas imediatas:**
1. Verifique sua conexão com a internet
2. Tente realizar o diagnóstico novamente em alguns minutos
3. Se o problema persistir, execute as verificações básicas abaixo

**VERIFICAÇÕES BÁSICAS EMERGENCIAIS:**

🔧 **Reinicialização Completa:**
• Desligue roteador e modem por 30 segundos
• Ligue primeiro o modem, aguarde 2 minutos
• Ligue o roteador e aguarde inicialização

🔧 **Teste de Conectividade:**
• Teste velocidade em speedtest.net
• Verifique conexão cabeada vs WiFi
• Teste em dispositivos diferentes

🔧 **Verificação Física:**
• Confira todos os cabos de rede
• Procure por conectores soltos
• Verifique LEDs dos equipamentos

📞 **Suporte Técnico:**
Se os problemas persistirem após estas verificações, entre em contato com o suporte técnico informando:
• Este código de erro: ${erro.hashCode.abs()}
• Horário da ocorrência: ${DateTime.now()}
• Descrição dos problemas identificados
• Resultados dos testes básicos realizados

---
⚠️ Este é um diagnóstico de emergência gerado pelo sistema.
Para diagnósticos completos, configure uma IA como Google Gemini.""";

    Diagnostico diagnostico = Diagnostico(
      avaliacaoId: avaliacaoId,
      categoriaId: categoriaId,
      promptEnviado: "Erro no sistema",
      respostaChatgpt: diagnosticoErro,
      resumoDiagnostico: "Erro no sistema: ${erro.length > 50 ? erro.substring(0, 50) + '...' : erro}",
      statusApi: 'erro',
      erroApi: erro,
      dataCriacao: DateTime.now(),
    );
    
    diagnosticos.add(diagnostico);
    print('📋 Diagnóstico de erro criado como fallback final');
  }

  // Método auxiliar para formatar data e hora
  String _formatarDataHora(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  // Limpar diagnósticos
  void limparDiagnosticos() {
    diagnosticos.clear();
    statusMensagem.value = '';
    print('🧹 Diagnósticos limpos da memória');
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

  // Limpar apenas status
  void limparStatus() {
    statusMensagem.value = '';
  }

  // Método para testar conectividade do Gemini
  Future<bool> testarGemini() async {
    print('🧪 Iniciando teste de conectividade com Google Gemini...');
    return await GeminiService.testarConexao();
  }

  // Obter informações sobre o Gemini
  Map<String, String> get infoGemini => GeminiService.getInfo();

  // Verificar se Gemini está configurado
  bool get geminiConfigurado => GeminiService.isConfigured;

  // Debug - mostrar configurações
  void debugConfiguracoes() {
    GeminiService.debugConfiguracoes();
  }
}