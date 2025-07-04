// lib/diagnostico/diagnostico.view.dart
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
    // Simular diagnóstico se não há avaliação real
    if (checkmarkController.avaliacaoAtual.value == null) {
      // Criar diagnóstico de exemplo para demonstração
      await Future.delayed(const Duration(seconds: 2));
      
      // Simular resposta do ChatGPT
      String diagnosticoExemplo = """🔍 DIAGNÓSTICO TÉCNICO

Com base nos problemas identificados, foi detectado:

📊 ANÁLISE:
• Velocidade abaixo do contratado
• Latência alta (ping > 100ms)
• Perda de pacotes intermitente

🎯 CAUSA PROVÁVEL:
Sobrecarga na rede local ou interferência no sinal WiFi.

🛠️ SOLUÇÕES RECOMENDADAS:

1. REINICIALIZAÇÃO DO EQUIPAMENTO
   - Desligue o roteador por 30 segundos
   - Aguarde a inicialização completa

2. VERIFICAÇÃO FÍSICA
   - Confira cabos de rede (conectores soltos)
   - Teste conexão cabeada diretamente

3. OTIMIZAÇÃO WiFi
   - Mude o canal WiFi (1, 6 ou 11)
   - Aproxime dispositivos do roteador
   - Remova interferências (micro-ondas, etc.)

4. TESTE DE VELOCIDADE
   - Realize teste em horário alternativo
   - Compare com velocidade contratada

⚠️ SE PERSISTIR:
Entre em contato com a operadora informando os testes realizados.

✅ PREVENÇÃO:
- Atualize firmware do roteador mensalmente
- Monitore dispositivos conectados
- Evite sobrecarga simultânea""";

      // Simular salvamento no controller
      diagnosticoController.diagnosticos.add(
        Diagnostico(
          id: 1,
          avaliacaoId: 1,
          categoriaId: 1,
          promptEnviado: "Diagnóstico de problemas de lentidão",
          respostaChatgpt: diagnosticoExemplo,
          resumoDiagnostico: "Problemas de lentidão detectados. Soluções: reiniciar roteador, verificar cabos, otimizar WiFi.",
          statusApi: 'sucesso',
        )
      );
      return;
    }

    // Código real para quando tiver avaliação ativa
    List<int> checkmarksMarcadosIds = checkmarkController.checkmarksMarcados;
    
    if (checkmarksMarcadosIds.isEmpty) {
      Get.snackbar(
        'Aviso',
        'Nenhum problema foi selecionado',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    List<Checkmark> checkmarksMarcados = checkmarkController.checkmarksAtivos
        .where((checkmark) => checkmarksMarcadosIds.contains(checkmark.id))
        .toList();

    bool sucesso = await diagnosticoController.gerarDiagnostico(
      checkmarkController.avaliacaoAtual.value!.id!,
      1,
      checkmarksMarcados,
    );

    if (!sucesso) {
      Get.snackbar(
        'Erro',
        'Erro ao gerar diagnóstico',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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
            // Título Diagnóstico
            Container(
              width: double.infinity,
              color: const Color(0xFF4A4A4A),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                'Diagnóstico',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            // Área de diagnóstico - AQUI É ONDE APARECE O TEXTO DO CHATGPT
            Expanded(
              child: Container(
                width: double.infinity,
                color: const Color(0xFF2A2A2A),
                padding: const EdgeInsets.all(16),
                child: Obx(() {
                  // Loading enquanto gera diagnóstico
                  if (diagnosticoController.isLoading.value) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF00FF88),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Gerando diagnóstico...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
                              color: const Color(0xFF00FF88).withOpacity(0.3),
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
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // TEXTO DO DIAGNÓSTICO EM BRANCO - AQUI É O PRINCIPAL
                              Text(
                                diagnostico.respostaChatgpt,
                                style: const TextStyle(
                                  color: Colors.white,  // 👈 TEXTO BRANCO AQUI
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Timestamp
                              Text(
                                'Gerado em: ${_formatarData(diagnostico.dataCriacao)}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  // Mensagem quando não há diagnóstico
                  return const Center(
                    child: Text(
                      'Nenhum diagnóstico disponível',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
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
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Ícone de envio
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: const Color(0xFF00FF88),
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