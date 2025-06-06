import 'package:flutter/material.dart';
import 'package:get/get.dart';


class Diagnosticoview extends StatelessWidget {
  const Diagnosticoview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
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
            const SizedBox(height: 24),
            // Logo centralizada
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00E87C), // Verde da logo
                ),
                child: Icon(
                  Icons.eco_rounded, // Ícone similar à folha do print
                  size: 140,
                  color: Colors.black.withOpacity(0.01), // Deixe invisível, só para manter o espaço
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Título Diagnóstico
            Container(
              width: double.infinity,
              color: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: const Text(
                'Diagnóstico',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Diagnóstico texto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. “O problema provável é que o roteador não está atribuindo IPs automaticamente (falha no DHCP).”',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '2. “Pode ser uma falha no serviço DHCP ou problema na conexão com a WAN.”',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '3. “Verifique se o cabo de entrada da operadora está corretamente conectado e reinicie o roteador. Caso o erro persista, configure IP manualmente como solução temporária.”',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Pergunte alguma coisa',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF232323),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}