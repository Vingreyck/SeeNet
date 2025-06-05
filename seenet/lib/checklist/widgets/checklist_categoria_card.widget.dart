import 'package:flutter/material.dart';

class ChecklistCategoriaCardWidget extends StatelessWidget {
  final String title;
  final String assetIcon;
  final VoidCallback onTap;

  const ChecklistCategoriaCardWidget({
    super.key,
    required this.title,
    required this.assetIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Image.asset(assetIcon, width: 40, height: 40),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}