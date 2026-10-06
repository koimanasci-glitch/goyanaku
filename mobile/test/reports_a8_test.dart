import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/reports_a8.dart';
import 'package:goyana_flutter/pure/reports_dart.dart';

Object? _canon(Object? v) {
  if (v is Map) return {for (final k in (v.keys.toList()..sort())) '$k': _canon(v[k])};
  if (v is List) return [for (final x in v) _canon(x)];
  if (v is double && v == v.truncate() && v.abs() < 9e15) return v.toInt();
  return v;
}

void main() {
  for (final group in ['semua']) {
    final fx = jsonDecode(File('test/fixtures/parity/reports_a8.json').readAsStringSync()) as Map;
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
  _adapterTests();
  _hubTests();
  test('A8 pembulatan JavaScript: .5 naik, termasuk negatif', () {
    expect(jsRound(2.5), 3);
    expect(jsRound(-2.5), -2);
    expect(jsRound(-0.4), 0);
    expect(rpA8(-1500), '−Rp1.500');
    expect(rpA8(0), 'Rp0');
  });
}

void _adapterTests() {
  test('Adaptor database Dart menghasilkan pesanan laporan yang sama dengan HTML (data nyata)', () {
    final fx = jsonDecode(File('test/fixtures/parity/reports_a8.json').readAsStringSync()) as Map;
    final seed = (fx['scenarios'] as List).cast<Map>().firstWhere((s) => s['name'] == 'seed');
    final flows = jsonDecode(File('test/fixtures/parity/flows_a4_a5_a7.json').readAsStringSync()) as Map;
    final before = ((flows['steps'] as List).cast<Map>().firstWhere((s) => s['part'] == 'A7'))['before'] as Map;
    final business = Map<String, dynamic>.from(jsonDecode(before['goyana-business177'] as String) as Map);
    final now = DateTime.parse(seed['state']['now'] as String);
    final got = reportStateFromBusiness(business, now: now, tzMinutes: 420);
    int ms(Object? v) => v is num ? v.toInt() : DateTime.parse('$v').millisecondsSinceEpoch;
    final want = (seed['state']['ord'] as List).cast<Map>();
    final have = (got['ord'] as List).cast<Map>();
    expect(have.length, want.length);
    for (var i = 0; i < want.length; i++) {
      final w = want[i], h = have[i];
      for (final k in ['id', 'c', 'total', 'paid', 'm', 'st', 'dur', 'antar', 'pts', 'disc', 'ong', 'kg', 'sub', 'staff']) {
        expect(h[k], w[k], reason: 'pesanan ${w['id']} kolom $k');
      }
      for (final k in ['t', 'due', 'done']) {
        expect(h[k], ms(w[k]), reason: 'pesanan ${w['id']} kolom $k');
      }
      expect((h['items'] as List).length, (w['items'] as List).length);
      expect(jsonEncode(h['payments178']).replaceAll(RegExp(r'"at":"[^"]*",?'), ''), jsonEncode(w['payments178']).replaceAll(RegExp(r'"at":"[^"]*",?'), ''));
    }
    // Seluruh laporan dari adaptor = dari HTML pada data yang sama.
    final ctx = RepCtx.fromJson(got);
    for (final e in (seed['periods'] as Map).entries) {
      final r = ctx.range(e.key as String);
      for (final id in (fx['ids'] as List).cast<String>()) {
        if (const {'presensi', 'stok', 'pakai', 'nilai'}.contains(id)) continue;
        expect(jsonEncode(_canon(jsonDecode(jsonEncode(reportA8(id, ctx, r))))), jsonEncode(_canon((e.value as Map)['expected'][id])), reason: '$id ${e.key}');
      }
    }
  });
}

void _hubTests() {
  test('Beranda laporan Dart: hero, KPI, 41 butir daftar, saringan dan pencarian', () {
    final fx = jsonDecode(File('test/fixtures/parity/reports_a8.json').readAsStringSync()) as Map;
    final sc = (fx['scenarios'] as List).cast<Map>().firstWhere((s) => s['name'] == 'synthetic');
    final ctx = RepCtx.fromJson(sc['state'] as Map);
    final m = reportsHubA8(ctx, periodKey: '30');
    expect(m.heroBig, startsWith('Rp'));
    expect(m.heroLabel, 'Omzet · 30 hari');
    expect(m.kpis.map((k) => k.title), ['Pengeluaran', 'Laba bersih', 'Belum dibayar', 'Pelanggan baru']);
    expect(m.methods.map((x) => x.title), ['Tunai', 'QRIS', 'Transfer', 'Deposit']);
    expect(m.sections.fold<int>(0, (a, s) => a + s.items.length), 41);
    expect(m.periods.where((p) => p.on).single.t, '30 hari');
    final piutang = reportsHubA8(ctx, periodKey: '30', query: 'piutang');
    expect(piutang.sections.single.items.single.title, 'Piutang (Belum Bayar)');
    expect(reportVisibleIds(query: 'piutang'), ['piutang']);
    final keu = reportsHubA8(ctx, periodKey: 'last', cat: 'keu');
    expect(keu.sections.single.items.length, 10);
    expect(keu.sections.single.items.first.index, 0);
  });
  test('CSV dan teks WA laporan', () {
    final fx = jsonDecode(File('test/fixtures/parity/reports_a8.json').readAsStringSync()) as Map;
    final sc = (fx['scenarios'] as List).cast<Map>().firstWhere((s) => s['name'] == 'synthetic');
    final ctx = RepCtx.fromJson(sc['state'] as Map);
    final d = reportA8('ptrx', ctx, ctx.range('30'))!;
    final csv = reportCsvA8(d).split('\n');
    expect(csv.first, 'Order;Pelanggan;Nominal');
    expect(csv[1], matches(RegExp(r'^GY-\d+ · \d\d/\d\d/\d{4};.+;Rp[\d.]+$')));
    final wa = reportShareTextA8('Pendapatan Transaksi', '30 hari', d);
    expect(wa, startsWith('*LAPORAN PENDAPATAN TRANSAKSI*'));
    expect(wa, contains('• Pendapatan diterima: *Rp'));
  });
}
