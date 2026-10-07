// Mode murni: Pengaturan → Diskon mengirim butir yang sama persis dengan HTML (tangkapan test/fixtures/pure/discount.json).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/delivery.dart';
import 'package:goyana_flutter/native/cash_page.dart';
import 'package:goyana_flutter/native/cashclose_page.dart';
import 'package:goyana_flutter/pure/access.dart';
import 'package:goyana_flutter/pure/cash_pages.dart';
import 'package:goyana_flutter/pure/pure_shell.dart';
import 'package:goyana_flutter/pure/views.dart';

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
  // Kunci unik: tiap pump membuat ulang aplikasi dari data tersimpan (seperti menutup lalu membuka aplikasi).
  await tester.pumpWidget(MaterialApp(home: PureShell(key: UniqueKey(), store: kv, clock: () => DateTime(2026, 10, 3, 10))));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  return tester.state<PureShellState>(find.byType(PureShell));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  servicesTests();
  templateTests();
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final f in ['Regular', 'Medium', 'SemiBold']) {
      final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  testWidgets('Diskon: butir halaman dan popup sama dengan HTML di tiap langkah', (tester) async {
    final fx = (jsonDecode(File('test/fixtures/pure/discount.json').readAsStringSync()) as List).cast<Map>();
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('discounts');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[0]['model']['items']), reason: 'halaman kosong');

    s.fmButton(0);
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('disc127')), jsonEncode(fx[1]['sheet']['items']), reason: 'popup Tambah Diskon');
    s.fmScoped('disc127', 'button', 2);
    expect(s.debugToast, 'Isi nama diskon');
    s.fmScoped('disc127', 'input', 0, 'Member');
    s.fmScoped('disc127', 'input', 1, '10');
    s.fmScoped('disc127', 'input', 3, '50000');
    s.fmScoped('disc127', 'button', 2);
    await _settle(tester);
    expect(s.debugToast, fx[2]['toast']);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[2]['model']['items']), reason: 'halaman dengan 1 diskon');
    expect(s.debugSheet('disc127') == null || find.text('Tambah Diskon').evaluate().isEmpty, isTrue);

    s.fmButton(1); // ✎
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('disc127')), jsonEncode(fx[3]['sheet']['items']), reason: 'popup Edit Diskon');
    s.fmScoped('disc127', 'close', 0);
    await _settle(tester);

    s.fmButton(2); // 🗑
    await _settle(tester);
    final want = (fx[4]['sheet']['items'] as List).cast<Map>();
    for (final it in want) {
      expect(find.text('${it['t']}'), findsOneWidget, reason: '${it['t']}');
    }
    s.fmScoped('gs107', 'button', 1); // Batal
    await _settle(tester);

    // Tersimpan permanen (di HTML daftar diskon hilang saat aplikasi ditutup).
    final t = await _pump(tester, kv);
    t.nav('discounts');
    await _settle(tester);
    expect(jsonEncode(t.debugItems()), jsonEncode(fx[2]['model']['items']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Diskon di Atur Pesanan: pilihan, minimal transaksi, dan diskon manual seperti HTML', (tester) async {
    final kv = _store();
    kv.data['goyana-pure-settings'] = jsonEncode({
      'discounts': [
        {'id': 4, 'name': 'Member', 'type': 'p', 'val': 10, 'scope': 'Semua layanan', 'min': 50000, 'until': '', 'on': true},
        {'id': 5, 'name': 'Promo Satuan', 'type': 'n', 'val': 5000, 'scope': 'Satuan', 'min': 0, 'until': '', 'on': true},
        {'id': 6, 'name': 'Lama', 'type': 'p', 'val': 5, 'scope': 'Semua layanan', 'min': 0, 'until': '2026-01-01', 'on': true},
        {'id': 7, 'name': 'Mati', 'type': 'p', 'val': 5, 'scope': 'Semua layanan', 'min': 0, 'until': '', 'on': false},
      ],
    });
    final s = await _pump(tester, kv);
    expect(s.debugDiscOptions(), ['Tidak', 'Member · 10% · min Rp50.000', 'Promo Satuan · Rp5.000 (Satuan)', 'Diskon manual (Rp)…', '🎟 Pakai kode voucher…']);
    s.aoSheetSelect(3, 1); // keranjang kosong: di bawah minimal
    expect(s.debugToast, '"Member" butuh minimal transaksi Rp50.000');
    s.aoSheetSelect(3, 3);
    await _settle(tester);
    expect(find.text('Diskon manual'), findsOneWidget);
    expect(find.text('Potongan (Rp)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

// ---- Layanan ----
void servicesTests() {
  testWidgets('Layanan: model halaman, popup Kategori Baru dan Edit Layanan sama dengan HTML', (tester) async {
    final fx = (jsonDecode(File('test/fixtures/pure/services.json').readAsStringSync()) as List).cast<Map>();
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('services');
    await _settle(tester);
    expect(jsonEncode(s.servicesJson()), jsonEncode(fx[0]['model']), reason: 'halaman Layanan');
    s.svAdd();
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('cat99')), jsonEncode(fx[1]['sheet']['items']), reason: 'popup Kategori Baru');
    s.fmScoped('cat99', 'close', 0);
    await _settle(tester);
    s.svEdit(0);
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('gs107')), jsonEncode(fx[2]['sheet']['items']), reason: 'popup Edit Layanan');
    s.fmScoped('gs107', 'button', 1);
    await _settle(tester);
    s.svToggle(0, 0);
    await _settle(tester);
    expect(jsonEncode(s.servicesJson()), jsonEncode(fx[3]['model']), reason: 'Reguler dimatikan');

    // Kategori baru: harga Express 1,4× dibulatkan Rp500, Kilat 2×.
    s.svAdd();
    await _settle(tester);
    s.fmScoped('cat99', 'button', 29);
    expect(s.debugToast, 'Isi nama kategori dulu');
    s.fmScoped('cat99', 'input', 0, 'Cuci Tas');
    s.fmScoped('cat99', 'input', 1, '25000');
    s.fmScoped('cat99', 'button', 19); // ikon Tas
    s.fmScoped('cat99', 'button', 23); // pcs
    s.fmScoped('cat99', 'button', 29);
    await _settle(tester);
    expect(s.debugToast, 'Kategori "Cuci Tas" tersimpan · harga Express & Kilat bisa diubah');
    final first = (jsonDecode(kv.data[Keys.services]!) as List).first as Map;
    expect(first['prices'], {'Reguler': 25000, 'Express': 35000, 'Kilat': 50000});
    expect(first['unit'], 'pcs');
    expect(first['proc'], ['Cuci', 'Kering', 'Packing']);
    expect(tester.takeException(), isNull);
  });
}

