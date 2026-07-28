// lib/login/loginview.controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/usuario_controller.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class LoginController extends GetxController {
  late TextEditingController loginInput; // agora recebe nome
  late TextEditingController senhaInput;
  late TextEditingController codigoEmpresaController;
  late FocusNode codigoEmpresaFocusNode;

  RxBool isLoading = false.obs;
  RxString email = ''.obs;   // ← mantido como variável interna (nome do campo no controller)
  RxString senha = ''.obs;
  RxString codigoEmpresa = ''.obs;
  RxBool empresaValida = false.obs;
  RxBool verificandoEmpresa = false.obs;
  Rx<Map<String, dynamic>?> empresaInfo = Rx<Map<String, dynamic>?>(null);

  /// Estado detalhado da checagem da empresa. `empresaValida` continua existindo
  /// (widgets usam) e vira true só no caso `valida`; este aqui permite mostrar
  /// "não deu pra checar" (rede) diferente de "código errado".
  final Rx<ResultadoEmpresa?> statusEmpresa = Rx<ResultadoEmpresa?>(null);

  static const _keyUltimoCodigo = 'ultimo_codigo_empresa';

  // 🐛 FIX (bug do botão nunca ficar verde no iPhone/rede ruim): cada tecla
  // digitada disparava uma verificação nova SEM cancelar a anterior — em rede
  // lenta/instável, uma resposta atrasada (de um código ainda incompleto)
  // podia chegar DEPOIS da resposta certa e travar `empresaValida` em false
  // pra sempre. `_empresaCheckId` marca qual é a verificação mais recente:
  // qualquer resposta de uma verificação "velha" é descartada. O debounce
  // reduz a quantidade de chamadas (não dispara a cada tecla, só quando o
  // usuário para de digitar).
  Timer? _debounceEmpresa;
  int _empresaCheckId = 0;

  // Variáveis de erro
  RxString emailError = ''.obs;  // ← mantido o nome para não quebrar os widgets
  RxString senhaError = ''.obs;
  RxString empresaError = ''.obs;

  final UsuarioController usuarioController = Get.find<UsuarioController>();
  final AuthService authService = Get.find<AuthService>();
  final ApiService apiService = Get.find<ApiService>();

  @override
  void onInit() {
    super.onInit();

    loginInput = TextEditingController();
    senhaInput = TextEditingController();
    codigoEmpresaController = TextEditingController();
    codigoEmpresaFocusNode = FocusNode();

    loginInput.addListener(() => email.value = loginInput.text);
    senhaInput.addListener(() => senha.value = senhaInput.text);

    codigoEmpresaController.addListener(() {
      String codigo = codigoEmpresaController.text.toUpperCase();
      if (codigo != codigoEmpresa.value) {
        codigoEmpresa.value = codigo;
        _debounceEmpresa?.cancel();
        if (codigo.length >= 4) {
          // Feedback imediato (spinner) sem esperar o debounce, mas a
          // requisição em si só sai depois que o usuário parar de digitar.
          verificandoEmpresa.value = true;
          _debounceEmpresa = Timer(
            const Duration(milliseconds: 400),
            () => verificarEmpresa(codigo),
          );
        } else {
          _empresaCheckId++; // invalida qualquer verificação pendente
          empresaInfo.value = null;
          empresaValida.value = false;
          statusEmpresa.value = null;
          verificandoEmpresa.value = false;
        }
      }
    });

    // Técnico usa sempre a MESMA empresa: já deixa o código preenchido (e
    // verificado) na próxima vez. Menos digitação e menos chance de erro.
    final ultimo = GetStorage().read<String>(_keyUltimoCodigo);
    if (ultimo != null && ultimo.isNotEmpty) {
      codigoEmpresaController.text = ultimo;
    }
  }

  Future<void> verificarEmpresa(String codigo) async {
    if (codigo.length < 4) {
      empresaInfo.value = null;
      empresaValida.value = false;
      return;
    }

    // Marca esta chamada como a mais recente — qualquer resposta de uma
    // chamada anterior que chegue depois desta será ignorada.
    final meuId = ++_empresaCheckId;

    try {
      verificandoEmpresa.value = true;
      final r = await authService.verificarCodigoEmpresa(codigo);

      if (meuId != _empresaCheckId) return; // resposta atrasada — descarta

      statusEmpresa.value = r.resultado;
      empresaInfo.value = r.ok ? r.empresa : null;
      empresaValida.value = r.ok;
    } catch (e) {
      if (meuId != _empresaCheckId) return;
      // Exceção inesperada = não conseguimos checar (NÃO é "código errado").
      statusEmpresa.value = ResultadoEmpresa.erroRede;
      empresaInfo.value = null;
      empresaValida.value = false;
    } finally {
      if (meuId == _empresaCheckId) {
        verificandoEmpresa.value = false;
      }
    }
  }

  Future<void> tryToLogin() async {
    // Limpar erros anteriores
    emailError.value = '';
    senhaError.value = '';
    empresaError.value = '';

    bool hasError = false;

    // Validar identificador (CPF)
    if (loginInput.text.trim().isEmpty) {
      emailError.value = 'CPF é obrigatório';
      hasError = true;
    } else if (loginInput.text.trim().length < 2) {
      emailError.value = 'CPF muito curto';
      hasError = true;
    }

    if (codigoEmpresaController.text.trim().isEmpty) {
      empresaError.value = 'Código é obrigatório';
      hasError = true;
    } else if (statusEmpresa.value == ResultadoEmpresa.naoEncontrada) {
      // Só bloqueia quando o servidor RESPONDEU que não existe. Se a checagem
      // não rolou (rede), deixa tentar: quem valida de verdade é o /auth/login.
      empresaError.value = 'Código inválido';
      hasError = true;
    }

    if (hasError) return;

    try {
      isLoading.value = true;

      bool loginSucesso = await usuarioController.login(
        loginInput.text.trim(),  // ← agora é nome
        senhaInput.text,
        codigoEmpresaController.text.trim().toUpperCase(),
      );

      if (loginSucesso) {
        // Guarda pra pré-preencher no próximo login (o técnico usa sempre a
        // mesma empresa). Só salva depois de dar certo, pra não gravar lixo.
        GetStorage().write(
          _keyUltimoCodigo,
          codigoEmpresaController.text.trim().toUpperCase(),
        );
        Get.offAllNamed('/ordens-servico');
      }
    } catch (e) {
      emailError.value = 'Erro de conexão';
      print('❌ Erro no login: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void limparCampos() {
    _debounceEmpresa?.cancel();
    _empresaCheckId++; // invalida qualquer verificação em andamento

    loginInput.clear();
    senhaInput.clear();
    codigoEmpresaController.clear();

    email.value = '';
    senha.value = '';
    codigoEmpresa.value = '';
    empresaInfo.value = null;
    empresaValida.value = false;
    statusEmpresa.value = null;

    emailError.value = '';
    senhaError.value = '';
    empresaError.value = '';
  }

  void registrar() => Get.toNamed('/registro');

  /// ⚠️ NÃO exige que a checagem da empresa tenha dado certo.
  ///
  /// A checagem (`/tenant/verify`) é só CONVENIÊNCIA — quem valida a empresa de
  /// verdade é o `/auth/login`, que já recusa código errado. Exigir o check aqui
  /// fazia uma chamada não-essencial BLOQUEAR o login inteiro: se ela falhasse
  /// (rede instável, servidor lento), o técnico ficava com o botão travado sem
  /// conseguir entrar, mesmo com CPF e código corretos. Agora só bloqueia
  /// quando o servidor respondeu explicitamente que a empresa não existe.
  bool get podeLogar {
    return email.value.trim().isNotEmpty &&
        codigoEmpresa.value.trim().length >= 3 &&
        statusEmpresa.value != ResultadoEmpresa.naoEncontrada &&
        !isLoading.value;
  }

  @override
  void onClose() {
    _debounceEmpresa?.cancel();
    loginInput.dispose();
    senhaInput.dispose();
    codigoEmpresaController.dispose();
    codigoEmpresaFocusNode.dispose();
    super.onClose();
  }
}