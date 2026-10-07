// Mode murni: alur kasir lengkap tanpa WebView (logika Dart + widget native).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/access.dart';
import 'package:goyana_flutter/pure/pure_shell.dart';

MemoryKvStore _store() {
  final s = jsonDecode(File('test/fixtures/core/snapshot.json').readAsStringSync()) as Map<String, dynamic>;
  return MemoryKvStore({
    for (final k in [Keys.business, Keys.services, Keys.outlets, Keys.activeOutlet, Keys.perfumes])
      if (s[k] is String) k: s[k] as String,
    // Diskon uji (di HTML daftar diskon kosong sampai dibuat di Pengaturan → Diskon).
    'goyana-pure-settings': jsonEncode({
      'discounts': [
        for (final d in [['Diskon 5%', 'p', 5], ['Diskon 10%', 'p', 10], ['Potongan Rp5.000', 'n', 5000], ['Potongan Rp10.000', 'n', 10000]])
          {'id': 4 + [5, 10, 5000, 10000].indexOf(d[2] as int), 'name': d[0], 'type': d[1], 'val': d[2], 'scope': 'Semua layanan', 'min': 0, 'until': '', 'on': true},
      ],
    }),
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
  // Tes alur lama memakai fitur Silver/Gold (pegawai, stok, CRM): jalankan dengan paket uji Platinum.
  setUp(() => planAccess.testPlan = 'PLATINUM');
  tearDown(() => planAccess.testPlan = null);
  testWidgets('kasir: pelanggan baru → layanan → opsi → tunai → pesanan tersimpan', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    // Header spelling follows the approved Flutter brand text.
    expect(find.text('Goyana'), findsWidgets);

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

    s.fmScoped('detail', 'button', 8); // Riwayat
    await _settle(tester);
    expect(find.text('Riwayat Status'), findsOneWidget);
    s.fmScoped('history', 'button', 0);
    await _settle(tester);
    s.tab(6);
    s.search('budi');
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('halaman pelanggan, laporan, pengaturan tampil tanpa error', (tester) async {
    final s = await _pump(tester, _store());
    for (final p in ['customers', 'reports', 'settings', 'receipt', 'printer', 'qris', 'bank', 'services', 'perfume', 'kas', 'outlet', 'today', 'data', 'stock', 'couriers', 'discounts', 'employees', 'help', 'crm', 'whatsapp', 'outlets', 'notif', 'plan', 'home']) {
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
    s.svEdit(0);
    await _settle(tester);
    s.fmScoped('gs107', 'input', 2, '12000'); // Harga Express
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    b = await Business.load(kv);
    expect(b.services.first.priceFor('Express'), 12000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit transaksi: diskon, parfum, keterangan, estimasi', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('orders');
    s.openCard(0);
    await _settle(tester);
    s.fmScoped('detail', 'button', 7);
    await _settle(tester);
    s.fmScoped('edit', 'input', 0, 'rak B2');
    s.fmScoped('edit', 'input', 2, 3); // Potongan Rp5.000
    s.fmScoped('edit', 'input', 3, '5');
    s.fmScoped('edit', 'button', 1);
    await _settle(tester);
    final o = (await Business.load(kv)).orders.first;
    expect(o.note, 'rak B2');
    expect(o.total, 9000);
    expect(o.due!.difference(o.masuk!).inDays, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pesanan jemput tanpa layanan, lalu isi layanan setelah ditimbang', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.tile(0);
    s.aoPickCustomer(0);
    s.fmScoped('dur', 'button', 0);
    await _settle(tester);
    s.aoNext();
    await _settle(tester);
    s.fmScoped('pickup', 'button', 1);
    await _settle(tester);
    var o = (await Business.load(kv)).orders.first;
    expect(o.status, 'jemput');
    expect(o.total, 0);
    s.fmScoped('detail', 'button', 1); // Sudah dijemput
    s.fmScoped('detail', 'button', 9); // Isi layanan
    await _settle(tester);
    s.fmScoped('items', 'input', 0, '3,5');
    s.fmScoped('items', 'button', 1001);
    await _settle(tester);
    o = (await Business.load(kv)).orders.first;
    expect(o.status, 'antrian');
    expect(o.total, 24500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stok bahan: tambah, pemakaian, opname; pegawai & PIN', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('stock');
    await _settle(tester);
    s.fmButton(1);
    s.fmInput(0, 'Deterjen');
    s.fmInput(1, 'liter');
    s.fmInput(2, '2');
    s.fmInput(3, '15000');
    s.fmInput(4, '10');
    s.fmButton(10);
    await _settle(tester);
    s.fmButton(100); // mutasi item 0
    s.fmButton(21); // pemakaian
    s.fmInput(5, '3');
    s.fmButton(12);
    await _settle(tester);
    s.fmButton(200); // opname
    s.fmInput(5, '6');
    s.fmButton(13);
    await _settle(tester);
    final raw = jsonDecode((await kv.get('goyana-stock181'))!) as Map<String, dynamic>;
    final ledger = (raw['ledger'] as List).cast<Map>();
    expect(ledger.map((e) => e['type']), ['Stok Awal', 'Pemakaian', 'Stock Opname']);
    expect(ledger.last['qty'], -1, reason: 'sistem 7, fisik 6');

    s.nav('employees');
    await _settle(tester);
    s.fmInput(0, 'Rina');
    s.fmInput(2, '1234');
    s.fmButton(1);
    s.fmToggle(0);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pertama kali: isi profil outlet', (tester) async {
    final kv = MemoryKvStore({});
    final s = await _pump(tester, kv);
    expect(find.text('Selamat datang di GOYANA'), findsOneWidget);
    s.fmScoped('setup', 'button', 1);
    await _settle(tester);
    expect(find.text('Selamat datang di GOYANA'), findsOneWidget, reason: 'nama wajib');
    s.fmScoped('setup', 'input', 0, 'Goyana Cibubur');
    s.fmScoped('setup', 'button', 1);
    await _settle(tester);
    expect(find.text('Selamat datang di GOYANA'), findsNothing);
    expect((await Business.load(kv)).outlets.single.name, 'Goyana Cibubur');
    expect(tester.takeException(), isNull);
  });

  testWidgets('voucher CRM masuk pilihan diskon; label kantong; cabang', (tester) async {
    final kv2 = _store();
    final t = await _pump(tester, kv2);
    t.nav('crm');
    await _settle(tester);
    t.fmButton(2); // tab voucher
    await _settle(tester);
    t.fmInput(2, 'kangen 15');
    t.fmInput(4, '15');
    t.fmButton(11);
    await _settle(tester);
    t.nav('orders');
    t.openCard(0);
    await _settle(tester);
    t.fmScoped('detail', 'button', 7); // edit
    await _settle(tester);
    expect(find.text('Voucher KANGEN15'), findsNothing, reason: 'dropdown tertutup');
    t.fmScoped('edit', 'input', 2, 5); // voucher = setelah Tanpa diskon + 4 diskon
    t.fmScoped('edit', 'button', 1);
    await _settle(tester);
    final o = (await Business.load(kv2)).orders.first;
    expect(o.discKey, 'p15');
    t.fmScoped('detail', 'button', 10);
    await _settle(tester);
    expect(find.text('Cetak Label Kantong'), findsOneWidget);
    t.fmScoped('label', 'input', 0, '3');
    t.fmScoped('label', 'button', 1);
    await _settle(tester);
    for (final p in ['outlets', 'notif', 'whatsapp', 'plan']) {
      t.nav(p);
      await _settle(tester);
    }
    t.nav('outlets');
    t.fmButton(1);
    await _settle(tester);
    t.fmInput(1, 'Cabang 2');
    t.fmInput(2, 'Bandung');
    t.fmInput(3, '0812');
    t.fmButton(2);
    expect(t.debugToast, 'Lengkapi nama, alamat, dan nomor WA outlet');
    t.fmInput(3, '081299998888');
    t.fmButton(2);
    await _settle(tester);
    expect(t.debugToast, 'Outlet tersimpan');
    expect((await Business.load(kv2)).outlets.length, 2);
    expect(tester.takeException(), isNull);
  });
}
