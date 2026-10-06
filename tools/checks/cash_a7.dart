import 'dart:convert';
import 'dart:io';

import '../../mobile/lib/logic/cash.dart';

Object? canonical(Object? x) {
  if (x is Map) {
    final keys = x.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: canonical(x[k])};
  }
  if (x is List) return x.map(canonical).toList();
  return x;
}

void equal(Object? a, Object? b, String name) {
  if (jsonEncode(canonical(a)) != jsonEncode(canonical(b))) {
    stderr.writeln('$name\nEXPECTED ${jsonEncode(b)}\nACTUAL ${jsonEncode(a)}');
    exit(1);
  }
}

void main() {
  final fixture = jsonDecode(
    File('mobile/test/fixtures/parity/cash_a7_corrected.json')
        .readAsStringSync(),
  );
  for (final raw in fixture['shots']) {
    final state = Map<String, dynamic>.from(raw);
    final before = jsonEncode(state);
    final sum = cashSummaryA7(state['kas']);
    equal(sum, state['expected'], '${state['name']} summary');
    equal(cashCloseModelA7(state), state['model'], '${state['name']} model');
    final entry = state['entry'];
    if (entry != null) {
      final after = jsonDecode(entry['after'][cashBusinessKey]);
      final at = DateTime.parse(
        after['kas'][entry['income'] ? 'ins' : 'outs'].last['at'],
      );
      final result = cashEntryA7(
        before: Map<String, dynamic>.from(entry['before']),
        income: entry['income'],
        method: entry['method'],
        amount: entry['amount'],
        note: entry['note'],
        at: at,
      );
      equal(
        jsonDecode(result[cashBusinessKey]),
        after,
        'full manual storage ${state['name']}',
      );
    }
    equal(cashDenTotalA7(state['kas']), state['denTotal'], 'denominations');
    equal(jsonEncode(state), before, 'no input mutation');
    print('PASS A7 ${state['name']}');
  }
  final steps =
      jsonDecode(
            File('mobile/test/fixtures/parity/flows_a4_a5_a7.json')
                .readAsStringSync(),
          )['steps']
          as List;
  final step = steps.firstWhere((s) => s['part'] == 'A7');
  final actual = closeCashA7(
    before: Map<String, dynamic>.from(step['before']),
    inputs: {
      'start': 100000,
      'phys': 160000,
      'setor': 50000,
      'qrisReal': '0',
      'tfReal': '0',
    },
    at: DateTime.parse(
      jsonDecode(step['after'][cashBusinessKey])['kas']['hist'][0]['d'],
    ),
    note: 'Uji tutup kas',
  );
  final got = jsonDecode(actual[cashBusinessKey]),
      expected = jsonDecode(step['after'][cashBusinessKey]);
  final originalKas = jsonDecode(step['before'][cashBusinessKey])['kas'];
  for (final key in ['sales', 'ins', 'outs']) {
    expected['kas']['hist'][0]['ledger${key[0].toUpperCase()}${key.substring(1)}'] =
        originalKas[key];
  }
  equal(got, expected, 'full original A7 close business');
  for (final key in actual.keys.where((key) => key != cashBusinessKey))
    equal(actual[key], step['after'][key], 'unchanged $key');
  print('PASS A7 full original close and unrelated keys');
}
