import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:seenet/checklist/widgets/checkmark_enviar.widget.dart';


class Diagnosticoview extends StatelessWidget {
  const Diagnosticoview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: const Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            CheckmarkEnviarWidget(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}