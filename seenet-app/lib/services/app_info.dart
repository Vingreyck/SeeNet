// lib/services/app_info.dart
//
// Versão do app, lida do próprio pacote instalado (Android/iOS/web) — NÃO é
// constante escrita à mão, então não tem como ficar desatualizada.
//
// Por que isso existe: até 30/jul/2026 o app nunca informava a versão ao
// backend. Quando um técnico dizia que tinha atualizado e o comportamento era
// de versão antiga, a única forma de descobrir era comparar horários de
// arquivos no IXC — investigação de horas. Agora vai um header em toda
// requisição e o backend registra no login.
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  /// Ex.: "1.5.9+71". Vazio até o [carregar] rodar (ou se ele falhar) —
  /// nesse caso o header simplesmente não é enviado, nada quebra.
  static String versao = '';

  static Future<void> carregar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.trim();
      versao = build.isEmpty ? info.version : '${info.version}+$build';
      print('📱 Versão do app: $versao');
    } catch (e) {
      // Nunca deixa o arranque cair por causa disso.
      print('⚠️ Não consegui ler a versão do app: $e');
      versao = '';
    }
  }

  /// Header padrão pra juntar aos headers de qualquer service.
  /// Vazio quando a versão não foi lida → não polui a requisição.
  static Map<String, String> get header =>
      versao.isEmpty ? const {} : {'X-App-Version': versao};
}
