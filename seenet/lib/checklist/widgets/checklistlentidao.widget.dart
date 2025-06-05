import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChecklistLentidaoWidget extends StatelessWidget {
  final VoidCallback? onTap;
  const ChecklistLentidaoWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone verde
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/snail.svg',
                      width: 32,
                      height: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Título e descrição
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lentidão',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Problema de velocidade, latência alta, conexão instável',
                        style: TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                // Seta
                const Align(
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.chevron_right,
                    color: Color(0xFF00FF88),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}