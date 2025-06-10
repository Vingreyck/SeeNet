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
      title: 'Lentidão',
      description: 'Problema de velocidade, latência alta, conexão instável',
      assetIcon: 'assets/images/snail.svg',
      route: '/checklist/lentidao',
    ),
    ChecklistCategory(
      title: 'IPTV',
      description: 'Travamento, buffering, canais fora do ar, qualidade baixa',
      assetIcon: 'assets/images/iptv.svg',
      route: '/checklist/iptv',
    ),
    ChecklistCategory(
      title: 'Aplicativos',
      description: 'Apps não funcionam, erro de conexão, problemas de login',
      assetIcon: 'assets/images/app.svg',
      route: '/checklist/apps',
    ),
  ].obs;
}