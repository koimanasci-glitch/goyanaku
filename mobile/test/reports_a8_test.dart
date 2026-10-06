import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/reports_a8.dart';

Object? _canon(Object? v) {
  if (v is Map) return {for (final k in (v.keys.toList()..sort())) '$k': _canon(v[k])};
  if (v is List) return [for (final x in v) _canon(x)];
  if (v is double && v == v.truncate() && v.abs() < 9e15) return v.toInt();
  return v;
}

void main() {
  for (final group in ['keu']) {
    final fx = jsonDecode(File('test/fixtures/parity/reports_a8_$group.json').readAsStringSync()) as Map;
    final ids = (fx['ids'] as List).cast<String>();
    for (final sc in (fx['scenarios'] as List).cast<Map>()) {
      final ctx = RepCtx.fromJson(sc['state'] as Map);
      for (final e in (sc['periods'] as Map).entries) {
        final p = e.value as Map;
        test('A8 $group ${sc['name']} periode ${e.key}: rentang sama dengan HTML', () {
          final r = ctx.range(e.key);
          final rg = p['range'] as Map;
          final tz = (sc['state']['tz'] as num).toInt() * 60000;
          expect(r.s.millisecondsSinceEpoch - tz, DateTime.parse(rg['s'] as String).millisecondsSinceEpoch);
          expect(r.e.millisecondsSinceEpoch - tz, DateTime.parse(rg['e'] as String).millisecondsSinceEpoch);
          expect(r.days, rg['days']);
        });
        for (final id in ids) {
          test('A8 $group ${sc['name']} periode ${e.key}: laporan $id sama dengan HTML', () {
            final r = ctx.range(e.key);
            final got = reportA8(id, ctx, r);
            expect(got, isNotNull, reason: 'laporan $id belum dipindah');
            final want = (p['expected'] as Map)[id];
            final a = jsonEncode(_canon(jsonDecode(jsonEncode(got))));
            final b = jsonEncode(_canon(want));
            expect(a, b);
          });
        }
      }
    }
  }
  test('A8 pembulatan JavaScript: .5 naik, termasuk negatif', () {
    expect(jsRound(2.5), 3);
    expect(jsRound(-2.5), -2);
    expect(jsRound(-0.4), 0);
    expect(rpA8(-1500), '−Rp1.500');
    expect(rpA8(0), 'Rp0');
  });
}
