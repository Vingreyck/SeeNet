import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seenet/checklist/widgets/checklistlentidao.widget.dart';
import 'package:seenet/checklist/widgets/checklistiptv.widget.dart';
import 'package:seenet/checklist/widgets/checklistapps.widget.dart';

class Checklistview extends StatelessWidget {
  const Checklistview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.32, 1.0],
                  colors: [
                    Color.fromARGB(255, 0, 232, 124),
                    Color.fromARGB(255, 0, 176, 91),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/images/logo.svg',
                          width: 48,
                          height: 48,
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'SeeNet',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: IconButton(
                        icon: const Icon(Icons.person_outline, color: Colors.white, size: 28),
                        onPressed: () {
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 180, 
            left: 24,
            right: 24,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFF00FF88),
                    Color(0xFFFFFFFF),
                  ],
                ).createShader(Rect.fromLTWH(0.0, 0.0, bounds.width, bounds.height));
              },
              child: const Text(
                'Checklist Técnico',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
          const Positioned(
            top: 220, 
            left: 24,
            right: 24,
            child: Text(
              'Selecione a categoria para diagnóstico',
              style: TextStyle(
                color: Color(0XFF888888),
                fontSize: 16,
              ),
            ),
          ),
          //Container
          Positioned(
            top: 270, 
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Card 1 - Lentidão
                ChecklistLentidaoWidget(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChecklistLentidaoWidget(),
                      ),
                    );
                  },
                ),
                // Card 2 - IPTV
                ChecklistiptvWidget(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChecklistiptvWidget(), 
                      ),
                    );
                  },
                ),
                // Card 3 - Aplicativos
                ChecklistAppsWidget(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChecklistAppsWidget(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
