// lib/views/admin/widgets/checkmark_admin_dialog.dart
// ADICIONAR ESTA VALIDAÇÃO NO DIALOG DE CRIAR/EDITAR CHECKMARK

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CheckmarkAdminDialog {
  // ========== DIALOG PARA CRIAR CHECKMARK ==========
  static Future<void> showCreateDialog({
    required BuildContext context,
    required Function(Map<String, dynamic>) onCreate,
    required List<Map<String, dynamic>> categorias,
  }) async {
    final formKey = GlobalKey<FormState>();
    final tituloController = TextEditingController();
    final descricaoController = TextEditingController();
    final promptController = TextEditingController();
    int? categoriaSelecionada;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Novo Checkmark',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Categoria
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                  ),
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  items: categorias.map((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'],
                      child: Text(cat['nome']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    categoriaSelecionada = value;
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione uma categoria';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Título
                TextFormField(
                  controller: tituloController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Digite um título';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Descrição
                TextFormField(
                  controller: descricaoController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ✅ PROMPT COM VALIDAÇÃO DE 10 CARACTERES
                TextFormField(
                  controller: promptController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Prompt Gemini',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: 'Descreva o problema para o Gemini analisar',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Digite um prompt';
                    }
                    // ✅ VALIDAÇÃO: MÍNIMO 10 CARACTERES
                    if (value.length < 10) {
                      return 'O prompt deve ter no mínimo 10 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // ✅ CONTADOR DE CARACTERES
                Align(
                  alignment: Alignment.centerRight,
                  child: ValueListenableBuilder(
                    valueListenable: promptController,
                    builder: (context, TextEditingValue value, child) {
                      final length = value.text.length;
                      final color = length < 10 ? Colors.red : Colors.green;
                      return Text(
                        '$length caracteres (mínimo 10)',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // ✅ VALIDAR ANTES DE CRIAR
              if (formKey.currentState!.validate()) {
                if (categoriaSelecionada == null) {
                  // ✅ POPUP DE ERRO
                  Get.snackbar(
                    'Erro',
                    'Selecione uma categoria',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                  );
                  return;
                }

                // ✅ VALIDAR PROMPT NOVAMENTE (double-check)
                if (promptController.text.length < 10) {
                  // ✅ POPUP DE ERRO DETALHADO
                  Get.dialog(
                    AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      title: Row(
                        children: const [
                          Icon(Icons.error_outline, color: Colors.red, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Prompt inválido',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      content: Text(
                        'O prompt do Gemini deve conter no mínimo 10 caracteres para garantir uma análise adequada.\n\n'
                        'Atualmente: ${promptController.text.length} caracteres\n'
                        'Mínimo necessário: 10 caracteres',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text(
                            'Entendi',
                            style: TextStyle(color: Color(0xFF00FF88)),
                          ),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                onCreate({
                  'categoria_id': categoriaSelecionada,
                  'titulo': tituloController.text,
                  'descricao': descricaoController.text,
                  'prompt_gemini': promptController.text,
                });
                
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
            ),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  // ========== DIALOG PARA EDITAR CHECKMARK ==========
  static Future<void> showEditDialog({
    required BuildContext context,
    required Map<String, dynamic> checkmark,
    required Function(Map<String, dynamic>) onUpdate,
    required List<Map<String, dynamic>> categorias,
  }) async {
    final formKey = GlobalKey<FormState>();
    final tituloController = TextEditingController(text: checkmark['titulo']);
    final descricaoController = TextEditingController(text: checkmark['descricao']);
    final promptController = TextEditingController(text: checkmark['prompt_gemini']);
    int? categoriaSelecionada = checkmark['categoria_id'];
    bool ativo = checkmark['ativo'] ?? true;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'Editar Checkmark',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Categoria
                  DropdownButtonFormField<int>(
                    value: categoriaSelecionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    items: categorias.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['id'],
                        child: Text(cat['nome']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        categoriaSelecionada = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Título
                  TextFormField(
                    controller: tituloController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Digite um título';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Descrição
                  TextFormField(
                    controller: descricaoController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // ✅ PROMPT COM VALIDAÇÃO
                  TextFormField(
                    controller: promptController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Prompt Gemini',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Digite um prompt';
                      }
                      if (value.length < 10) {
                        return 'O prompt deve ter no mínimo 10 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder(
                      valueListenable: promptController,
                      builder: (context, TextEditingValue value, child) {
                        final length = value.text.length;
                        final color = length < 10 ? Colors.red : Colors.green;
                        return Text(
                          '$length caracteres (mínimo 10)',
                          style: TextStyle(color: color, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Ativo
                  SwitchListTile(
                    title: const Text(
                      'Ativo',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: ativo,
                    activeColor: const Color(0xFF00FF88),
                    onChanged: (value) {
                      setState(() {
                        ativo = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // ✅ VALIDAÇÃO ADICIONAL
                  if (promptController.text.length < 10) {
                    Get.dialog(
                      AlertDialog(
                        backgroundColor: const Color(0xFF2A2A2A),
                        title: Row(
                          children: const [
                            Icon(Icons.error_outline, color: Colors.red, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Prompt inválido',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        content: Text(
                          'O prompt do Gemini deve conter no mínimo 10 caracteres.\n\n'
                          'Atual: ${promptController.text.length} caracteres',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text(
                              'Entendi',
                              style: TextStyle(color: Color(0xFF00FF88)),
                            ),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  onUpdate({
                    'id': checkmark['id'],
                    'categoria_id': categoriaSelecionada,
                    'titulo': tituloController.text,
                    'descricao': descricaoController.text,
                    'prompt_gemini': promptController.text,
                    'ativo': ativo,
                  });
                  
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}