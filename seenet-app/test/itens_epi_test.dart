import 'package:flutter_test/flutter_test.dart';
import 'package:seenet/seguranca/services/seguranca_service.dart';

/// O gestor passou a poder EDITAR o pedido de EPI em vez de recusar.
///
/// Pra isso, o texto guardado em `epis_solicitados` ("Bota de Segurança
/// (Tam. 45) x2") é desmontado, editado e montado de volta. Se o
/// round-trip não for exato, o PDF da ficha e o histórico saem errados —
/// e ninguém percebe na hora.
void main() {
  // Monta a partir das partes (atalho pra deixar os testes legíveis)
  String montar(String nome, {String? tam, int qtd = 1}) =>
      SegurancaService.montarItemEpi(
          ItemEpi(nome: nome, tamanho: tam, quantidade: qtd));

  group('parseItemEpi — desmontar', () {
    test('nome puro', () {
      final i = SegurancaService.parseItemEpi('Capacete');
      expect(i.nome, 'Capacete');
      expect(i.tamanho, isNull);
      expect(i.quantidade, 1);
    });

    test('com tamanho', () {
      final i = SegurancaService.parseItemEpi('Bota de Segurança (Tam. 45)');
      expect(i.nome, 'Bota de Segurança');
      expect(i.tamanho, '45');
      expect(i.quantidade, 1);
    });

    test('com quantidade', () {
      final i = SegurancaService.parseItemEpi('Luva Latex x3');
      expect(i.nome, 'Luva Latex');
      expect(i.tamanho, isNull);
      expect(i.quantidade, 3);
    });

    test('com tamanho E quantidade', () {
      final i = SegurancaService.parseItemEpi('Bota de Segurança (Tam. 45) x2');
      expect(i.nome, 'Bota de Segurança');
      expect(i.tamanho, '45');
      expect(i.quantidade, 2);
    });

    test('tamanho por LETRA (roupa)', () {
      final i = SegurancaService.parseItemEpi('Calça Operacional (Tam. GG)');
      expect(i.nome, 'Calça Operacional');
      expect(i.tamanho, 'GG');
    });

    test('⚠️ EPI REAL com parênteses no nome não vira tamanho', () {
      // "Camisa Manga Longa (Jaleco)" existe no cadastro. Se o parser
      // aceitasse qualquer "(...)" no fim, o nome viraria "Camisa Manga
      // Longa" e o tamanho viraria "Jaleco".
      final i = SegurancaService.parseItemEpi('Camisa Manga Longa (Jaleco)');
      expect(i.nome, 'Camisa Manga Longa (Jaleco)');
      expect(i.tamanho, isNull);
    });

    test('...e o mesmo EPI COM tamanho de verdade', () {
      final i = SegurancaService.parseItemEpi('Camisa Manga Longa (Jaleco) (Tam. G)');
      expect(i.nome, 'Camisa Manga Longa (Jaleco)');
      expect(i.tamanho, 'G');
    });

    test('outro nome com parênteses do cadastro real', () {
      final i = SegurancaService.parseItemEpi('Luva de Segurança (Isolante) x2');
      expect(i.nome, 'Luva de Segurança (Isolante)');
      expect(i.quantidade, 2);
    });

    test('"x" no MEIO do nome não é quantidade', () {
      final i = SegurancaService.parseItemEpi('Capacete x2 Camadas');
      expect(i.nome, 'Capacete x2 Camadas');
      expect(i.quantidade, 1);
    });

    test('quantidade 0 ou negativa cai pra 1', () {
      expect(SegurancaService.parseItemEpi('Bota x0').quantidade, 1);
    });

    test('texto com espaços sobrando', () {
      final i = SegurancaService.parseItemEpi('  Capacete (Tam. M) x2  ');
      expect(i.nome, 'Capacete');
      expect(i.tamanho, 'M');
      expect(i.quantidade, 2);
    });
  });

  group('montarItemEpi — remontar', () {
    test('nome puro não ganha sufixo', () {
      expect(montar('Capacete'), 'Capacete');
    });

    test('quantidade 1 NÃO aparece (igual ao app do técnico)', () {
      expect(montar('Capacete', qtd: 1), 'Capacete');
    });

    test('quantidade > 1 aparece', () {
      expect(montar('Luva Latex', qtd: 3), 'Luva Latex x3');
    });

    test('tamanho vazio é ignorado', () {
      expect(montar('Capacete', tam: ''), 'Capacete');
      expect(montar('Capacete', tam: '   '), 'Capacete');
    });

    test('tamanho + quantidade na ordem certa', () {
      expect(montar('Bota de Segurança', tam: '45', qtd: 2),
          'Bota de Segurança (Tam. 45) x2');
    });
  });

  group('ROUND-TRIP: desmontar e montar devolve o texto IDÊNTICO', () {
    // Se algum destes falhar, o gestor editar um item corromperia os OUTROS
    // itens do mesmo pedido (que só passam pelo parser de ida e volta).
    const casos = [
      'Capacete',
      'Bota de Segurança (Tam. 45)',
      'Luva Latex x3',
      'Bota de Segurança (Tam. 45) x2',
      'Calça Operacional (Tam. GG) x2',
      'Camisa Manga Longa (Jaleco)',
      'Camisa Manga Longa (Jaleco) (Tam. G)',
      'Luva de Segurança (Isolante) x2',
      'Capacete de Segurança (Classe B)',
      'Óculos de Segurança',
      'Fita de Sinalização Zebrada x10',
      'Capacete x2 Camadas',
    ];

    for (final original in casos) {
      test('"$original"', () {
        final volta = SegurancaService.montarItemEpi(
            SegurancaService.parseItemEpi(original));
        expect(volta, original);
      });
    }
  });

  group('edição do gestor', () {
    test('tirar o tamanho que faltou e trocar por outro', () {
      final item = SegurancaService.parseItemEpi('Bota de Segurança (Tam. 45) x2');
      final novo = item.copyWith(tamanho: '44');
      expect(SegurancaService.montarItemEpi(novo),
          'Bota de Segurança (Tam. 44) x2');
    });

    test('reduzir a quantidade (estoque parcial)', () {
      final item = SegurancaService.parseItemEpi('Luva Latex x5');
      expect(SegurancaService.montarItemEpi(item.copyWith(quantidade: 2)),
          'Luva Latex x2');
    });

    test('reduzir pra 1 faz o "x" sumir', () {
      final item = SegurancaService.parseItemEpi('Luva Latex x5');
      expect(SegurancaService.montarItemEpi(item.copyWith(quantidade: 1)),
          'Luva Latex');
    });

    test('limpar o tamanho', () {
      final item = SegurancaService.parseItemEpi('Bota de Segurança (Tam. 45)');
      expect(
          SegurancaService.montarItemEpi(item.copyWith(limparTamanho: true)),
          'Bota de Segurança');
    });

    test('o nome NUNCA muda na edição', () {
      const nome = 'Camisa Manga Longa (Jaleco)';
      final item = SegurancaService.parseItemEpi('$nome (Tam. G) x2');
      final editado = item.copyWith(tamanho: 'GG', quantidade: 1);
      expect(editado.nome, nome);
      expect(SegurancaService.montarItemEpi(editado), '$nome (Tam. GG)');
    });
  });
}
