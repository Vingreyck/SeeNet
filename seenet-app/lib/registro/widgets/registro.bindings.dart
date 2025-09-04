import 'package:get/get.dart';
import 'package:seenet/registro/registroview.controller.dart';

class RegistroBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => RegistroController());
  }
} //lazy put vai chamar apenas uma vez a tela de registro