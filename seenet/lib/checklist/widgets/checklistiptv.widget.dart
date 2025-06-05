import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChecklistiptvWidget extends StatelessWidget {
  final String title;
  final bool isChecked;
  final ValueChanged<bool?>? onChanged;

  const ChecklistiptvWidget({
    super.key,
    required this.title,
    required this.isChecked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/iptv.svg', // ajuste o ícone conforme seu projeto
                width: 32,
                height: 32,
              ),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          trailing: Checkbox(
            value: isChecked,
            onChanged: onChanged,
            activeColor: const Color(0xFF00FF88),
            checkColor: Colors.black,
          ),
        ),
      ),
    );
  }
}