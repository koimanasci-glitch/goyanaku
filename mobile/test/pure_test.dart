// Mode murni: alur kasir lengkap tanpa WebView (logika Dart + widget native).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/pure_shell.dart';

MemoryKvStore _store() {
  final s = jsonDecode(File('test/fixtures/core/snapshot.json').readAsStringSync()) as Map<String, dynamic>;
  return MemoryKvStore({
    for (final k in [Keys.business, Keys.services, Keys.outlets, Keys.activeOutlet, Keys.perfumes])
      if (s[k] is String) k: s[k] as String,
  });
}

Future<PureShellState> _pump(WidgetTester tester, MemoryKvStore kv) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: PureShell(store: kv, clock: () => DateTime(2026, 10, 3, 10))));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  return tester.state<PureShellState>(find.byType(PureShell));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);
  testWidgets('kasir: pelanggan baru → layanan → opsi → tunai → pesanan tersimpan', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    expect(find.text('GOYANA'), findsWidgets);

    s.tile(0); // Tambah Transaksi
    await _settle(tester);
    s.aoAddCustomer();
    await _settle(tester);
    s.fmScoped('custform', 'input', 0, 'Rina');
    s.fmScoped('custform', 'input', 1, '081277788899');
    s.fmScoped('custform', 'button', 1);
    await _settle(tester);
    // Setelah pelanggan baru tersimpan, lembar durasi terbuka.
    s.fmScoped('dur', 'button', 1); // Express
    await _settle(tester);
    expect(find.text('Rina'), findsWidgets);

    final b = await Business.load(kv);
    final cuci = b.services.indexWhere((x) => x.name == 'Cuci Baju');
    s.aoService(cuci);
    await _settle(tester);
    s.fmScoped('qty', 'input', 0, '2,5');
    s.fmScoped('qty', 'button', 1);
    await _settle(tester);
    s.aoNext();
    await _settle(tester);
    s.aoSheetSelect(1, 2); // Diskon 10%
    s.aoSheetMain();
    await _settle(tester);
    s.aoPay(0); // Tunai
    await _settle(tester);
    s.fmScoped('cash', 'input', 0, '50000');
    await _settle(tester);
    s.fmScoped('cash', 'button', 1);
    await _settle(tester);
    expect(tester.takeException(), isNull);

    final saved = await Business.load(kv);
    final o = saved.orders.first;
    expect(o.name, 'Rina');
    expect(o.dur, 'Express');
    expect(o.items.single.qty, 2.5);
    expect(o.total, 23625, reason: '2,5 kg × 10.500 = 26.250 − 10%');
    expect(o.isPaid, isTrue);
    expect(saved.customerByName('Rina')!.phone, '081277788899');
    expect(find.text('Rincian Pesanan'), findsOneWidget, reason: 'rincian pesanan baru terbuka');

    // Status berikut & batal dari rincian.
    s.fmScoped('detail', 'button', 1);
    await _settle(tester);
    expect((await Business.load(kv)).orders.first.status, 'cuci');
  });

  testWidgets('pesanan: bayar sebagian lalu lunas, batalkan, tab & cari', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('orders');
    await _settle(tester);
    expect(find.text('Budi Native'), findsWidgets);
    s.openCard(0);
    await _settle(tester);
    s.fmScoped('detail', 'button', 2); // Bayar
    await _settle(tester);
    s.fmScoped('pay', 'input', 0, '4000');
    s.fmScoped('pay', 'button', 11); // QRIS
    s.fmScoped('pay', 'button', 1);
    await _settle(tester);
    var o = (await Business.load(kv)).orders.first;
    expect(o.paid, 4000);
    expect(o.payments.single['m'], 'QRIS');

    s.fmScoped('detail', 'button', 3); // Batalkan
    await _settle(tester);
    s.fmScoped('cancel', 'button', 1);
    await _settle(tester);
    o = (await Business.load(kv)).orders.first;
    expect(o.status, isNot('batal'), reason: 'alasan wajib');
    s.fmScoped('cancel', 'input', 0, 2);
    s.fmScoped('cancel', 'button', 1);
    await _settle(tester);
    o = (await Business.load(kv)).orders.first;
    expect(o.status, 'batal');

    s.tab(6);
    s.search('budi');
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('halaman pelanggan, laporan, pengaturan tampil tanpa error', (tester) async {
    final s = await _pump(tester, _store());
    for (final p in ['customers', 'reports', 'settings', 'receipt', 'printer', 'qris', 'bank', 'services', 'perfume', 'kas', 'home']) {
      s.nav(p);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: p);
    }
  });

  testWidgets('kas: kas masuk, pengeluaran, tutup kasir; harga layanan; parfum', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('kas');
    await _settle(tester);
    s.fmButton(1); // kas masuk
    s.fmInput(0, 1); // Modal awal
    s.fmInput(1, '100000');
    s.fmButton(10);
    await _settle(tester);
    s.fmButton(2); // pengeluaran
    s.fmInput(0, 3); // Listrik
    s.fmInput(1, '20000');
    s.fmButton(10);
    await _settle(tester);
    var b = await Business.load(kv);
    var sh = b.shift();
    expect(sh.start, 100000);
    expect(sh.outs, 20000);
    expect(sh.cashExpected, 100000 + 100000 - 20000, reason: 'modal + kas masuk (modal) − pengeluaran');
    s.fmButton(3); // tutup kasir
    s.fmInput(3, '170000');
    s.fmButton(12);
    await _settle(tester);
    b = await Business.load(kv);
    expect((b.kas['hist'] as List), isEmpty, reason: 'selisih tanpa catatan ditolak');
    s.fmInput(2, 'uang kembalian kurang');
    s.fmButton(12);
    await _settle(tester);
    b = await Business.load(kv);
    expect((b.kas['hist'] as List).single['diff'], -10000);
    expect(b.shift().sales, 0, reason: 'shift baru dimulai');

    s.nav('services');
    await _settle(tester);
    s.fmInput(1, '12000'); // layanan 0, Express
    s.fmButton(0);
    await _settle(tester);
    b = await Business.load(kv);
    expect(b.services.first.priceFor('Express'), 12000);

    s.nav('perfume');
    s.fmInput(0, 'Melati');
    s.fmButton(1);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