// ---- Halaman berpola tetap (butir = tangkapan HTML) ----
void templateTests() {
  testWidgets('Halaman pola tetap: butir sama persis dengan HTML dan bisa digambar', (tester) async {
    planAccess.testPlan = 'PLATINUM';
    addTearDown(() => planAccess.testPlan = null);
    final kv = _store();
    final s = await _pump(tester, kv);
    for (final f in Directory('test/fixtures/pure/pages').listSync().whereType<File>()) {
      final id = f.uri.pathSegments.last.replaceAll('.json', '');
      final fx = jsonDecode(f.readAsStringSync()) as Map;
      if (id == 'wadevices195' || id == 'upgrade') continue; // tangkapan dibuat tanpa pesanan/outlet lain; diuji terpisah
      if (id == 'datacenter') {
        // Tangkapan HTML dari data kosong; data uji punya 1 pelanggan & 1 transaksi.
        final cells = (fx['items'] as List)[0]['cells'] as List;
        cells[0]['v'] = '1';
        cells[1]['v'] = '1';
      }
      s.nav(id);
      await _settle(tester);
      expect(jsonEncode(s.debugItems()), jsonEncode(fx['items']), reason: id);
      expect(tester.takeException(), isNull, reason: id);
    }
  });

  testWidgets('Profil: validasi dan simpan seperti HTML; saklar Reminder tersimpan', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('profile');
    await _settle(tester);
    s.fmButton(0);
    expect(s.debugToast, 'Nama wajib diisi');
    s.fmInput(0, 'Koiman');
    s.fmInput(1, 'salah');
    s.fmButton(0);
    expect(s.debugToast, 'Format email belum benar');
    s.fmInput(1, 'a@b.co');
    s.fmInput(2, '123');
    s.fmButton(0);
    expect(s.debugToast, 'Password minimal 6 karakter');
    s.fmInput(2, '123456');
    s.fmButton(0);
    expect(s.debugToast, 'Profil tersimpan');
    s.nav('reminder');
    await _settle(tester);
    s.fmToggle(1);
    await _settle(tester);
    final t = await _pump(tester, kv);
    t.nav('reminder');
    await _settle(tester);
    expect((t.debugItems().where((e) => e['type'] == 'toggle').toList()[1])['on'], false);
    t.nav('profile');
    await _settle(tester);
    expect(t.debugItems()[2]['v'], 'Koiman');
    expect(t.debugItems()[6]['v'], '', reason: 'password tidak disimpan');
  });

  testWidgets('Pusat Bantuan: cari topik, popup panduan dan Coba Sekarang', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('helpcenter');
    await _settle(tester);
    s.fmInput(0, 'printer');
    await _settle(tester);
    expect(s.debugItems().where((e) => e['type'] == 'card').map((e) => e['t']), ['Printer, Struk & Label']);
    s.fmButton(3);
    await _settle(tester);
    expect(find.text('Coba Sekarang'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);
    await tester.tap(find.text('Coba Sekarang'));
    await _settle(tester);
    expect(find.text('Coba Sekarang'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pusat Data: hapus data trial sungguhan setelah ketik HAPUS', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('datacenter');
    await _settle(tester);
    s.fmButton(1);
    await _settle(tester);
    expect(s.debugItems().where((e) => e['t'] == 'Import Layanan & Harga').length, 2, reason: 'kartu + judul preview');
    s.fmButton(6);
    await _settle(tester);
    s.fmScoped('gs107', 'input', 0, 'hapuz');
    s.fmScoped('gs107', 'button', 0);
    expect(s.debugToast, 'Ketik HAPUS untuk konfirmasi');
    s.fmScoped('gs107', 'input', 0, 'hapus');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, 'Data trial dihapus · siap mulai dari nol');
    final raw = jsonDecode(kv.data[Keys.business]!) as Map;
    expect(raw['orders'], isEmpty);
    expect(raw['customers'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kategori Pengeluaran: tambah, ubah, hapus dengan butir seperti HTML', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('finance');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), '[{"type":"button","t":"+ Tambah Kategori","primary":true,"file":"","after":false,"i":0}]');
    s.fmButton(0);
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('gs107')),
        '[{"type":"title","t":"Tambah Kategori","s":""},{"type":"hint","t":"Kategori untuk mencatat pengeluaran"},{"type":"label","t":"Nama kategori"},{"type":"input","v":"","ph":"Contoh: Perawatan Mesin","multiline":false,"numeric":false,"decimal":false,"ro":false,"secret":false,"email":false,"i":0},{"type":"button","t":"Tambah","primary":true,"file":"","after":false,"i":0},{"type":"button","t":"Batal","primary":false,"file":"","after":false,"i":1}]');
    s.fmScoped('gs107', 'input', 0, 'Gaji');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, 'Kategori "Gaji" ditambahkan');
    expect(jsonEncode(s.debugItems()),
        '[{"type":"entry","t":"Gaji","lines":[],"badge":"","avatar":"","svg":"","color":"","compact":true,"btns":[{"t":"✎","on":false,"i":0},{"t":"×","on":false,"i":1}]},{"type":"button","t":"+ Tambah Kategori","primary":true,"file":"","after":false,"i":2}]');
    s.fmButton(0);
    await _settle(tester);
    s.fmScoped('gs107', 'input', 0, 'Gaji Pegawai');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, 'Perubahan tersimpan');
    s.fmButton(1);
    await _settle(tester);
    expect(find.text('Hapus "Gaji Pegawai"?'), findsOneWidget);
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(s.debugItems().length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Antar-Jemput: butir tiap mode tarif sama dengan HTML; ongkir masuk total pesanan', (tester) async {
    final kv = _store();
    kv.data['goyana-pure-settings'] = jsonEncode({
      'delivery': {'couriers': [{'n': 'Andi', 'p': '0857-2233-4455'}, {'n': 'Dimas', 'p': '0813-5566-7788'}]},
    });
    final s = await _pump(tester, kv);
    final b = await Business.load(kv);
    final outlet = b.outlets.isEmpty ? 'Outlet Aktif' : (b.outlets.where((o) => o.id == b.activeOutlet).firstOrNull ?? b.outlets.first).name;
    final fx = (jsonDecode(File('test/fixtures/pure/delivery.json').readAsStringSync().replaceAll('untuk Outlet Aktif.', 'untuk $outlet.')) as List).cast<Map>();
    s.nav('delivery');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[0]['items']), reason: 'gratis');
    s.fmRadio(1);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[1]['items']), reason: 'tarif tetap');
    s.fmRadio(2);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[3]['items']), reason: 'terpisah');
    s.fmRadio(3);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[4]['items']), reason: 'pulang-pergi');
    s.fmRadio(4);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[5]['items']), reason: 'jarak');

    s.fmRadio(2);
    s.fmInput(0, '4000');
    s.fmInput(1, '6000');
    s.fmButton(0);
    await _settle(tester);
    expect(s.debugToast, 'Tarif transportasi tersimpan');
    final saved = (jsonDecode(kv.data['goyana-transport183']!) as Map).values.first as Map;
    expect([saved['mode'], saved['pickup'], saved['delivery']], ['split', 4000, 6000]);
    expect(transportFee('Antar ke Pelanggan', Map<String, dynamic>.from(saved)), 6000);
    expect(transportFee('Jemput & Antar', Map<String, dynamic>.from(saved)), 10000);
    expect(transportFee('Datang Langsung', Map<String, dynamic>.from(saved)), 0);

    s.fmToggle(3); // antar dimatikan → hanya Datang Langsung
    await _settle(tester);
    expect(s.debugToast, 'Pengaturan antar-jemput diperbarui');
    s.fmToggle(1);
    await _settle(tester);
    expect(s.debugToast, fx[7]['toast']);
    transportAll.clear();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Outlet & Edit Outlet: butir sama dengan HTML (outlet Uji)', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/outlets.json').readAsStringSync()) as Map;
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('outlets');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['list']));
    s.fmButton(3); // Edit
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['edit']));
    s.nav('outlets');
    s.fmButton(1); // Tambah
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['new']));
    s.fmInput(1, 'uji');
    s.fmInput(2, 'jakarta');
    s.fmInput(3, '081234567890');
    s.fmButton(2);
    expect(s.debugToast, 'Outlet dengan nama dan alamat ini sudah ada. Gunakan Edit.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kunci paket seperti HTML: trial Basic menolak Pegawai/Stok/CRM/Ekspor; Mode Uji membukanya', (tester) async {
    expect(sha256Hex(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    final kv = _store();
    final s = await _pump(tester, kv);
    await _settle(tester);
    expect(jsonDecode(kv.data['goyana-trial190']!)['until'], isNotNull);
    s.nav('employees');
    expect(s.debugToast, 'Pegawai membutuhkan paket Silver');
    s.nav('stock');
    expect(s.debugToast, 'Stok bahan membutuhkan paket Silver');
    s.nav('crm');
    expect(s.debugToast, 'Loyalitas pelanggan membutuhkan paket Gold');
    s.nav('datacenter');
    await _settle(tester);
    s.fmButton(3);
    expect(s.debugToast, 'Ekspor Data membutuhkan paket Silver');

    s.nav('testmode192');
    await _settle(tester);
    s.fmInput(0, 'salah');
    s.fmButton(0);
    await _settle(tester);
    expect(find.text('Password salah.'), findsOneWidget);
    expect(planAccess.testPlan, isNull);
    planAccess.testPlan = 'SILVER';
    s.nav('employees');
    await _settle(tester);
    expect(s.debugToast, isNot('Pegawai membutuhkan paket Silver'));
    s.nav('crm');
    expect(s.debugToast, 'Loyalitas pelanggan membutuhkan paket Gold');
    planAccess.testPlan = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pegawai: formulir, validasi, simpan dan edit sama dengan HTML', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/employees.json').readAsStringSync()) as Map;
    planAccess.testPlan = 'SILVER';
    addTearDown(() => planAccess.testPlan = null);
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('employees');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['empty']));
    s.fmButton(0);
    expect(s.debugToast, 'Isi nama pegawai');
    s.fmInput(0, 'Rani');
    s.fmInput(1, '0812');
    s.fmButton(0);
    expect(s.debugToast, 'Periksa nomor handphone');
    s.fmInput(1, '081211112222');
    s.fmInput(2, 'rani');
    s.fmButton(0);
    expect(s.debugToast, 'Periksa alamat email');
    s.fmInput(2, 'rani@x.co');
    s.fmInput(3, '123');
    s.fmButton(0);
    expect(s.debugToast, 'Password minimal 6 karakter');
    s.fmInput(3, 'rahasia');
    s.fmToggle(0);
    s.fmToggle(12);
    s.fmButton(0);
    await _settle(tester);
    expect(s.debugToast, 'Data pegawai tersimpan di perangkat ini');
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['saved']));
    expect(jsonDecode(kv.data['goyana_employees_v157']!), [
      {'name': 'Rani', 'phone': '081211112222', 'email': 'rani@x.co', 'permissions': ['order_create', 'revenue']},
    ]);
    s.fmButton(1); // Edit
    await _settle(tester);
    final it = s.debugItems();
    expect(it[1]['v'], 'Rani');
    expect(it.where((e) => e['type'] == 'toggle' && e['on'] == true).map((e) => e['i']), [0, 12]);
    expect(it.firstWhere((e) => e['type'] == 'button')['t'], 'SIMPAN PERUBAHAN PEGAWAI');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Audit Aktivitas: daftar, chip dan pencarian sama dengan HTML', (tester) async {
    final fx = (jsonDecode(File('test/fixtures/pure/audit.json').readAsStringSync()) as List);
    final kv = _store();
    final at = DateTime(2026, 10, 3, 9).toIso8601String();
    kv.data['goyana-pure-settings'] = jsonEncode({
      'audit': [
        {'ic': '✓', 't': 'Tutup kas', 's': 'Kasir · omset Rp10.000', 'at': at},
        {'ic': '✎', 't': 'Ralat transaksi', 's': 'Rani · 1 → 2', 'at': at},
      ],
    });
    final s = await _pump(tester, kv);
    s.nav('audit');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[1]));
    s.fmButton(3);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[2]), reason: 'Kas');
    s.fmButton(2);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[3]), reason: 'Transaksi');
    s.fmButton(1);
    s.fmInput(0, 'rani');
    final got = s.debugItems();
    got[1]['v'] = '';
    expect(jsonEncode(got), jsonEncode(fx[4]).replaceFirst('"v":"rani"', '"v":""'), reason: 'cari');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kurir: Management Kurir (tambah, edit, nonaktifkan) sama dengan HTML', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/couriers.json').readAsStringSync().replaceAll('Outlet Aktif', 'Uji')) as Map;
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('couriers');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['tasks']));
    s.fmButton(1);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['manage']));
    s.fmButton(2);
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('g181-modal')), jsonEncode(fx['form']));
    s.fmScoped('g181-modal', 'input', 0, 'Budi');
    s.fmScoped('g181-modal', 'input', 1, '0812');
    s.fmScoped('g181-modal', 'button', 0);
    expect(s.debugToast, 'Lengkapi nama dan WhatsApp');
    s.fmScoped('g181-modal', 'input', 1, '081233334444');
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['one']));
    s.fmButton(3);
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('g181-modal')), jsonEncode(fx['edit']));
    s.fmScoped('g181-modal', 'button', 1);
    s.fmButton(4);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['off']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pembayaran: butir, tempel teks QRIS, QRIS dinamis dan rekening sama dengan HTML', (tester) async {
    final fx = (jsonDecode(File('test/fixtures/pure/qris.json').readAsStringSync().replaceAll('Outlet Gramapuri', 'Outlet Uji').replaceAll('"avatar": "G"', '"avatar": "U"')) as List).cast<Map>();
    final q = (jsonDecode(File('test/fixtures/core/qris.json').readAsStringSync()) as Map)['static'] as String;
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('qris');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[0]['items']));
    s.fmButton(1);
    expect(s.debugToast, 'Teks QRIS tidak valid. Periksa kode yang ditempel.');
    s.fmInput(1, q);
    s.fmButton(1);
    await _settle(tester);
    expect(s.debugToast, fx[1]['toast']);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[1]['items']));
    s.fmToggle(0);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[2]['items']));
    expect(jsonDecode(kv.data['goyana-qris-options185']!), {'dynamic': false});
    s.fmInput(2, 'BCA');
    s.fmButton(2);
    expect(s.debugToast, fx[3]['toast']);
    s.fmInput(3, '1234567');
    s.fmInput(4, 'Koiman');
    s.fmButton(2);
    await _settle(tester);
    expect(s.debugToast, fx[4]['toast']);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx[4]['items']));
    expect([kv.data['gy154-bank'], kv.data['gy154-account'], kv.data['gy154-holder']], ['BCA', '1234567', 'Koiman']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Printer & Nota + Printer Bluetooth: susunan butir sama dengan HTML; profil nota tersimpan', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/printer.json').readAsStringSync()) as Map;
    // Nilai isian HTML adalah contoh tertanam; yang dibandingkan susunan butirnya.
    String shape(Object items) => jsonEncode([
          for (final it in (items as List).cast<Map>()) {...it, if (it['type'] == 'input') 'v': ''},
        ]);
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('printer');
    await _settle(tester);
    expect(shape(s.debugItems()), shape(fx['printer']));
    s.fmInput(0, 'Laundry Uji');
    s.fmRadio(1);
    s.fmToggle(1);
    s.fmButton(2);
    await _settle(tester);
    expect(s.debugToast, 'Pengaturan printer & nota tersimpan');
    final saved = (jsonDecode(kv.data['goyana-pure-settings']!) as Map)['receipt'] as Map;
    expect([saved['header'], saved['width'], saved['showDue']], ['Laundry Uji', 48, false]);
    s.fmButton(0);
    await _settle(tester);
    final got = s.debugItems();
    expect(got.first['t'], 'Belum terhubung');
    expect(jsonEncode(got.sublist(1)), jsonEncode((fx['none'] as List).sublist(1)).replaceFirst('Belum ada perangkat dipasangkan. Buka Pengaturan Bluetooth HP.', 'Pasangkan printer di Bluetooth HP, lalu Cari Ulang Printer.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stok & Bahan: halaman, popup alat, pembelian hutang dan riwayat sama dengan HTML', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/stock.json').readAsStringSync().replaceAll('· Outlet Aktif', '· Uji')) as Map;
    planAccess.testPlan = 'PLATINUM';
    addTearDown(() => planAccess.testPlan = null);
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('stock');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['empty']));
    s.fmButton(1);
    expect(s.debugToast, 'Tambahkan bahan dulu');
    s.fmButton(0);
    await _settle(tester);
    expect(jsonEncode(s.debugSheet('g181-modal')), jsonEncode(fx['add']));
    for (final (k, v) in ['Deterjen', '10', 'liter', '3', '15000'].indexed) {
      s.fmScoped('g181-modal', 'input', k, v);
    }
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['one']));
    for (final (i, name) in [(1, 'move'), (2, 'op'), (4, 'sup'), (5, 'buy')]) {
      s.fmButton(i);
      await _settle(tester);
      expect(jsonEncode(s.debugSheet('g181-modal')), jsonEncode(fx[name]), reason: name);
      s.fmScoped('g181-modal', 'button', 1);
      await _settle(tester);
    }
    s.fmButton(3);
    expect(s.debugToast, 'Minimal 2 outlet');
    s.fmButton(4);
    await _settle(tester);
    s.fmScoped('g181-modal', 'input', 0, 'Toko Sabun');
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    s.fmButton(5);
    await _settle(tester);
    s.fmScoped('g181-modal', 'input', 0, 1);
    s.fmScoped('g181-modal', 'input', 2, '2.5');
    s.fmScoped('g181-modal', 'input', 3, '16000');
    s.fmScoped('g181-modal', 'input', 4, 1);
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['bought']));
    s.fmButton(8);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['debt']));
    s.fmButton(9);
    // Jam di riwayat mengikuti waktu pencatatan; yang dibandingkan judul & jumlahnya.
    String rows(Object items) => jsonEncode([for (final it in (items as List).cast<Map>()) if (it['type'] == 'entry') [it['t'], it['amount'], '${(it['lines'] as List).first}'.split(' · ').last]]);
    expect(rows(s.debugItems()), rows(fx['hist']));
    s.fmButton(8);
    s.fmButton(10); // Tandai Lunas
    await _settle(tester);
    expect(s.debugItems().any((e) => e['t'] == 'Tidak ada hutang supplier.'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Voucher kode unik CRM di Atur Pesanan: validasi dan pesan sama dengan HTML', (tester) async {
    final kv = _store();
    kv.data['goyana-crm203'] = jsonEncode({
      'vouchers': [
        {'code': 'GY-AAAAA', 'name': 'Kangen', 'type': 'p', 'val': 15, 'min': 0, 'until': '', 'who': 'Koiman', 'used': false, 'batch': 'b1'},
        {'code': 'GY-BBBBB', 'name': 'Lama', 'type': 'n', 'val': 5000, 'min': 0, 'until': '2026-01-01', 'who': 'Koiman', 'used': false, 'batch': 'b1'},
        {'code': 'GY-CCCCC', 'name': 'Pakai', 'type': 'n', 'val': 5000, 'min': 0, 'until': '', 'who': 'Koiman', 'used': true, 'batch': 'b1'},
      ],
    });
    final s = await _pump(tester, kv);
    final last = s.debugDiscOptions().length - 1;
    Future<void> tryCode(String code) async {
      s.aoSheetSelect(3, last);
      await _settle(tester);
      expect(find.text('Kode voucher'), findsWidgets);
      s.fmScoped('gs107', 'input', 0, code);
      s.fmScoped('gs107', 'button', 0);
      await _settle(tester);
    }

    await tryCode('gy-zzzzz');
    expect(s.debugToast, 'Kode tidak ditemukan');
    await tryCode('GY-BBBBB');
    expect(s.debugToast, 'Kode sudah kedaluwarsa');
    await tryCode('GY-CCCCC');
    expect(s.debugToast, 'Kode sudah pernah dipakai');
    await tryCode('gy-aaaaa');
    expect(s.debugToast, 'Voucher GY-AAAAA dipakai (Koiman)');
    expect(s.debugDiscOptions().last, '🎟 GY-AAAAA · 15%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manajemen Cabang & Monitor Cabang: butir sama dengan HTML (tanpa pesanan)', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/branches.json').readAsStringSync()) as Map;
    final kv = _store();
    final raw = jsonDecode(kv.data[Keys.business]!) as Map;
    raw['orders'] = <dynamic>[];
    raw['details'] = <String, dynamic>{};
    kv.data[Keys.business] = jsonEncode(raw);
    final s = await _pump(tester, kv);
    s.nav('superbilling');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['one']));
    s.fmButton(1);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['monitor']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Balasan Cepat & Trigger: formulir, simpan dan edit sama dengan HTML; menu chatbot terkunci tanpa paket', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/triggers.json').readAsStringSync()) as Map;
    final kv = _store();
    final s = await _pump(tester, kv);
    await _settle(tester);
    s.stItem(4, 3);
    await _settle(tester);
    expect(find.text('WhatsApp & Chatbot terkunci'), findsOneWidget);
    s.fmScoped('lock111', 'close', 0);
    s.stGroup(6, false);
    expect(s.debugToast, 'Balasan Cepat membutuhkan paket Silver');
    planAccess.testPlan = 'PLATINUM';
    addTearDown(() => planAccess.testPlan = null);
    s.stGroup(6, false);
    await _settle(tester);
    s.fmButton(0);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['form']));
    s.fmButton(1);
    expect(s.debugToast, 'Isi nama, pemicu dan teks atau gambar.');
    s.fmInput(0, 'Harga');
    s.fmInput(1, 'harga, biaya');
    s.fmInput(3, 'Mulai Rp7.000/kg');
    s.fmButton(1);
    await _settle(tester);
    expect(s.debugToast, 'Balasan tersimpan');
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['saved']));
    s.fmButton(1);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['edit']));
    expect(kv.data.keys.any((k) => k.startsWith('goyana-chat191:')), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deposit Pelanggan (popup dari Pengaturan): tambah saldo tercatat', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    await _settle(tester);
    s.stItem(9, 6);
    await _settle(tester);
    expect(find.text('Deposit Pelanggan'), findsOneWidget);
    s.fmScoped('deposits178', 'button', 0);
    expect(s.debugToast, 'Isi nominal saldo yang benar');
    s.fmScoped('deposits178', 'input', 1, '50000');
    s.fmScoped('deposits178', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, 'Saldo deposit tersimpan');
    final b = await Business.load(kv);
    expect(b.depositOf(b.customers.first.name), 50000);
    s.stItem(12, 2);
    await _settle(tester);
    expect(find.text('Izin Aplikasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ralat & Log Koreksi: halaman kosong sama dengan HTML', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/ralat.json').readAsStringSync()) as Map;
    final kv = _store();
    kv.data['goyana-pure-settings'] = jsonEncode({'adminName': 'Koko'});
    final s = await _pump(tester, kv);
    s.nav('ralat139');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['empty']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ralat: ralat pembayaran (QRIS), ralat pengeluaran, log, dan PIN Admin untuk kasir', (tester) async {
    final kv = _store();
    // Siapkan 1 pembayaran tunai Rp10.000 dan 1 pengeluaran.
    final b = await Business.load(kv);
    final o = b.orders.first;
    expect(b.pay(o, method: 'Tunai', amount: 10000, now: DateTime(2026, 10, 3, 9)), isNull);
    b.kasEntry(income: false, type: 'Listrik', amount: 50000, note: 'token', now: DateTime(2026, 10, 3, 9, 30));
    await b.save();
    final s = await _pump(tester, kv);
    s.nav('ralat139');
    await _settle(tester);
    var rows = s.debugItems().where((e) => e['type'] == 'entry').toList();
    expect(rows[1]['t'], o.id);
    expect(rows[1]['amount'], 'Rp10.000');
    s.fmButton(5);
    await _settle(tester);
    s.fmScoped('rs139', 'button', 1); // QRIS
    s.fmScoped('rs139', 'button', 8);
    expect(s.debugToast, 'Pilih alasan ralat dulu');
    s.fmScoped('rs139', 'button', 3);
    s.fmScoped('rs139', 'button', 8);
    await _settle(tester);
    expect(s.debugToast, 'Ralat tersimpan · tercatat di Log Ralat');
    var after = await Business.load(kv);
    expect((after.kas['sales'] as List).single['m'], 'QRIS');
    expect(after.orders.first.paid, 10000);

    s.fmButton(3); // Pengeluaran
    s.fmButton(5);
    await _settle(tester);
    s.fmScoped('rs139', 'input', 1, '45.000');
    s.fmScoped('rs139', 'button', 0);
    s.fmScoped('rs139', 'button', 5);
    await _settle(tester);
    after = await Business.load(kv);
    expect((after.kas['outs'] as List).single['a'], 45000);
    s.fmButton(4); // Log
    rows = s.debugItems().where((e) => e['type'] == 'entry').toList();
    expect(rows.length, 3, reason: 'baris login + 2 log');
    expect(rows[1]['t'], 'Ralat pengeluaran');

    // Kasir butuh PIN Admin Utama.
    s.fmButton(1);
    s.fmButton(2);
    s.fmButton(5);
    await _settle(tester);
    s.fmScoped('rs139', 'button', 5);
    s.fmScoped('rs139', 'button', 7); // Batalkan Bayar
    await _settle(tester);
    expect(find.text('PIN Admin Utama'), findsOneWidget);
    s.fmScoped('pin139', 'input', 0, '0000');
    s.fmScoped('pin139', 'button', 0);
    expect(s.debugToast, 'PIN salah');
    s.fmScoped('pin139', 'input', 0, '1234');
    s.fmScoped('pin139', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, 'Pembayaran dibatalkan · pesanan jadi Belum Bayar');
    after = await Business.load(kv);
    expect(after.orders.first.paid, 0);
    expect((after.kas['voided'] as List).length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kas: Penambahan Kas, Pengeluaran dan Tutup Kasir memakai halaman Hibrida dan hitungan A7', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.rpQuick(0);
    await _settle(tester);
    expect(find.byType(NativeCash), findsOneWidget);
    final cashin = CashEntryPage(s, income: true);
    expect(cashin.model()['submit'], 'Tambah Kas');
    cashin.submit();
    expect(s.debugToast, 'Isi jumlah terlebih dahulu');
    cashin.amount = '100000';
    cashin.submit();
    await _settle(tester);
    expect(s.debugToast, 'Penambahan kas tersimpan');
    var b = await Business.load(kv);
    expect((b.kas['ins'] as List).single['a'], 100000);

    s.rpQuick(2);
    await _settle(tester);
    expect(find.byType(NativeCashClose), findsOneWidget);
    final page = CashClosePage(s);
    final m = page.model();
    expect(m['title'], 'TUTUP KASIR');
    expect(m['date'], 'Sabtu, 3 Okt 2026');
    expect(((m['sections'] as List)[1]['rows'] as List)[4]['v'], 'Rp100.000', reason: 'seharusnya di laci');
    page.tap('#cashclose .kc137-go', 0, null);
    expect(s.debugToast, 'Hitung uang di laci dulu');
    page.tap('#kc-den label', 0, 'button:last-of-type'); // 1 lembar 100rb
    page.tap('#cashclose .kc137-go', 0, null);
    await _settle(tester);
    expect(find.text('Tutup kas sekarang?'), findsOneWidget);
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    b = await Business.load(kv);
    expect((b.kas['hist'] as List).length, 1);
    expect((b.kas['hist'] as List).first['diff'], 0);
    expect(b.kas['ins'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Antar Jemput (v202): buat penjemputan, tugaskan kurir, Sampai Lokasi → transaksi; butir sama dengan HTML', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/pickup.json').readAsStringSync()) as Map;
    final kv = _store();
    kv.data['goyana-couriers181'] = jsonEncode([{'id': 'k1', 'name': 'Budi', 'phone': '081233334444', 'outlets': [], 'active': true}]);
    final s = await _pump(tester, kv);
    s.tile(1);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['empty']));
    s.fmButton(0);
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['new']));
    s.fmInput(0, 'Sari');
    s.fmInput(1, '081277776666');
    s.fmButton(0);
    expect(s.debugToast, 'Isi alamat atau link Maps');
    s.fmInput(2, 'Jl. Mawar 1');
    s.fmInput(6, 'Cuci kering');
    s.fmButton(0);
    await _settle(tester);
    expect(s.debugToast, 'Penjemputan dibuat');
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['one']));
    s.fmButton(5);
    expect(s.debugToast, 'Pilih kurir dulu');
    s.fmInput(0, 1);
    s.fmButton(5);
    await _settle(tester);
    expect(s.debugToast, 'Ditugaskan ke Budi · tekan Kirim ke Kurir untuk mengabari lewat WhatsApp');
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['assigned']));
    expect((await Business.load(kv)).customers.any((c) => c.name == 'Sari'), isTrue, reason: 'pelanggan baru ikut tersimpan');
    s.fmButton(7); // Sampai Lokasi
    await _settle(tester);
    expect(s.debugToast, 'Timbang barang, lalu pilih ongkos kirim di opsi pesanan');
    final saved = (jsonDecode(kv.data['goyana-pickup202']!) as List).single as Map;
    expect(saved['status'], 'sampai');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tambah Transaksi: model tiap tahap sama dengan HTML (bundel final)', (tester) async {
    Object? canon(Object? v) {
      if (v is Map) return {for (final k in (v.keys.map((e) => '$e').toList()..sort())) k: canon(v[k])};
      if (v is List) return [for (final x in v) canon(x)];
      return v;
    }

    final fx = jsonDecode(File('test/fixtures/pure/addorder.json').readAsStringSync()) as Map;
    final kv = _store();
    // Tangkapan HTML dibuat pada data tanpa pesanan (nomor nota berikutnya 0133).
    final raw = jsonDecode(kv.data[Keys.business]!) as Map;
    raw['orders'] = <dynamic>[];
    raw['details'] = <String, dynamic>{};
    kv.data[Keys.business] = jsonEncode(raw);
    final s = await _pump(tester, kv);
    void same(String stage) {
      final want = Map<String, dynamic>.from(fx[stage] as Map), got = s.debugAddOrder();
      // Nomor nota memuat tanggal hari tangkapan.
      if (want['sheet'] is Map && (want['sheet'] as Map)['id'] != null) {
        (want['sheet'] as Map)['id'] = '${(want['sheet'] as Map)['id']}'.replaceFirst(RegExp(r'GY-\d{6}'), 'GY-261003');
      }
      expect(jsonEncode(canon(got)), jsonEncode(canon(want)), reason: stage);
    }

    s.tile(0);
    await _settle(tester);
    same('customer');
    s.aoPickCustomer(0);
    await _settle(tester);
    s.fmScoped('dur', 'button', 0);
    await _settle(tester);
    same('services');
    s.aoService(0);
    await _settle(tester);
    s.fmScoped('qty', 'input', 0, '2,5');
    s.fmScoped('qty', 'button', 1);
    await _settle(tester);
    same('picked');
    s.aoNext();
    await _settle(tester);
    same('options');
    s.aoSheetMain();
    await _settle(tester);
    same('payment');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beranda, Pelanggan dan Pesanan: model sama dengan HTML (bundel final), sebelum dan sesudah 1 pesanan Bayar Nanti', (tester) async {
    Object? canon(Object? v) {
      if (v is Map) return {for (final k in (v.keys.map((e) => '$e').toList()..sort())) k: canon(v[k])};
      if (v is List) return [for (final x in v) canon(x)];
      return v;
    }

    String norm(Object? m) => jsonEncode(canon(m)).replaceAll(RegExp(r'GY-\d{6}'), 'GY-000000');
    final fx = jsonDecode(File('test/fixtures/pure/main_pages.json').readAsStringSync()) as Map;
    final kv = _store();
    final raw = jsonDecode(kv.data[Keys.business]!) as Map;
    raw['orders'] = <dynamic>[];
    raw['details'] = <String, dynamic>{};
    kv.data[Keys.business] = jsonEncode(raw);
    final now = DateTime(2026, 10, 3, 10);
    final s = await _pump(tester, kv);
    var b = await Business.load(kv);
    expect(norm(homeJson(b, now)), norm(fx['home0']), reason: 'Beranda kosong');
    expect(norm(customersJson(b, '', open: true)), norm(fx['customers']), reason: 'Pelanggan');
    expect(norm(ordersJson(b, tab: 1, search: '', now: now)), norm(fx['orders0']), reason: 'Pesanan kosong');

    s.tile(0);
    s.aoPickCustomer(0);
    await _settle(tester);
    s.fmScoped('dur', 'button', 0);
    s.aoService(0);
    await _settle(tester);
    s.fmScoped('qty', 'input', 0, '2,5');
    s.fmScoped('qty', 'button', 1);
    s.aoNext();
    s.aoSheetMain();
    await _settle(tester);
    s.aoPay(3); // Bayar Nanti
    await _settle(tester);
    expect(s.debugToast, 'Pesanan tersimpan · kirim nota lewat tombol WA hijau');
    b = await Business.load(kv);
    expect(norm(ordersJson(b, tab: 1, search: '', now: now)), norm(fx['orders1']), reason: 'Pesanan dengan 1 antrian');
    expect(norm(homeJson(b, now)), norm(fx['home1']), reason: 'Beranda dengan 1 pesanan');

    // Rincian Pesanan: model `od` sama dengan HTML. Beda yang disengaja: baris pelanggan memakai nomor & alamat asli
    // (HTML menampilkan contoh "0852 •••• 8626 · Cikarang"), ikon layanan dan jam tangkapan diabaikan.
    String od(Object? m) {
      final c = jsonDecode(jsonEncode(m)) as Map;
      (c['customer'] as Map)
        ..['sub'] = ''
        ..['svg'] = '';
      for (final it in c['items'] as List) {
        (it as Map)['svg'] = '';
      }
      return norm(c).replaceAll(RegExp(r'\d\d/\d\d/\d{4} · \d\d:\d\d'), 'TGL');
    }

    expect(od(s.debugDetail()), od(fx['od']), reason: 'Rincian sesudah simpan (ada kotak Pesanan tersimpan)');
    expect((s.debugDetail()!['customer'] as Map)['sub'], '0812 •••• 0001');
    for (final step in (fx['odFlow'] as List).cast<Map>()) {
      s.odButton(8);
      await _settle(tester);
      expect(s.debugToast, step['toast']);
      expect(od(s.debugDetail()), od(step['od']), reason: 'Rincian sesudah ${step['toast']}');
    }
    s.odButton(1);
    await _settle(tester);
    expect([for (final it in s.debugSheet('act115')!) '${it['type']}|${it['t']}|${it['s'] ?? ''}|${it['i']}'],
        [for (final it in (fx['act115'] as List).cast<Map>()) '${it['type']}|${it['t']}|${it['s'] ?? ''}|${it['i']}'], reason: 'menu ⋯');

    // Popup khusus (widget Hibrida): Riwayat Status & Nota WhatsApp, teks dari data Dart.
    String flat(Object? n) => n is Map
        ? (n['spans'] is List ? (n['spans'] as List).map((e) => '${(e as Map)['t']}').join() : '') + (n['ch'] is List ? (n['ch'] as List).map(flat).join('|') : '')
        : '';
    final pm = jsonDecode(File('test/fixtures/pure/popups.json').readAsStringSync()) as Map;
    s.fmScoped('act115', 'button', 2);
    await _settle(tester);
    final hist = flat((s.debugMirror('hist115')!)['box']);
    expect(hist, contains('Riwayat Status'));
    expect(hist, contains('1|Antrian|oleh '));
    expect(hist, contains('4|Diambil|oleh '));
    s.fmScoped('hist115', 'button', 0);
    s.odButton(s.debugDetail()!['banner'] == null ? 8 : 9);
    await _settle(tester);
    String nota(String t) => t
        .replaceAll(RegExp(r'GY-\d{6}'), 'GY-000000')
        .replaceAll(RegExp(r'\d\d/\d\d/\d{4} \d\d:\d\d'), 'TGL')
        .replaceAll(RegExp(r'Kasir      : .*'), 'Kasir      : -');
    expect(nota(flat((s.debugMirror('wa131')!)['box'])), nota(flat((pm['wa131'] as Map)['box'])), reason: 'teks Nota WhatsApp sama dengan HTML');
    s.fmScoped('wa131', 'button', 3);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
