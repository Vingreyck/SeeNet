import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'widgets/logarbutton.widget.dart';
import 'widgets/logintextfield.widget.dart';
import 'widgets/senhatextfield.dart';
import 'widgets/registrarbutton.widget.dart';
import 'loginview.controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(0, 0, 0, 0),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B7280), // Cinza médio no topo
              Color(0xFF4B5563), // Cinza médio-escuro
              Color(0xFF374151), // Cinza escuro
              Color(0xFF1F2937), // Cinza muito escuro
              Color(0xFF111827), // Quase preto
              Color(0xFF0F0F0F), // Preto profundo
            ],
            stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'SeeNet',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00FF99),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Expanded(child: _body()), // Usa o método abaixo
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return Center(
      child: ListView(
        padding: const EdgeInsets.all(40),
        children: const [
          LoginTextField(),
          SizedBox(height: 30),
          SenhaTextField(),
          SizedBox(height: 60), // ← ESPAÇAMENTO AUMENTADO (era 50)
          LogarButton(),
          SizedBox(height: 30), // ← ESPAÇAMENTO AUMENTADO (era 20)
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white,
                  thickness: 1,
                  endIndent: 10,
                ),
              ),
              Text(
                'ou',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white,
                  thickness: 1,
                  indent: 10,
                ),
              ),
            ],
          ),
          SizedBox(height: 30), // ← ESPAÇAMENTO AUMENTADO (era 20)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ainda não tem uma conta?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 5),
              RegistrarButton(),
            ],
          ),
        ],
      ),
    );
  }
}