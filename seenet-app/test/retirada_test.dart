import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:seenet/models/ordem_servico_model.dart';

OrdemServico os(String assunto) => OrdemServico.fromJson({
      'id': 1,
      'cliente_nome': 'X',
      'dados_ixc': jsonEncode({'id_assunto': assunto}),
    });

void main() {
  group('Aba Retirada — quais assuntos entram', () {
    test('os 6 assuntos de retirada do IXC', () {
      // Tem que bater com ASSUNTOS_RETIRADA do BriefingOSService.js.
      for (final a in ['34', '46', '50', '86', '90', '141']) {
        expect(os(a).isRetirada, isTrue, reason: 'assunto $a deveria ser retirada');
      }
    });

    test('86 (RETIRAR EQUIPAMENTO) entra — era o caso quebrado', () {
      // 6 OS abertas em producao caiam na aba errada por causa disto.
      expect(os('86').isRetirada, isTrue);
    });

    test('assuntos de defeito NAO entram', () {
      for (final a in ['9', '14', '5', '116', '163', '32', '44', '10']) {
        expect(os(a).isRetirada, isFalse, reason: 'assunto $a nao e retirada');
      }
    });

    test('assuntos de instalacao NAO entram', () {
      for (final a in ['4', '60', '31', '128', '105']) {
        expect(os(a).isRetirada, isFalse, reason: 'assunto $a e instalacao');
      }
    });

    test('sem assunto nao quebra e nao vira retirada', () {
      final semAssunto = OrdemServico.fromJson({'id': 1, 'cliente_nome': 'X'});
      expect(semAssunto.isRetirada, isFalse);
    });

    test('assunto desconhecido cai fora da aba (lado seguro)', () {
      expect(os('9999').isRetirada, isFalse);
    });
  });
}
