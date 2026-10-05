import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/payments.dart';
import 'package:goyana_flutter/logic/order_detail.dart';

void main() {
  final cases = <Map>[];
  for (final file in [
    'flows_a4_a5_a7.json',
    'payments_a5_extra.json',
    'payments_a5_corrected.json',
  ]) {
    final fixture = jsonDecode(
      File('test/fixtures/parity/$file').readAsStringSync(),
    ) as Map;
    cases.addAll(
      (fixture['steps'] as List).whereType<Map>().map(
        (c) => {...c, 'freshModel': file != 'flows_a4_a5_a7.json'},
      ),
    );
  }
  for (final c in cases.where((c) => c['part'] == 'A5')) {
    test('A5 snapshot HTML ${c['name']}', () {
      final before = Map<String, dynamic>.from(c['before'] as Map);
      final after = Map<String, dynamic>.from(c['after'] as Map);
      final original = jsonEncode(before);
      final action = inferPaymentA5Action(before: before, after: after);
      expect(action, isNotNull);
      expect(applyPaymentA5(before: before, action: action!), after);
      expect(jsonEncode(before), original);
    });
  }
  for (final c in cases.where(
    (c) =>
        c['part'] == 'A5' &&
        c['freshModel'] == true &&
        c['name'] != 'deposit_topup_transfer',
  )) {
    test('A5 detail native sama HTML ${c['name']}', () {
      final before = Map<String, dynamic>.from(c['before'] as Map);
      final action = inferPaymentA5Action(
        before: before,
        after: Map<String, dynamic>.from(c['after'] as Map),
      )!;
      final got = applyPaymentA5(before: before, action: action);
      expect(
        orderDetailA4Model(
          store: got,
          orderId: action.orderId,
          presentation: Map<String, dynamic>.from(c['detail'] as Map),
          preserveSavedBanner: true,
        ),
        c['detail'],
      );
    });
  }
  final base = cases.firstWhere((c) => c['name'] == 'dp50_tunai');
  final before = Map<String, dynamic>.from(base['before'] as Map);
  final action = inferPaymentA5Action(
    before: before,
    after: Map<String, dynamic>.from(base['after'] as Map),
  )!;
  for (final amount in [0, -1, 28001, 9007199254740992]) {
    test('A5 reject nominal $amount tanpa mutasi', () {
      final original = jsonEncode(before);
      expect(
        () => applyPaymentA5(
          before: before,
          action: PaymentA5Action.pay(
            orderId: action.orderId,
            amount: amount,
            method: 'Tunai',
            at: action.at,
          ),
        ),
        throwsArgumentError,
      );
      expect(jsonEncode(before), original);
    });
  }
  test('A5 saldo deposit kurang tidak mengubah storage', () {
    final original = jsonEncode(before);
    expect(
      () => applyPaymentA5(
        before: before,
        action: PaymentA5Action.pay(
          orderId: action.orderId,
          amount: 1,
          method: 'Deposit',
          at: action.at,
        ),
      ),
      throwsStateError,
    );
    expect(jsonEncode(before), original);
  });
  test('A5 normalisasi nomor deposit', () {
    expect(
      paymentCustomerKey('Citra', '0812-0000'),
      paymentCustomerKey('Citra', '628120000'),
    );
  });
  for (final c in cases.where((c) => c['part'] == 'A5-rejected')) {
    test('A5 tidak berubah saat ditolak ${c['name']}', () {
      expect(c['after'], c['before']);
      expect(
        inferPaymentA5Action(
          before: Map<String, dynamic>.from(c['before'] as Map),
          after: Map<String, dynamic>.from(c['after'] as Map),
        ),
        isNull,
      );
    });
  }
  test('A5 refund deposit Rp18000 kembali sekali dan bertahan', () {
    final c = cases.firstWhere(
      (c) => c['name'] == 'void_deposit' && c['part'] == 'A5',
    );
    final b =
        jsonDecode((c['after'] as Map)[paymentBusinessKey] as String) as Map;
    expect(
      ((b['deposits178'] as Map)['phone:6281200000006'] as Map)['balance'],
      40000,
    );
    final details = (b['details'] as Map).values.whereType<Map>();
    final order = details.firstWhere((o) => o['name'] == 'Fina Deposit');
    expect(order['paid'], 10000);
    final card = (b['orders'] as List).whereType<Map>().firstWhere(
      (o) => (o['fields'] as List)[1][0] == order['id'],
    );
    expect((card['dataset'] as Map)['paid177'], '10000');
    expect(
      (jsonDecode(
        (card['dataset'] as Map)['payments178'] as String,
      ) as List).length,
      1,
    );
  });
  for (final c in cases.where((c) => c['part'] == 'A5-audit')) {
    test('A5 ralat bermasalah tidak disalin ${c['name']}', () {
      expect(
        inferPaymentA5Action(
          before: Map<String, dynamic>.from(c['before'] as Map),
          after: Map<String, dynamic>.from(c['after'] as Map),
        ),
        isNull,
      );
    });
  }
}
