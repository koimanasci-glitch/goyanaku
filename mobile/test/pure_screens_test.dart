// Gambar layar mode murni (CI: --tags screens → branch ci-screens, berkas pure_*.png).
@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/access.dart';
import 'package:goyana_flutter/pure/import_csv.dart';
import 'package:goyana_flutter/pure/pages.dart' show DataCenterPage;
import 'package:goyana_flutter/pure/pure_shell.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

MemoryKvStore _store() {
  final s = jsonDecode(File('test/fixtures/core/snapshot.json').readAsStringSync()) as Map<String, dynamic>;
  return MemoryKvStore({
    for (final k in [Keys.business, Keys.services, Keys.outlets, Keys.activeOutlet, Keys.perfumes])
      if (s[k] is String) k: s[k] as String,
  });
}

void main() {
  setUp(() => planAccess.testPlan = 'PLATINUM');
  tearDown(() => planAccess.testPlan = null);
  setUpAll(_loadFonts);

  testWidgets('mode murni: layar utama', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: const Key('screen'), child: PureShell(store: _store(), clock: () => DateTime(2026, 10, 3, 10))),
    ));
    Future<void> shot(String name) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull, reason: name);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/pure_$name.png'));
    }

    final s = tester.state<PureShellState>(find.byType(PureShell));
    await shot('home');
    s.nav('orders');
    await shot('orders');
    s.openCard(0);
    await shot('detail');
    s.fmScoped('detail', 'close', 0);
    s.tile(0);
    await shot('addorder_customer');
    s.aoPickCustomer(0);
    await shot('addorder_duration');
    s.fmScoped('dur', 'button', 0);
    s.aoService(0);
    s.fmScoped('qty', 'input', 0, '3');
    s.fmScoped('qty', 'button', 1);
    await shot('addorder_services');
    s.aoNext();
    s.aoSheetMain();
    await shot('addorder_payment');
    s.aoPay(0);
    s.fmScoped('cash', 'input', 0, '50000');
    await shot('addorder_cash');
    s.nav('customers');
    await shot('customers');
    s.nav('reports');
    await shot('reports');
    s.nav('settings');
    await shot('settings');
    s.stGroup(4, true);
    await shot('settings_pelanggan');
    s.stGroup(4, true);
    s.stGroup(5, true);
    await shot('settings_whatsapp');
    s.nav('upgrade');
    await shot('upgrade');
    await tester.drag(find.text('Pilih Paket'), const Offset(0, -520));
    await shot('upgrade_bawah');
    await tester.tap(find.text('GOLD'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot('upgrade_rincian');
    await tester.tap(find.text('Tutup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    s.nav('customers');
    s.cuAdd();
    await shot('customeradd_gender');
    s.fmScoped('gp128', 'button', 0);
    await shot('customeradd');
  });

  testWidgets('mode murni: revisi uji HP (jarak aman bawah, stok, peta, nota, hutang, tambahan paket)', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    // HP dengan bilah gestur: 24 px logis di bawah harus dikosongkan.
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    final kv = _store();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: const Key('screen'), child: PureShell(store: kv, clock: () => DateTime(2026, 10, 3, 10))),
    ));
    Future<void> shot(String name) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull, reason: name);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/pure_rev_$name.png'));
    }

    final s = tester.state<PureShellState>(find.byType(PureShell));
    await shot('home_inset');
    s.tile(0);
    s.aoPickCustomer(0);
    s.fmScoped('dur', 'button', 0);
    await shot('addorder_inset');
    s.nav('customers');
    s.cuAdd();
    await shot('gender');
    s.fmScoped('gp128', 'button', 0);
    await shot('customeradd');
    s.fmButton(5);
    await shot('map');
    s.closePageSheet('map203');
    s.nav('services');
    s.svAdd();
    await shot('ikon');
    s.fmScoped('cat99', 'close', 0);
    s.nav('orders');
    s.openCard(0);
    s.odButton(8);
    await shot('wakind');
    s.fmScoped('wakind', 'button', 9);
    for (var k = 0; k < 8 && !s.debugHanding; k++) {
      s.fmScoped('detail', 'button', 1);
      await tester.pump();
    }
    await shot('hutang');
    s.aoSheetClose();
    s.nav('jemputnew202');
    await shot('jemput_baru');
    s.fmButton(10);
    await shot('jemput_pilih');
    s.fmScoped('pickcust', 'button', 0);
    s.fmButton(21);
    await shot('jemput_terisi');
    s.nav('stock');
    await shot('stok_kosong');
    s.fmButton(0);
    await shot('stok_tambah');
    for (final (k, v) in ['Deterjen', '2', 'liter', '3', '15000'].indexed) {
      s.fmScoped('g181-modal', 'input', k, v);
    }
    s.fmScoped('g181-modal', 'button', 0);
    s.fmButton(0);
    for (final (k, v) in ['Parfum Laundry', '12', 'liter', '2', '40000'].indexed) {
      s.fmScoped('g181-modal', 'input', k, v);
    }
    s.fmScoped('g181-modal', 'button', 0);
    await shot('stok');
    s.fmButton(3000);
    await shot('stok_bahan');
    s.fmScoped('stockitem', 'button', 9);
    s.nav('finance');
    await shot('kategori_pengeluaran');
    s.nav('cashout');
    await shot('pengeluaran');
    s.nav('automation');
    await shot('otomasi');
    s.nav('datacenter');
    await shot('pusat_data');
    (s.debugPage('datacenter') as DataCenterPage).previewImport(0, importTemplates[0]);
    await shot('import');
    s.fmScoped('import203', 'button', 1);
    s.nav('upgrade');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.text('Pilih Paket'), const Offset(0, -900));
    await shot('tambahan');
    await tester.tap(find.text('Tambah Cabang'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await shot('tambahan_rincian');
  });
}
