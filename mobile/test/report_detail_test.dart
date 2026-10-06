import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/logic/reports_a8.dart';
import 'package:goyana_flutter/native/report_detail.dart';

class _Act implements ReportDetailActions {
  final log = <String>[];
  @override
  void rdBack() => log.add('back');
  @override
  void rdScan() => log.add('scan');
  @override
  void rdNav(String page) => log.add('nav:$page');
  @override
  void rdPeriod(String key) => log.add('per:$key');
  @override
  void rdCsv() => log.add('csv');
  @override
  void rdShare() => log.add('wa');
  @override
  void rdOpen(String page) => log.add('open:$page');
}

RepCtx _ctx() {
  final fx = jsonDecode(File('test/fixtures/parity/reports_a8.json').readAsStringSync()) as Map;
  final sc = (fx['scenarios'] as List).cast<Map>().firstWhere((s) => s['name'] == 'synthetic');
  return RepCtx.fromJson(sc['state'] as Map);
}

Future<_Act> _pump(WidgetTester tester, String id, {String key = '30'}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final ctx = _ctx();
  final r = ctx.range(key);
  final a = _Act();
  await tester.pumpWidget(MaterialApp(
    home: NativeReportDetail(
      topInset: 0,
      actions: a,
      model: ReportDetailModel(
        id: id, title: 'Uji $id', category: 'Keuangan', desc: 'Deskripsi uji', periodKey: key,
        periodLabel: periodLabelA8(key, r), data: reportA8(id, ctx, r)!, isExport: id.startsWith('x-'),
      ),
    ),
  ));
  await tester.pump();
  return a;
}

void main() {
  test('parseRepCell memisahkan teks utama, teks kecil, label dan tebal', () {
    final (main, small) = parseRepCell('GY-1<small>05/10/2026 · Reguler</small>');
    expect(main.single.text, 'GY-1');
    expect(small.single.text, '05/10/2026 · Reguler');
    final (m2, s2) = parseRepCell('Budi &amp; Ani<small><span class="tag g">Selesai</span> Tunai</small>');
    expect(m2.single.text, 'Budi & Ani');
    expect(s2.first.tag, 'g');
    expect(s2.first.text, 'Selesai');
    expect(s2.last.text, ' Tunai');
    final (m3, _) = parseRepCell('<b>Laba bersih</b>');
    expect(m3.single.bold, isTrue);
    final (m4, s4) = parseRepCell('<b>x</b> & y', raw: false);
    expect(m4.single.text, '<b>x</b> & y');
    expect(s4, isEmpty);
  });

  test('shA8 meniru sh() HTML', () {
    expect(shA8(0), 'Rp0');
    expect(shA8(950), 'Rp950');
    expect(shA8(250000), 'Rp250rb');
    expect(shA8(1500000), 'Rp1,5jt');
    expect(shA8(12000000), 'Rp12jt');
    expect(shA8(2100000000), 'Rp2,1M');
    expect(shA8(-1500000), '−Rp1,5jt');
  });

  testWidgets('Omzet 30 hari: KPI, grafik, rincian dan periode tampil dari data Dart', (tester) async {
    final a = await _pump(tester, 'omzet');
    expect(find.text('UJI OMZET'), findsOneWidget);
    expect(find.text('Keuangan · 30 hari'), findsOneWidget);
    expect(find.text('Omzet per hari'), findsOneWidget);
    expect(find.text('Rincian'), findsOneWidget);
    expect(find.text('30 baris'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rd-per-7')));
    await tester.tap(find.byKey(const ValueKey('rd-csv')));
    await tester.tap(find.byKey(const ValueKey('rd-wa')));
    await tester.tap(find.byKey(const ValueKey('rd-back')));
    expect(a.log, ['per:7', 'csv', 'wa', 'back']);
    // 30 baris = batas awal, tombol "lebih banyak" tidak ada.
    expect(find.byKey(const ValueKey('rd-more')), findsNothing);
  });

  testWidgets('Rincian panjang: tombol tampilkan lebih banyak membuka sisanya', (tester) async {
    await _pump(tester, 'arus', key: 'last');
    expect(find.byKey(const ValueKey('rd-more')), findsNothing);
    final ctx = _ctx();
    final rows = (reportA8('semua', ctx, ctx.range('last')) as Map)['rows'] as List;
    expect(rows.length, greaterThan(0));
  });

  testWidgets('Laporan kosong menampilkan pesan kosong; export menampilkan pratinjau', (tester) async {
    await _pump(tester, 'batal', key: 'today');
    expect(find.text('Tidak ada pesanan batal 👍'), findsOneWidget);
    await _pump(tester, 'x-trx');
    expect(find.text('Pratinjau'), findsOneWidget);
    expect(find.text('Siap diexport'), findsOneWidget);
  });
}
