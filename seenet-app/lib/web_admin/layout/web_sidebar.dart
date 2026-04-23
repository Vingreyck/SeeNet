import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const _items = [
    {'icon': Icons.assignment_outlined, 'label': 'Ordens de Serviço'},
    {'icon': Icons.map_outlined,        'label': 'GPS / Rastreamento'},
    {'icon': Icons.security_outlined,   'label': 'EPIs'},
    {'icon': Icons.people_outline,      'label': 'Técnicos'},
    {'icon': Icons.bar_chart_outlined,  'label': 'Relatórios'},
    {'icon': Icons.warning_amber_outlined, 'label': 'APR'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF1A1A2E), // sua cor primária — ajuste
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / nome
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'SeeNet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12),
          const SizedBox(height: 8),

          // Itens de navegação
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final selected = selectedIndex == i;
                return _SidebarItem(
                  icon: _items[i]['icon'] as IconData,
                  label: _items[i]['label'] as String,
                  selected: selected,
                  onTap: () => onItemSelected(i),
                );
              },
            ),
          ),

          const Divider(color: Colors.white12),

          // Logout
          _SidebarItem(
            icon: Icons.logout,
            label: 'Sair',
            selected: false,
            onTap: () {
              // seu método de logout existente
              // AuthController.to.logout();
              Get.offAllNamed('/login');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.blueAccent : Colors.white60, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}