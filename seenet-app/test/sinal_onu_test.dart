import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:seenet/models/ordem_servico_model.dart';

/// Monta uma OS mínima com o dados_ixc informado, exatamente como o backend
/// entrega (dados_ixc chega como STRING JSON vinda do Postgres).
OrdemServico osComFibra(Map<String, dynamic> fibra, {bool comoString = true}) {
  return OrdemServico.fromJson({
    'id': 1,
    'numero_os': 'OS-TESTE',
    'cliente_nome': 'Cliente Teste',
    'dados_ixc': comoString ? jsonEncode(fibra) : fibra,
  });
}

void main() {
  group('Classificação do sinal da ONU (regra fixa, sem IA)', () {
    test('sinal bom continua bom', () {
      // valor real puxado do IXC
      final os = osComFibra({'sn_sinal_rx': -17.85});
      expect(os.nivelSinal, NivelSinal.bom);
      expect(os.temSinal, isTrue);
    });

    test('sinal crítico real do IXC é classificado como crítico', () {
      // edenilsonfp: -27.96 dBm, caso que motivou a feature
      final os = osComFibra({'sn_sinal_rx': -27.96});
      expect(os.nivelSinal, NivelSinal.critico);
      expect(os.sinalExplicacao, contains('Fora da faixa'));
    });

    test('faixa de atenção entre -25 e -27', () {
      expect(osComFibra({'sn_sinal_rx': -25.5}).nivelSinal, NivelSinal.atencao);
      expect(osComFibra({'sn_sinal_rx': -26.9}).nivelSinal, NivelSinal.atencao);
    });

    test('limites exatos não oscilam', () {
      // -25 ainda é bom; abaixo disso vira atenção
      expect(osComFibra({'sn_sinal_rx': -25.0}).nivelSinal, NivelSinal.bom);
      expect(osComFibra({'sn_sinal_rx': -25.01}).nivelSinal, NivelSinal.atencao);
      // -27 ainda é atenção; abaixo disso vira crítico
      expect(osComFibra({'sn_sinal_rx': -27.0}).nivelSinal, NivelSinal.atencao);
      expect(osComFibra({'sn_sinal_rx': -27.01}).nivelSinal, NivelSinal.critico);
    });

    test('sinal FORTE demais também é defeito, não "ótimo"', () {
      final os = osComFibra({'sn_sinal_rx': -5.0});
      expect(os.nivelSinal, NivelSinal.critico);
      expect(os.sinalExplicacao, contains('Forte demais'));
    });

    test('sem medição = desconhecido, nunca "0 dBm"', () {
      // o IXC grava 0.00 quando nunca mediu — não pode virar leitura válida
      expect(osComFibra({'sn_sinal_rx': 0}).nivelSinal, NivelSinal.desconhecido);
      expect(osComFibra({'sn_sinal_rx': '0.00'}).nivelSinal, NivelSinal.desconhecido);
      expect(osComFibra({'sn_sinal_rx': null}).nivelSinal, NivelSinal.desconhecido);
      expect(osComFibra({}).nivelSinal, NivelSinal.desconhecido);
      expect(osComFibra({}).temSinal, isFalse);
    });

    test('aceita número em STRING (dados_ixc de versão antiga do sync)', () {
      final os = osComFibra({'sn_sinal_rx': '-27.96'});
      expect(os.sinalRx, -27.96);
      expect(os.nivelSinal, NivelSinal.critico);
    });

    test('valor inválido não quebra nem vira número errado', () {
      expect(osComFibra({'sn_sinal_rx': 'abc'}).sinalRx, isNull);
      expect(osComFibra({'sn_sinal_rx': ''}).sinalRx, isNull);
    });
  });

  group('Frescor da medição', () {
    test('medição de agora não está desatualizada', () {
      final agora = DateTime.now().subtract(const Duration(minutes: 10));
      final os = osComFibra({
        'sn_sinal_rx': -20.0,
        'sn_sinal_data': agora.toIso8601String().replaceFirst('T', ' '),
      });
      expect(os.sinalMedidoEm, isNotNull);
      expect(os.sinalDesatualizado, isFalse);
    });

    test('medição de 2 dias atrás está desatualizada', () {
      final antes = DateTime.now().subtract(const Duration(days: 2));
      final os = osComFibra({
        'sn_sinal_rx': -20.0,
        'sn_sinal_data': antes.toIso8601String().replaceFirst('T', ' '),
      });
      expect(os.sinalDesatualizado, isTrue);
      expect(os.sinalIdadeTexto, 'há 2 dias');
    });

    test('sem data conta como desatualizado (não finge que é de agora)', () {
      final os = osComFibra({'sn_sinal_rx': -20.0});
      expect(os.sinalDesatualizado, isTrue);
      expect(os.sinalIdadeTexto, 'sem data');
    });

    test('data zerada do IXC não vira DateTime', () {
      final os = osComFibra({
        'sn_sinal_rx': -20.0,
        'sn_sinal_data': '0000-00-00 00:00:00',
      });
      expect(os.sinalMedidoEm, isNull);
    });

    test('formato de data do IXC (espaço em vez de T) é entendido', () {
      final os = osComFibra({
        'sn_sinal_rx': -27.96,
        'sn_sinal_data': '2026-08-18 16:40:41',
      });
      expect(os.sinalMedidoEm, DateTime(2026, 8, 18, 16, 40, 41));
    });

    test('texto de idade em horas e minutos', () {
      DateTime atras(Duration d) => DateTime.now().subtract(d);
      String idade(Duration d) => osComFibra({
            'sn_sinal_rx': -20.0,
            'sn_sinal_data': atras(d).toIso8601String().replaceFirst('T', ' '),
          }).sinalIdadeTexto;

      expect(idade(const Duration(minutes: 1)), 'agora');
      expect(idade(const Duration(minutes: 30)), 'há 30 min');
      expect(idade(const Duration(hours: 3)), 'há 3 h');
      expect(idade(const Duration(days: 1, hours: 1)), 'há 1 dia');
    });
  });

  group('Apresentação', () {
    test('formata em dBm com vírgula', () {
      expect(osComFibra({'sn_sinal_rx': -27.96}).sinalFormatado, '-27,96 dBm');
      expect(osComFibra({'sn_sinal_rx': -20}).sinalFormatado, '-20,00 dBm');
      expect(osComFibra({}).sinalFormatado, '');
    });

    test('campos extras da ONU são lidos', () {
      final os = osComFibra({
        'sn_sinal_rx': -22.5,
        'sn_sinal_tx': -25.53,
        'sn_onu_temp': 39.0,
        'sn_onu_tipo': 'ZTEG-F670LV9',
      });
      expect(os.sinalTx, -25.53);
      expect(os.onuTemperatura, 39.0);
      expect(os.onuTipo, 'ZTEG-F670LV9');
    });

    test('dados_ixc como Map (não só String) também funciona', () {
      final os = osComFibra({'sn_sinal_rx': -27.96}, comoString: false);
      expect(os.nivelSinal, NivelSinal.critico);
    });
  });

  group('Nada quebra sem os campos novos', () {
    test('OS sem dados_ixc nenhum', () {
      final os = OrdemServico.fromJson({'id': 1, 'cliente_nome': 'X'});
      expect(os.temSinal, isFalse);
      expect(os.nivelSinal, NivelSinal.desconhecido);
      expect(os.sinalFormatado, '');
      expect(os.clienteNome, 'X');
    });

    test('dados_ixc antigo (só os campos que já existiam)', () {
      final os = osComFibra({
        'login': 'copadomundo2026',
        'caixa_ftth': '839',
        'porta_ftth': '4',
        'sn_online': true,
      });
      expect(os.clienteLogin, 'copadomundo2026');
      expect(os.caixaFtth, '839');
      expect(os.statusConexaoOnline, isTrue);
      expect(os.temSinal, isFalse); // sem sinal, e sem quebrar
    });
  });
}
