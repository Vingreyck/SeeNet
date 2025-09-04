import 'package:get/get.dart';
import 'package:seenet/login/loginview.controller.dart';

class LoginBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginController());
  }
}//lazy put vai chamar apenas uma vez a tela de logar