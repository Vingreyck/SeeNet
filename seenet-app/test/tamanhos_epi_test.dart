// Testa o parser de tamanhos do EPI.
//
// Vale um teste de verdade porque a coluna `tamanhos` foi criada direto no
// banco (não há migration), então o valor pode chegar como LISTA (coluna
// json/jsonb) ou como STRING JSON (coluna text) — e um erro aqui faz os
// tamanhos sumirem em silêncio pro técnico, sem nenhum erro na tela.
import 'package:flutter_test/flutter_test.dart';
import 'package:seenet/seguranca/services/seguranca_service.dart';

void main() {
  group('SegurancaService.parseTamanhos', () {
    test('lista já decodificada (coluna json/jsonb)', () {
      expect(SegurancaService.parseTamanhos(['P', 'M', 'G']), ['P', 'M', 'G']);
    });

    test('string JSON (coluna text)', () {
      expect(SegurancaService.parseTamanhos('["39","40","41"]'), ['39', '40', '41']);
    });

    test('números dentro do JSON viram texto', () {
      expect(SegurancaService.parseTamanhos('[39,40]'), ['39', '40']);
      expect(SegurancaService.parseTamanhos([39, 40]), ['39', '40']);
    });

    test('texto separado por vírgula (não é JSON)', () {
      expect(SegurancaService.parseTamanhos('P, M, G, GG'), ['P', 'M', 'G', 'GG']);
    });

    test('null e vazios devolvem lista vazia', () {
      expect(SegurancaService.parseTamanhos(null), isEmpty);
      expect(SegurancaService.parseTamanhos(''), isEmpty);
      expect(SegurancaService.parseTamanhos('   '), isEmpty);
      expect(SegurancaService.parseTamanhos([]), isEmpty);
      expect(SegurancaService.parseTamanhos('[]'), isEmpty);
    });

    test('espaços em volta são removidos', () {
      expect(SegurancaService.parseTamanhos('[" P ","M "]'), ['P', 'M']);
    });

    test('itens vazios são descartados', () {
      expect(SegurancaService.parseTamanhos('["P","","G"]'), ['P', 'G']);
      expect(SegurancaService.parseTamanhos('P,,G'), ['P', 'G']);
    });

    test('tipo inesperado não quebra', () {
      expect(SegurancaService.parseTamanhos(42), isEmpty);
      expect(SegurancaService.parseTamanhos({'a': 1}), isEmpty);
      expect(SegurancaService.parseTamanhos(true), isEmpty);
    });

    test('JSON que não é lista devolve vazio', () {
      expect(SegurancaService.parseTamanhos('{"P":1}'), isEmpty);
      expect(SegurancaService.parseTamanhos('"P"'), isEmpty);
    });
  });
}
