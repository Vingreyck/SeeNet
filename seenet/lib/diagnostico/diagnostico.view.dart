// lib/diagnostico/diagnostico.view.dart - VERSÃO ATUALIZADA
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../controllers/diagnostico_controller.dart';
import '../controllers/checkmark_controller.dart';
import '../models/diagnostico.dart';
import '../models/checkmark.dart';

class Diagnosticoview extends StatefulWidget {
  const Diagnosticoview({super.key});

  @override
  State<Diagnosticoview> createState() => _DiagnosticoviewState();
}

class _DiagnosticoviewState extends State<Diagnosticoview> {
  late DiagnosticoController diagnosticoController;
  late CheckmarkController checkmarkController;
  final TextEditingController perguntaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Inicializar controllers se não existirem
    if (Get.isRegistered<DiagnosticoController>()) {
      diagnosticoController = Get.find<DiagnosticoController>();
    } else {
      diagnosticoController = Get.put(DiagnosticoController());
    }
    
    if (Get.isRegistered<CheckmarkController>()) {
      checkmarkController = Get.find<CheckmarkController>();
    } else {
      checkmarkController = Get.put(CheckmarkController());
    }
    
    _gerarDiagnostico();
  }

  void _gerarDiagnostico() async {
    print('🔥 Iniciando geração de diagnóstico...');

    // Verificar se há avaliação ativa
    if (checkmarkController.avaliacaoAtual.value == null) {
      print('⚠️ Nenhuma avaliação ativa - criando diagnóstico de demonstração');
      _criarDiagnosticoDemo();
      return;
    }

    // Verificar se há checkmarks marcados
    List<int> checkmarksMarcadosIds = checkmarkController.checkmarksMarcados;
    print('📝 Checkmarks marcados: $checkmarksMarcadosIds');
    
    if (checkmarksMarcadosIds.isEmpty) {
      Get.snackbar(
        'Aviso',
        'Nenhum problema foi selecionado',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      
      // Criar diagnóstico de exemplo mesmo sem problemas selecionados
      _criarDiagnosticoDemo();
      return;
    }

    // Buscar objetos dos checkmarks marcados
    List<Checkmark> checkmarksMarcados = checkmarkController.checkmarksAtivos
        .where((checkmark) => checkmarksMarcadosIds.contains(checkmark.id))
        .toList();

    print('🎯 Checkmarks para diagnóstico: ${checkmarksMarcados.map((c) => c.titulo).join(', ')}');

    // Gerar diagnóstico real com ChatGPT
    bool sucesso = await diagnosticoController.gerarDiagnostico(
      checkmarkController.avaliacaoAtual.value!.id!,
      checkmarkController.categoriaAtual.value,
      checkmarksMarcados,
    );

    if (!sucesso) {
      print('❌ Falha na geração de diagnóstico');
      Get.snackbar(
        'Erro',
        'Erro ao gerar diagnóstico. Criando diagnóstico de exemplo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      
      // Como fallback, criar diagnóstico de exemplo
      _criarDiagnosticoDemo();
    } else {
      print('✅ Diagnóstico gerado com sucesso');
    }
  }

  void _criarDiagnosticoDemo() {
    print('🎭 Criando diagnóstico de demonstração');
    
    // Simular delay
    Future.delayed(const Duration(seconds: 2), () {
      // Simular resposta do ChatGPT
      String diagnosticoExemplo = """🔍 **DIAGNÓSTICO TÉCNICO DEMONSTRAÇÃO**

📊 **ANÁLISE REALIZADA:**
Sistema em modo de demonstração. Este é um exemplo de como o diagnóstico apareceria com problemas reais selecionados.

🎯 **CAUSA PROVÁVEL:**
• Sobrecarga na rede local
• Interferência no sinal WiFi
• Possível degradação do sinal da operadora

🛠️ **SOLUÇÕES RECOMENDADAS:**

**1. REINICIALIZAÇÃO BÁSICA (5 min)**
   ✓ Desligue o roteador por 30 segundos
   ✓ Aguarde inicialização completa (2-3 minutos)
   ✓ Teste novamente a conexão

**2. VERIFICAÇÃO FÍSICA (10 min)**
   ✓ Confira todos os cabos de rede
   ✓ Procure por conectores soltos
   ✓ Teste conexão cabeada diretamente

**3. OTIMIZAÇÃO WiFi (15 min)**
   ✓ Mude o canal WiFi (1, 6 ou 11)
   ✓ Aproxime dispositivos do roteador
   ✓ Remova interferências (micro-ondas, etc.)

**4. TESTE DE VELOCIDADE**
   ✓ Realize teste em horário alternativo
   ✓ Compare com velocidade contratada

⚠️ **SE PERSISTIR:**
Entre em contato com a operadora informando os testes realizados.

✅ **PREVENÇÃO:**
• Atualize firmware mensalmente
• Monitore dispositivos conectados
• Evite sobrecarga simultânea

---
📋 Diagnóstico de demonstração - Configure sua chave do ChatGPT para diagnósticos reais""";

      // Adicionar diagnóstico na lista
      diagnosticoController.diagnosticos.add(
        Diagnostico(
          id: 1,
          avaliacaoId: 1,
          categoriaId: 1,
          promptEnviado: "Diagnóstico de demonstração",
          respostaChatgpt: diagnosticoExemplo,
          resumoDiagnostico: "Diagnóstico de demonstração - Configure ChatGPT para funcionalidade completa",
          statusApi: 'sucesso',
          dataCriacao: DateTime.now(),
        )
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF6B7280),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Get.offAllNamed('/checklist');
          },
        ),
        title: const Text(
          'Diagnóstico IA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B7280),
              Color(0xFF4B5563),
              Color(0xFF374151),
              Color(0xFF1F2937),
              Color(0xFF111827),
              Color(0xFF0F0F0F),
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 1),
            // Logo SVG centralizada
            Center(
              child: Container(
                width: 360,
                height: 360,
                padding: const EdgeInsets.all(1),
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 1),
            
            // Status do diagnóstico
            Obx(() {
              if (diagnosticoController.statusMensagem.value.isNotEmpty) {
                return Container(
                  width: double.infinity,
                  color: const Color(0xFF4A4A4A),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      if (diagnosticoController.isLoading.value)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00FF88),
                          ),
                        ),
                      if (diagnosticoController.isLoading.value) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          diagnosticoController.statusMensagem.value,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // Título padrão quando não há status
              return Container(
                width: double.infinity,
                color: const Color(0xFF4A4A4A),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Text(
                  'Diagnóstico Inteligente',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              );
            }),
            
            // Área de diagnóstico
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFF2A2A2A),
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  // Loading enquanto gera diagnóstico
                  if (diagnosticoController.isLoading.value) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFF00FF88),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            diagnosticoController.statusMensagem.value.isNotEmpty 
                                ? diagnosticoController.statusMensagem.value
                                : 'Gerando diagnóstico...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1F1F),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '🤖 Analisando problemas selecionados\n💡 Consultando inteligência artificial\n📋 Preparando soluções personalizadas',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Mostra diagnósticos
                  if (diagnosticoController.diagnosticos.isNotEmpty) {
                    return ListView.builder(
                      itemCount: diagnosticoController.diagnosticos.length,
                      itemBuilder: (context, index) {
                        final diagnostico = diagnosticoController.diagnosticos[index];
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: diagnostico.isSucesso 
                                  ? const Color(0xFF00FF88).withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status do diagnóstico
                              Row(
                                children: [
                                  Icon(
                                    diagnostico.isSucesso ? Icons.check_circle : Icons.error,
                                    color: diagnostico.isSucesso 
                                        ? const Color(0xFF00FF88) 
                                        : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    diagnostico.isSucesso ? 'Diagnóstico Concluído' : 'Erro no Diagnóstico',
                                    style: TextStyle(
                                      color: diagnostico.isSucesso 
                                          ? const Color(0xFF00FF88) 
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Indicador se é ChatGPT real ou simulado
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: diagnostico.promptEnviado.contains('demonstração') 
                                          ? Colors.orange.withOpacity(0.2)
                                          : Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: diagnostico.promptEnviado.contains('demonstração') 
                                            ? Colors.orange
                                            : Colors.blue,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      diagnostico.promptEnviado.contains('demonstração') ? 'DEMO' : 'CHATGPT',
                                      style: TextStyle(
                                        color: diagnostico.promptEnviado.contains('demonstração') 
                                            ? Colors.orange
                                            : Colors.blue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // TEXTO DO DIAGNÓSTICO EM BRANCO
                              Text(
                                diagnostico.respostaChatgpt,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Informações adicionais
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Timestamp
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 16, color: Colors.white54),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Gerado em: ${_formatarData(diagnostico.dataCriacao)}',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Mostrar prompt se disponível
                                    if (diagnostico.promptEnviado.isNotEmpty && 
                                        !diagnostico.promptEnviado.contains('demonstração')) ...[
                                      const SizedBox(height: 8),
                                      const Divider(color: Colors.white24, height: 1),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.psychology, size: 16, color: Colors.white54),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Prompt enviado:',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0A0A0A),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Text(
                                          diagnostico.promptEnviado.length > 200 
                                              ? '${diagnostico.promptEnviado.substring(0, 200)}...'
                                              : diagnostico.promptEnviado,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  // Mensagem quando não há diagnóstico
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.psychology_outlined,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum diagnóstico disponível',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Volte para o checklist e selecione problemas para gerar um diagnóstico',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => Get.offAllNamed('/checklist'),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Voltar ao Checklist'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF88),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            
            // Campo de input na parte inferior
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: perguntaController,
                        decoration: const InputDecoration(
                          hintText: 'Pergunte algo sobre o diagnóstico',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Ícone do microfone
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3A3A3A),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.mic, color: Colors.white70, size: 24),
                      onPressed: () {
                        Get.snackbar(
                          'Funcionalidade',
                          'Reconhecimento de voz será implementado em breve',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.blue,
                          colorText: Colors.white,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Ícone de envio
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FF88),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.black,
                        size: 24,
                      ),
                      onPressed: () {
                        if (perguntaController.text.isNotEmpty) {
                          // Aqui você pode implementar chat adicional no futuro
                          Get.snackbar(
                            'Funcionalidade',
                            'Chat adicional será implementado em breve',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.blue,
                            colorText: Colors.white,
                          );
                          perguntaController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return 'Data não disponível';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    perguntaController.dispose();
    super.dispose();
  }
}