  import 'package:flutter/material.dart';
  import 'package:flutter_svg/flutter_svg.dart';
  import 'package:get/get.dart';
  import 'package:flutter/services.dart';
  import 'widgets/logarbutton.widget.dart';
  import 'widgets/logintextfield.widget.dart';
  import 'widgets/senhatextfield.dart';
  import 'widgets/registrarbutton.widget.dart';
  import 'widgets/codigoempresa_textfield.dart';
  import 'loginview.controller.dart';
  
  class LoginView extends GetView<LoginController> {
    const LoginView({super.key});
  
    @override
    Widget build(BuildContext context) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
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
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
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
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ),
      );
    }
  
    Widget _body() {
      return Center(
        child: ListView(
          padding: const EdgeInsets.all(40),
          children: [
            const LoginTextField(),
            const SizedBox(height: 30),
            const SenhaTextField(),
            const SizedBox(height: 30),
            const CodigoEmpresaTextField(),
            const SizedBox(height: 60),
            const LogarButton(),
            
            const SizedBox(height: 30),
            const Row(
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
            const SizedBox(height: 30),
            const Row(
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