import 'dart:convert';
import 'dart:io';

import '../../mobile/lib/logic/cash_day.dart';

void main() {
  final fixture = jsonDecode(
    File('mobile/test/fixtures/parity/cash_day.json').readAsStringSync(),
  );
  for (final s in fixture['shots']) {
    final got = cashDayRevenue(
      s['kas'],
      DateTime.parse(s['now']),
      business: s['business'] ?? {},
    );
    if (got != s['expected']) {
      throw StateError('${s['name']}: $got != ${s['expected']}');
    }
    print('PASS Dart daily revenue ${s['name']}');
  }
}
