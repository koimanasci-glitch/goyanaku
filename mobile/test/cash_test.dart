import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/cash.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/parity/cash_a7_corrected.json').readAsStringSync(),
  );
  for (final raw in fixture['shots']) {
    final state = Map<String, dynamic>.from(raw);
    test('A7 corrected cash ${state['name']}', () {
      final original = jsonEncode(state);
      expect(cashSummaryA7(state['kas']), state['expected']);
      expect(cashDenTotalA7(state['kas']), state['denTotal']);
      expect(cashCloseModelA7(state), state['model']);
      expect(jsonEncode(state), original);
      // Calculations must not depend on the HTML displayed amounts.
      final poisoned = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
      poisoned['model']['total'] = 'wrong';
      for (final m in poisoned['model']['sections'][0]['methods']) {
        m['v'] = 'wrong';
        m['s'] = 'wrong';
      }
      for (final row in (poisoned['model']['sections'][1]['rows'] as List).skip(
        1,
      )) {
        row['v'] = 'wrong';
      }
      expect(cashCloseModelA7(poisoned), state['model']);
    });
  }
  for (final state in fixture['shots']) {
    final entry = state['entry'];
    if (entry == null) continue;
    test('A7 corrected manual storage ${state['name']}', () {
      final after = jsonDecode(entry['after'][cashBusinessKey]);
      final at = DateTime.parse(
        after['kas'][entry['income'] ? 'ins' : 'outs'].last['at'],
      );
      final got = cashEntryA7(
        before: Map<String, dynamic>.from(entry['before']),
        income: entry['income'],
        method: entry['method'],
        amount: entry['amount'],
        note: entry['note'],
        at: at,
      );
      expect(jsonDecode(got[cashBusinessKey]), after);
    });
  }
  final old =
      (jsonDecode(
                File('test/fixtures/parity/flows_a4_a5_a7.json')
                    .readAsStringSync(),
              )['steps']
              as List)
          .firstWhere((s) => s['part'] == 'A7');
  final before = Map<String, dynamic>.from(old['before']);
  Map<String, dynamic> close(
    Map<String, dynamic> inputs, {
    String note = 'Uji tutup kas',
  }) => closeCashA7(
    before: before,
    inputs: inputs,
    at: DateTime.parse(
      jsonDecode(old['after'][cashBusinessKey])['kas']['hist'][0]['d'],
    ),
    note: note,
  );
  test('A7 full storage close parity preserves orders and audit records', () {
    final original = jsonEncode(before);
    final result = close({
      'start': 100000,
      'phys': 160000,
      'setor': 50000,
      'qrisReal': '0',
      'tfReal': '0',
    });
    final expected = jsonDecode(old['after'][cashBusinessKey]);
    final originalKas = jsonDecode(before[cashBusinessKey])['kas'];
    for (final key in ['sales', 'ins', 'outs']) {
      expected['kas']['hist'][0]['ledger${key[0].toUpperCase()}${key.substring(1)}'] =
          originalKas[key];
    }
    expect(jsonDecode(result[cashBusinessKey]), expected);
    for (final key in before.keys.where((k) => k != cashBusinessKey)) {
      expect(result[key], old['after'][key]);
    }
    expect(jsonEncode(before), original);
  });
  test('A7 missing physical and unexplained difference rejected', () {
    expect(() => close({}), throwsStateError);
    expect(() => close({'phys': 40000}, note: ''), throwsStateError);
    expect(() => close({'phys': 49000}, note: ''), returnsNormally);
  });
  test('A7 invalid amounts and ledger replacement rejected', () {
    for (final inputs in <Map<String, dynamic>>[
      {'phys': -1},
      {'phys': 1.5},
      {'phys': 49000, 'setor': -1},
      {
        'phys': 49000,
        'den': {'5000': -1},
      },
      {'phys': 49000, 'sales': []},
    ]) {
      expect(() => close(inputs), throwsStateError);
    }
  });
  test(
    'A7 denomination priority, capped setor, default carry and signed refunds',
    () {
      final k = jsonDecode(
        close({
          'phys': 1,
          'den': {'100000': 1},
          'setor': 200000,
        })[cashBusinessKey],
      )['kas'];
      expect(k['start'], 0);
      expect(k['hist'][0]['setor'], 100000);
      final balanced = jsonDecode(
        close({'start': 100000, 'phys': 149000})[cashBusinessKey],
      )['kas'];
      expect(balanced['start'], 100000);
      expect(
        cashSummaryA7({
          'start': 100000,
          'sales': [
            {'m': 'Tunai', 'a': -10000},
          ],
          'ins': [],
          'outs': [],
        })['expect'],
        90000,
      );
    },
  );
  test('A7 manual entries preserve unrelated data', () {
    for (final args in [
      (true, 'Tunai'),
      (true, 'Non-Tunai'),
      (false, 'Tunai'),
    ]) {
      final result = cashEntryA7(
        before: before,
        at: DateTime.utc(2026, 10, 6),
        income: args.$1,
        method: args.$2,
        amount: 5000,
        note: 'Uji',
      );
      final b = jsonDecode(result[cashBusinessKey]),
          original = jsonDecode(before[cashBusinessKey]);
      for (final key in original.keys.where((k) => k != 'kas')) {
        expect(b[key], original[key]);
      }
      expect(
        b['kas'][args.$1 ? 'ins' : 'outs'].last,
        args.$1
            ? {
                'm': args.$2,
                'a': 5000,
                't': 'Uji',
                'at': '2026-10-06T00:00:00.000Z',
              }
            : {'t': 'Uji', 'a': 5000, 'at': '2026-10-06T00:00:00.000Z'},
      );
    }
    final noncash = jsonDecode(
      cashEntryA7(
        before: before,
        at: DateTime.utc(2026, 10, 6),
        income: false,
        method: 'Non-Tunai',
        amount: 5000,
        note: '',
      )[cashBusinessKey],
    );
    expect(noncash['kas']['outs'].last['m'], 'Non-Tunai');
    expect(
      cashSummaryA7(noncash['kas'])['expect'],
      cashSummaryA7(jsonDecode(before[cashBusinessKey])['kas'])['expect'],
    );
    expect(
      () => cashEntryA7(
        before: before,
        at: DateTime.utc(2026, 10, 6),
        income: true,
        method: 'Tunai',
        amount: 0,
        note: '',
      ),
      throwsStateError,
    );
  });
  test('A7 historical discrepancy retained for audit', () {
    final originalFixture = jsonDecode(
      File('test/fixtures/parity/cash_a7.json').readAsStringSync(),
    );
    final audit = originalFixture['shots'].firstWhere(
      (s) => s['name'] == 'deposit_audit',
    );
    expect(cashSummaryA7(audit['kas'])['omset'], 28000);
    expect(audit['expected']['omset'], 0);
    final noncash = originalFixture['shots'].firstWhere(
      (s) => s['name'] == 'noncash_out_audit',
    );
    expect(cashSummaryA7(noncash['kas'])['outs'], 0);
    expect(noncash['expected']['outs'], 5000);
  });
}
