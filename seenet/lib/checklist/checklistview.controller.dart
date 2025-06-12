import 'package:get/get.dart';

class ChecklistCategory {
  final String title;
  final String description;
  final String assetIcon;
  final String route;

  ChecklistCategory({
    required this.title,
    required this.description,
    required this.assetIcon,
    required this.route,
  });
}

class ChecklistViewController extends GetxController {
  final categories = <ChecklistCategory>[
    ChecklistCategory(
      title: 'Manutenção e Reparo',
      description: 'Problemas de conexão, lentidão, quedas, e reparos',
      assetIcon: 'assets/images/repair.svg',
      route: '/checklist/manutencao',
    ),
    ChecklistCategory(
      title: 'IPTV',
      description: 'Travamento, buffering, canais fora do ar, qualidade baixa',
      assetIcon: 'assets/images/iptv.svg',
      route: '/checklist/iptv',
    ),
    ChecklistCategory(
      title: 'Instalação e Aplicativos',
      description: 'Configuração de roteadores, aplicativos, e configuração',
      assetIcon: 'assets/images/app.svg',
      route: '/checklist/conf',
    ),
  ].obs;
}