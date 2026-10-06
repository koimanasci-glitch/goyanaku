import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/cash_day.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/parity/cash_day.json').readAsStringSync(),
  );
  for (final s in fixture['shots']) {
    test('Daily revenue ${s['name']}', () {
      final original = jsonEncode(s);
      expect(
        cashDayRevenue(
          s['kas'],
          DateTime.parse(s['now']),
          business: s['business'] ?? {},
        ),
        s['expected'],
      );
      expect(jsonEncode(s), original);
    });
  }
}
