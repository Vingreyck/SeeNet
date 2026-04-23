import 'package:flutter/material.dart';
import 'web_sidebar.dart';
import '../pages/os/web_os_page.dart';

class WebLayout extends StatefulWidget {
  const WebLayout({super.key});

  @override
  State<WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends State<WebLayout> {
  int _selectedIndex = 0;

  // Adicione as outras páginas aqui conforme criar
  final List<Widget> _pages = [
    const WebOsPage(),
    const Center(child: Text('GPS — em breve',    style: TextStyle(color: Colors.white))),
    const Center(child: Text('EPIs — em breve',   style: TextStyle(color: Colors.white))),
    const Center(child: Text('Técnicos — em breve', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Relatórios — em breve', style: TextStyle(color: Colors.white))),
    const Center(child: Text('APR — em breve',    style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Row(
        children: [
          WebSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => setState(() => _selectedIndex = i),
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}