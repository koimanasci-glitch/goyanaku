import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/payments.dart';
import 'package:goyana_flutter/logic/order_detail.dart';

void main() {
  final cases = <Map>[];
  for (final file in ['flows_a4_a5_a7.json', 'payments_a5_extra.json']) {
    final fixture = jsonDecode(
      File('test/fixtures/parity/$file').readAsStringSync(),
    ) as Map;
    cases.addAll((fixture['steps'] as List).whereType<Map>());
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
    (c) => c['part'] == 'A5' && c['name'] != 'deposit_topup_transfer',
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
