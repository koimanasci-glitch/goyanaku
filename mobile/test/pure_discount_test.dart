// Mode murni: Pengaturan → Diskon mengirim butir yang sama persis dengan HTML (tangkapan test/fixtures/pure/discount.json).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/business.dart';
import 'package:goyana_flutter/core/hpp.dart';
import 'package:goyana_flutter/core/money.dart';
import 'package:goyana_flutter/core/settings.dart';
import 'package:goyana_flutter/core/stock.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/defaults.dart';
import 'package:goyana_flutter/pure/delivery.dart';
import 'package:goyana_flutter/native/cash_page.dart';
import 'package:goyana_flutter/native/cashclose_page.dart';
import 'package:goyana_flutter/pure/access.dart';
import 'package:goyana_flutter/pure/import_csv.dart';
import 'package:goyana_flutter/pure/label_page.dart';
import 'package:goyana_flutter/pure/pages.dart' show DataCenterPage, HelpCenterPage, addAudit, restoreBackup;
import 'package:goyana_flutter/pure/reminders.dart';
import 'package:goyana_flutter/pure/receipt_image.dart';
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
    // 'cols' = kisi ikon 5 kolom (revisi Koiman), selebihnya sama dengan HTML.
    expect(jsonEncode([for (final it in s.debugSheet('cat99')!) Map.of(it)..remove('cols')]), jsonEncode(fx[1]['sheet']['items']), reason: 'popup Kategori Baru');
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
const _redesigned = {'automation', 'datacenter', 'cashier', 'barcode', 'reminder', 'whatsappbot'};
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
      if (_redesigned.contains(id)) continue; // sengaja berbeda dari HTML (permintaan Koiman), diuji terpisah
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
    expect(s.debugToast, 'File tidak dapat dibaca', reason: 'Import membuka pemilih file (tidak ada di tes)');
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

  testWidgets('Data contoh bawaan: layanan (kiloan/satuan/meteran) & kategori pengeluaran terisi sekali, tidak menimpa data yang ada', (tester) async {
    final fresh = MemoryKvStore({});
    await _pump(tester, fresh);
    await _settle(tester);
    final sv = (jsonDecode(fresh.data[Keys.services]!) as List).cast<Map>();
    expect(sv.map((e) => e['unit']).toSet(), {'kg', 'pcs', 'm'});
    expect(sv.map((e) => e['name']), containsAll(['Cuci Setrika', 'Selimut', 'Bed Cover', 'Boneka', 'Jas', 'Karpet']));
    expect(sv.first['prices'], {'Reguler': 7000, 'Express': 10500, 'Kilat': 14000});
    final st = jsonDecode(fresh.data[AppSettings.key]!) as Map;
    expect(st['expenseCats'], contains('Perawatan Mesin'));
    expect((st['expenseCats'] as List).length, defaultExpenseCats.length);

    // Sudah punya layanan sendiri: tidak ditambah; kategori buatan sendiri tidak digandakan.
    final kv = _store();
    kv.data[AppSettings.key] = jsonEncode({'expenseCats': ['perawatan mesin']});
    final before = kv.data[Keys.services];
    var s = await _pump(tester, kv);
    await _settle(tester);
    expect(kv.data[Keys.services], before);
    final cats = (jsonDecode(kv.data[AppSettings.key]!) as Map)['expenseCats'] as List;
    expect(cats.where((c) => '$c'.toLowerCase() == 'perawatan mesin').length, 1);
    expect(cats.length, defaultExpenseCats.length);
    // Kategori yang dihapus pengguna tidak muncul lagi saat aplikasi dibuka ulang.
    s.nav('finance');
    await _settle(tester);
    s.fmButton(1);
    await _settle(tester);
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    s = await _pump(tester, kv);
    await _settle(tester);
    expect(((jsonDecode(kv.data[AppSettings.key]!) as Map)['expenseCats'] as List).length, defaultExpenseCats.length - 1);
    // Halaman Pengeluaran menampilkan kategori sebagai pilihan cepat.
    s.nav('cashout');
    await _settle(tester);
    expect(find.text('Listrik'), findsOneWidget);
    await tester.tap(find.text('Listrik'));
    await tester.pump();
    expect((s.debugPage('cashout') as CashEntryPage).note, 'Listrik');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kategori Pengeluaran: tambah, ubah, hapus dengan butir seperti HTML', (tester) async {
    final kv = _store();
    kv.data[AppSettings.key] = jsonEncode({'seed203': {'services': true, 'expenseCats': true}}); // tanpa kategori contoh
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
    final fx = (jsonDecode(File('test/fixtures/pure/delivery.json').readAsStringSync().replaceAll('untuk Outlet Aktif.', 'untuk $outlet.').replaceAll('+ Tambah Kurir', 'Pengaturan Kurir')) as List).cast<Map>();
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

  testWidgets('Kunci paket seperti HTML: trial Basic membuka Pegawai, membuka Stok, menolak WhatsApp/CRM/Ekspor; Mode Uji membukanya', (tester) async {
    expect(sha256Hex(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    final kv = _store();
    final s = await _pump(tester, kv);
    await _settle(tester);
    expect(jsonDecode(kv.data['goyana-trial190']!)['until'], isNotNull);
    // Keputusan 8 Okt 2026: Pegawai terbuka di Trial dan Basic.
    expect(planAccess.has('employees', s.now), isTrue);
    s.nav('employees');
    await _settle(tester);
    expect(s.debugToast, isNot('Pegawai membutuhkan paket Silver'));
    // Keputusan 10 Okt 2026: stok, opname, transfer terbuka di semua paket; Hubungkan WhatsApp mulai Silver.
    s.nav('stock');
    await _settle(tester);
    expect(s.debugState().split('|').first, 'stock');
    expect(planAccess.has('transfer', s.now), isTrue);
    expect(planAccess.has('wa', s.now), isFalse);
    s.nav('settings');
    await _settle(tester);
    s.stItem(5, 0);
    expect(s.debugToast, 'Hubungkan WhatsApp membutuhkan paket Silver');
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
    expect(planAccess.has('wa', s.now), isTrue);
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
    // Filter "Dari tanggal" benar-benar menyaring (dulu hanya nama pegawai yang dipakai).
    s.fmInput(0, '');
    s.fmButton(0);
    await _settle(tester);
    s.fmScoped('gs107', 'input', 0, '2026-10-04');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    var list = s.debugItems();
    expect(list.where((e) => e['type'] == 'entry'), isEmpty);
    expect(list.any((e) => e['t'] == 'SEJAK 04/10/2026'), isTrue);
    s.fmButton(0);
    await _settle(tester);
    s.fmScoped('gs107', 'input', 0, '2026-10-03');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    list = s.debugItems();
    expect(list.where((e) => e['type'] == 'entry').length, 2);
    // Catatan baru membawa id dan cabang (untuk dikirim ke server); riwayat dari cabang lain menampilkan nama akun & cabangnya.
    addAudit(s, '✓', 'Uji', 'catatan baru');
    final mine = (s.settings.raw['audit'] as List).first as Map;
    expect(mine['id'], startsWith('a-'));
    expect(mine['o'], s.business.activeOutlet);
    (s.settings.raw['audit'] as List).insert(0, {'ic': '✕', 't': 'Batal pesanan', 's': 'GY-9', 'at': DateTime(2026, 10, 3, 9).toIso8601String(), 'by': 'Dodi', 'o': 'srv-77'});
    s.fmButton(0);
    await _settle(tester);
    s.fmScoped('gs107', 'input', 0, '');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(s.debugItems().where((e) => e['type'] == 'entry').any((e) => (e['lines'] as List).first == 'GY-9 · Dodi'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kurir: tab Tugas sama dengan HTML; Pengaturan Kurir terkunci sampai pemilik masuk ke akun GOYANA', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/couriers.json').readAsStringSync().replaceAll('Outlet Aktif', 'Uji').replaceAll('Management Kurir', 'Pengaturan Kurir')) as Map;
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('couriers');
    await _settle(tester);
    expect(jsonEncode(s.debugItems()), jsonEncode(fx['tasks']));
    // Daftar kurir lama (email + centang outlet) sudah diganti menu Pengaturan Kurir: tiap kurir = akun di server.
    s.fmButton(1);
    await _settle(tester);
    expect(s.debugState().split('|').first, 'kurirsetting');
    final items = s.debugItems();
    expect(items.first['t'], 'Masuk ke akun GOYANA dulu');
    expect(items.where((e) => e['type'] == 'button').map((e) => e['t']), ['Masuk ke Akun GOYANA']);
    expect(items.any((e) => e['t'] == 'Cara masuk kurir'), isTrue);
    expect(items.any((e) => '${e['t']}'.contains('Tambah Kurir')), isFalse, reason: 'tanpa akun server tidak ada kurir setengah jadi');
    s.fmButton(0);
    expect(s.debugSheetIds(), isEmpty);
    // Menu Antar-Jemput menunjuk ke tempat yang sama.
    s.nav('delivery');
    await _settle(tester);
    expect(s.debugItems().any((e) => e['type'] == 'button' && e['t'] == 'Pengaturan Kurir'), isTrue);
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

  testWidgets('Stok & Bahan (rombakan Koiman): daftar bahan langsung, popup aksi per bahan, belanja hutang, riwayat', (tester) async {
    planAccess.testPlan = 'PLATINUM';
    addTearDown(() => planAccess.testPlan = null);
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('stock');
    await _settle(tester);
    List<Map> of(String type) => s.debugItems().where((e) => e['type'] == type).toList();
    List<Map> bahan() => of('card').where((e) => (e['i'] as int) >= 3000).toList();
    expect(s.debugItems()[1], containsPair('t', '+ Tambah Bahan'));
    expect([for (final o in of('buttons').first['options'] as List) (o as Map)['t']], ['Semua', 'Menipis', 'Hutang', 'Riwayat']);
    expect(bahan(), isEmpty);
    expect([for (final c in of('card')) c['t']], ['Belanja Bahan', 'Supplier', 'Kirim ke Cabang Lain', 'Pemakaian Otomatis per Layanan']);
    s.fmButton(5);
    expect(s.debugToast, 'Tambahkan bahan dulu');
    s.fmButton(0);
    await _settle(tester);
    final add = s.debugSheet('g181-modal')!;
    expect(add.first['t'], 'Tambah Bahan');
    expect([for (final it in add.where((e) => e['type'] == 'input')) it['ph']],
        ['Nama bahan (contoh: Deterjen)', 'Stok awal', 'Satuan (kg / liter / pcs)', 'Batas stok menipis (minimum)', 'Harga beli per satuan']);
    for (final (k, v) in ['Deterjen', '10', 'liter', '3', '15000'].indexed) {
      s.fmScoped('g181-modal', 'input', k, v);
    }
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(bahan().single['t'], 'Deterjen');
    expect(bahan().single['s'], 'Sisa 10 liter · batas menipis 3 liter');
    expect(bahan().single['badge'], '');
    expect((of('stats').first['cells'] as List)[2]['v'], 'Rp150.000');

    // Ketuk bahan → popup aksi; "− Dipakai" membuka lembar dengan bahan & arah sudah terpilih.
    s.fmButton(3000);
    await _settle(tester);
    final act = s.debugSheet('stockitem')!;
    expect(act.first['t'], 'Deterjen');
    expect([for (final it in act) if (it['type'] == 'button') it['t'] else if (it['type'] == 'buttons') ...[for (final o in it['options'] as List) (o as Map)['t']]],
        ['+ Stok Masuk', '− Dipakai', 'Cek Stok di Rak', 'Riwayat', 'Edit Bahan', 'Tutup']);
    s.fmScoped('stockitem', 'button', 1);
    await _settle(tester);
    expect(s.debugSheet('g181-modal')!.first['t'], 'Stok Dipakai');
    s.fmScoped('g181-modal', 'input', 2, '8');
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(bahan().single['s'], 'Sisa 2 liter · batas menipis 3 liter');
    expect(bahan().single['badge'], 'Menipis · perlu dibeli');
    s.fmButton(21); // saringan Menipis
    expect(bahan().length, 1);

    // Cek Stok di Rak (opname) dan Edit.
    s.fmButton(3000);
    s.fmScoped('stockitem', 'button', 2);
    await _settle(tester);
    expect(s.debugSheet('g181-modal')!.first['t'], 'Cek Stok di Rak');
    s.fmScoped('g181-modal', 'input', 1, '5');
    s.fmScoped('g181-modal', 'input', 2, 'salah hitung');
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(bahan().single['s'], 'Sisa 5 liter · batas menipis 3 liter');
    s.fmButton(3000);
    s.fmScoped('stockitem', 'button', 4);
    await _settle(tester);
    expect(s.debugSheet('g181-modal')!.first['t'], 'Edit Bahan');
    s.fmScoped('g181-modal', 'input', 0, 'Deterjen Cair');
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(bahan().single['t'], 'Deterjen Cair');

    // Supplier + belanja hutang.
    s.fmButton(3);
    expect(s.debugToast, 'Minimal 2 outlet');
    s.fmButton(4);
    await _settle(tester);
    s.fmScoped('g181-modal', 'input', 0, 'Toko Sabun');
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    s.fmButton(5);
    await _settle(tester);
    expect(s.debugSheet('g181-modal')!.first['t'], 'Belanja Bahan');
    s.fmScoped('g181-modal', 'input', 0, 1);
    s.fmScoped('g181-modal', 'input', 2, '2.5');
    s.fmScoped('g181-modal', 'input', 3, '16000');
    s.fmScoped('g181-modal', 'input', 4, 1);
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(bahan().single['s'], 'Sisa 7,5 liter · batas menipis 3 liter');
    s.fmButton(8);
    expect(of('entry').single['t'], 'Deterjen Cair · Sisa Rp40.000');
    s.fmButton(9);
    expect([for (final e in of('entry')) '${e['t']}|${e['amount']}'],
        ['Pembelian · Deterjen Cair|+2.5 liter', 'Cek Stok · Deterjen Cair|+3 liter', 'Dipakai · Deterjen Cair|-8 liter', 'Stok Awal · Deterjen Cair|+10 liter']);
    s.fmButton(8);
    s.fmButton(10); // Tandai Lunas
    await _settle(tester);
    expect(s.debugItems().any((e) => e['t'] == 'Tidak ada hutang supplier.'), isTrue);
    // Data tersimpan tetap memakai jenis catatan lama (dipakai laporan HPP).
    final led = (jsonDecode(kv.data['goyana-stock181']!) as Map)['ledger'] as List;
    expect([for (final x in led) (x as Map)['type']], ['Stok Awal', 'Pemakaian', 'Stock Opname', 'Pembelian']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Laporan per cabang: pemilik memilih cabang atau Semua Cabang; laba gabungan hanya Platinum', (tester) async {
    final kv = _store();
    kv.data[Keys.outlets] = jsonEncode([
      {'id': 'outlet180-5b424413-a465-4529-8c7b-ba442ad71afa', 'name': 'Uji', 'address': '', 'phone': '', 'logo': ''},
      {'id': 'srv-9', 'name': 'Bekasi', 'address': '', 'phone': '', 'logo': ''},
    ]);
    final s = await _pump(tester, kv);
    s.nav('reports');
    await _settle(tester);
    expect(find.text('Uji'), findsWidgets);
    s.rpOutlet();
    await _settle(tester);
    final sheet = s.debugSheet('rpoutlet')!;
    expect([for (final e in sheet) if (e['type'] == 'button') e['t']], ['Semua Cabang', '✓ Uji', 'Bekasi']);
    s.fmScoped('rpoutlet', 'button', 2);
    await _settle(tester);
    expect(find.text('Bekasi'), findsWidgets);
    s.rpOutlet();
    s.fmScoped('rpoutlet', 'button', 0);
    await _settle(tester);
    expect(find.text('Semua Cabang'), findsWidgets);
    s.rpKpi(1);
    expect(s.debugToast, 'Laba-rugi gabungan semua cabang membutuhkan paket Platinum');
    expect(s.debugState().split('|').first, 'reports');
    planAccess.testPlan = 'PLATINUM';
    addTearDown(() => planAccess.testPlan = null);
    s.rpKpi(1);
    await _settle(tester);
    expect(s.debugState().split('|').first, 'rp');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stok per cabang: cabang tujuan menerima kiriman, selisih wajib dicatat', (tester) async {
    final kv = _store();
    const pusat = 'srv-1', bekasi = 'outlet180-5b424413-a465-4529-8c7b-ba442ad71afa';
    kv.data[Keys.outlets] = jsonEncode([
      {'id': bekasi, 'name': 'Bekasi', 'address': '', 'phone': '', 'logo': ''},
      {'id': pusat, 'name': 'Pusat', 'address': '', 'phone': '', 'logo': ''},
    ]);
    kv.data['goyana-stock181'] = jsonEncode({
      'items': [{'id': 'det', 'name': 'Deterjen', 'unit': 'kg', 'min': 1, 'cost': 15000}],
      'ledger': [
        {'id': 'm1', 'itemId': 'det', 'outletId': pusat, 'type': 'Stok Awal', 'qty': 20},
        {'id': 'm2', 'itemId': 'det', 'outletId': pusat, 'type': 'Transfer Keluar', 'qty': -10, 'ref': 'tr-1'},
      ],
      'transfers': [{'id': 'tr-1', 'itemId': 'det', 'from': pusat, 'to': bekasi, 'qty': 10, 'status': 'sent', 'sentAt': '2026-10-03T01:00:00Z'}],
    });
    final s = await _pump(tester, kv);
    s.nav('stock');
    await _settle(tester);
    Map row() => s.debugItems().firstWhere((e) => '${e['t']}'.startsWith('Deterjen · 10'));
    expect('${(row()['lines'] as List).first}', contains('Pusat → Bekasi · Dalam perjalanan'));
    final btn = ((row()['btns'] as List).single as Map);
    expect(btn['t'], 'Terima Kiriman');
    s.fmButton(btn['i'] as int);
    await _settle(tester);
    final sheet = s.debugSheet('g181-modal')!;
    expect(sheet.first['t'], 'Terima Kiriman');
    expect(sheet.any((e) => e['t'] == 'Deterjen · dikirim 10 kg dari Pusat'), isTrue);
    expect(sheet.firstWhere((e) => e['type'] == 'input')['v'], '10');
    // Lebih dari yang dikirim ditolak; kurang wajib diberi catatan.
    s.fmScoped('g181-modal', 'input', 0, '12');
    s.fmScoped('g181-modal', 'button', 0);
    expect(s.debugToast, 'Jumlah diterima tidak boleh melebihi yang dikirim');
    s.fmScoped('g181-modal', 'input', 0, '8');
    s.fmScoped('g181-modal', 'button', 0);
    expect(s.debugToast, 'Isi catatan selisih');
    s.fmScoped('g181-modal', 'input', 1, '2 kg bocor di jalan');
    s.fmScoped('g181-modal', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, 'Kiriman diterima · selisih 2');
    expect('${(row()['lines'] as List).first}', contains('Diterima 8 dari 10 · selisih 2'));
    final saved = jsonDecode(kv.data['goyana-stock181']!) as Map;
    final t = (saved['transfers'] as List).single as Map;
    expect([t['status'], t['receivedQty'], t['receivedNote']], ['received', 8, '2 kg bocor di jalan']);
    final masuk = (saved['ledger'] as List).cast<Map>().where((x) => x['type'] == 'Transfer Masuk').single;
    expect([masuk['outletId'], masuk['qty'], masuk['ref']], [bekasi, 8, 'tr-1']);
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
    // Menu WhatsApp digabung dalam satu kategori "WhatsApp Chatbot" (grup 5).
    s.stItem(5, 4);
    await _settle(tester);
    expect(find.text('Otomasi Pelanggan terkunci'), findsOneWidget);
    s.fmScoped('lock111', 'close', 0);
    s.stItem(5, 1);
    expect(s.debugToast, 'Balasan Cepat membutuhkan paket Silver');
    planAccess.testPlan = 'PLATINUM';
    addTearDown(() => planAccess.testPlan = null);
    s.stItem(5, 1);
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
    // Tombol 'Ganti PIN' adalah tambahan Mode Murni; selebihnya sama dengan HTML.
    final got = jsonDecode(jsonEncode(s.debugItems())) as List;
    ((got.first as Map)['btns'] as List).removeWhere((b) => (b as Map)['i'] == 900);
    expect(jsonEncode(got), jsonEncode(fx['empty']));
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
    // Papan PIN seperti HTML: 1–9 (0–8), Batal (9), 0 (10), ⌫ (11); diperiksa otomatis saat lengkap.
    expect(find.text('Persetujuan Admin Utama'), findsOneWidget);
    for (var k = 0; k < 4; k++) {
      s.fmScoped('pin139', 'button', 10);
    }
    expect(s.debugToast, 'PIN salah');
    s.fmScoped('pin139', 'button', 0);
    s.fmScoped('pin139', 'button', 4);
    s.fmScoped('pin139', 'button', 11);
    for (final k in [1, 2, 3]) {
      s.fmScoped('pin139', 'button', k);
    }
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

  testWidgets('Antar Jemput (9 Okt 2026): penjemputan = pesanan Penjemputan → Tugas Kurir → timbang di lokasi → Antrian', (tester) async {
    final kv = _store();
    kv.data['goyana-couriers181'] = jsonEncode([{'id': 'k1', 'name': 'Budi', 'phone': '081233334444', 'outlets': [], 'active': true}]);
    final s = await _pump(tester, kv);
    s.nav('jemput202');
    await _settle(tester);
    expect(s.debugItems().where((e) => e['type'] == 'pickup'), isEmpty);
    s.fmButton(0);
    await _settle(tester);
    // Halaman: Pilih Pelanggan, Tambah Pelanggan Baru, lalu daftar pelanggan terdaftar.
    expect([for (final it in s.debugItems()) if (it['type'] == 'title' || it['type'] == 'button') it['t']],
        ['Pelanggan', 'Pilih Pelanggan', '+ Tambah Pelanggan Baru', 'Pelanggan terdaftar']);
    expect(s.debugItems().where((e) => e['type'] == 'card').map((e) => e['t']), contains('Budi Native'));
    // Tambah pelanggan baru → kembali dan langsung muncul popup Jadwal Penjemputan.
    s.fmButton(11);
    await _settle(tester);
    s.fmScoped('gp128', 'button', 1);
    s.fmInput(0, 'Sari');
    s.fmInput(1, '081277776666');
    s.fmButton(7);
    await _settle(tester);
    expect(s.debugSheetIds(), contains('jjadwal'));
    expect(s.debugSheet('jjadwal')!.first['s'], 'Sari');
    s.fmScoped('jjadwal', 'button', 22); // Besok → Secepatnya tidak berlaku, jam otomatis Pagi
    await _settle(tester);
    s.fmScoped('jjadwal', 'button', 1); // Lanjut Pilih Kurir
    await _settle(tester);
    // Pilih Kurir: Saya sendiri + daftar kurir; memilih kurir langsung membuat penjemputan.
    expect([for (final e in s.debugSheet('jkurir')!) if (e['type'] == 'card') e['t']], ['Saya sendiri', 'Budi']);
    s.fmScoped('jkurir', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, startsWith('Penjemputan dibuat'));
    var b = await Business.load(kv);
    final o = b.orders.firstWhere((e) => e.name == 'Sari');
    expect(o.status, 'jemput');
    expect(o.items, isEmpty);
    expect(o.dataset['courier181'], 'k1');
    expect(o.dataset['jemputDate'], '2026-10-04');
    expect(o.dataset['jemputSlot'], 'pagi');
    // Pelanggan terdaftar dari daftar: Pilih → Jadwal → Kurir (Saya sendiri).
    s.nav('jemputnew202');
    await _settle(tester);
    final idx = s.debugItems().where((e) => e['type'] == 'card').firstWhere((e) => e['t'] == 'Budi Native')['i'] as int;
    s.fmButton(idx);
    await _settle(tester);
    expect(s.debugSheetIds(), contains('jjadwal'));
    s.fmScoped('jjadwal', 'button', 1);
    await _settle(tester);
    s.fmScoped('jkurir', 'button', 1000);
    await _settle(tester);
    expect((await Business.load(kv)).orders.where((e) => e.name == 'Budi Native' && e.status == 'jemput' && e.dataset['jemputSelf'] != null).length, 1);
    final cardItem = s.debugItems().firstWhere((e) => e['type'] == 'pickup' && e['t'] == 'Sari');
    expect([cardItem['t'], cardItem['when'], cardItem['who'], cardItem['badge']], ['Sari', 'Besok, Pagi 08.00–11.00', 'Kurir: Budi', 'Ditugaskan']);
    expect([for (final x in cardItem['btns'] as List) (x as Map)['t']], ['Navigasi', 'Buat Pesanan', 'WhatsApp']);
    // Tab Penjemputan di Pesanan: tombol kartu "Buat Pesanan", tidak langsung masuk Antrian dengan Rp0.
    s.nav('orders');
    await _settle(tester);
    b = await Business.load(kv);
    s.cardAction(b.orders.indexWhere((e) => e.id == o.id));
    await _settle(tester);
    expect(s.debugSheetIds(), contains('dur'), reason: 'membuka Buat Pesanan (Pilih Durasi)');
    expect((await Business.load(kv)).orderById(o.id)!.status, 'jemput');
    s.aoBack();
    await _settle(tester);
    // Ikut tampil di Tugas Kurir.
    s.nav('couriers');
    await _settle(tester);
    expect(s.debugItems().any((e) => e['type'] == 'title' && '${e['t']}'.contains('Penjemputan · Sari')), isTrue);
    // ⋮ → Ganti Kurir → Saya sendiri.
    s.nav('jemput202');
    await _settle(tester);
    Map sari() => s.debugItems().firstWhere((e) => e['type'] == 'pickup' && e['t'] == 'Sari');
    s.fmButton(sari()['menu'] as int);
    await _settle(tester);
    expect([for (final e in s.debugSheet('jmenu')!) if (e['type'] == 'button') e['t']], ['Ganti Kurir', 'Buka Rincian Pesanan', 'Batalkan Penjemputan', 'Tutup']);
    s.fmScoped('jmenu', 'button', 1);
    await _settle(tester);
    s.fmScoped('jkurir', 'button', 1000);
    await _settle(tester);
    expect(sari()['who'], 'Dijemput: Owner');
    // Buat Pesanan: Tambah Transaksi yang sama (durasi → layanan → Atur Pesanan → Pembayaran), tanpa pilihan Penyerahan.
    s.fmButton(((sari()['btns'] as List)[1] as Map)['i'] as int);
    await _settle(tester);
    expect(s.debugSheetIds(), contains('dur'));
    s.fmScoped('dur', 'button', 1); // Express
    await _settle(tester);
    s.aoService(0);
    await _settle(tester);
    s.fmScoped('qty', 'input', 0, '3');
    s.fmScoped('qty', 'button', 1);
    s.aoNext();
    await _settle(tester);
    final fields = ((s.debugAddOrder()['sheet'] as Map)['fields'] as List).map((f) => (f as Map)['label']).toList();
    expect(fields, isNot(contains('Penyerahan')));
    s.aoSheetMain();
    await _settle(tester);
    expect((s.debugAddOrder()['sheet'] as Map)['id'], o.id, reason: 'nomor nota tetap');
    s.aoPay(3); // Bayar Nanti
    await _settle(tester);
    expect(s.debugToast, startsWith('Pesanan masuk Antrian'));
    b = await Business.load(kv);
    expect(b.orders.where((e) => e.name == 'Sari').length, 1, reason: 'tidak membuat pesanan kedua');
    final done = b.orderById(o.id)!;
    expect(done.status, 'antrian');
    expect(done.dur, 'Express');
    expect(done.items.single.qty, 3);
    expect(done.handover, 'Jemput & Antar');
    expect(done.dataset['picked'], '1');
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
      if (s.debugHanding) {
        // Revisi Koiman: serah terima pesanan belum lunas menanyakan pembayaran dulu → "Hutang Dulu".
        s.aoPayCancel();
        await _settle(tester);
        expect(s.debugToast, startsWith('Hutang dulu'));
      } else {
        expect(s.debugToast, step['toast']);
      }
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
    // Revisi Koiman: Kirim WA menanyakan dulu Nota Gambar / Nota Teks.
    expect([for (final it in s.debugSheet('wakind')!.where((e) => e['type'] == 'card')) it['t']], ['Nota Gambar', 'Nota Teks']);
    s.fmScoped('wakind', 'button', 1);
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

  testWidgets('Struk gambar (rc106): Code128 seperti HTML, PNG tergambar', (tester) async {
    expect(code128Pattern('GY'), startsWith('211214'), reason: 'mulai set B (104)');
    expect(code128Pattern('GY').length, 6 + 2 * 6 + 6 + 7);
    final b = await Business.load(_store());
    final d = ReceiptData.of(b.orders.first, outlet: 'Uji', address: 'Jakarta', wa: '081234567890', phone: '081200000001');
    expect(d.status, 'BELUM LUNAS');
    expect(d.items.single[1], contains('kg'));
    final png = await tester.runAsync(() => receiptPng(d));
    expect(png!.sublist(1, 4), [0x50, 0x4e, 0x47]);
    expect(png.length, greaterThan(5000));
  });

  testWidgets('Cetak Label Cucian (printlabel): susunan halaman & popup Cek Kantong sama dengan HTML', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/label.json').readAsStringSync()) as Map;
    final s = await _pump(tester, _store());
    s.nav('printlabel');
    await _settle(tester);
    List<String> shape(List items) => [
          for (final it in items.cast<Map>())
            if (it['type'] == 'card') 'card' else if (it['type'] == 'labelprev') 'labelprev' else if (it['type'] == 'stepper') 'stepper|${it['t']}|${it['s']}|${it['minus']}|${it['plus']}'
            else if (it['type'] == 'buttons') 'buttons|${(it['options'] as List).map((o) => '${(o as Map)['t']}:${o['i']}:${o['on']}').join(',')}'
            else '${it['type']}|${it['t'] ?? ''}|${it['s'] ?? ''}|${it['ph'] ?? ''}',
        ];
    expect(shape(s.debugItems()), shape((fx['page'] as Map)['items'] as List));
    s.fmButton(3);
    await _settle(tester);
    expect(shape(s.debugItems()), shape((fx['two'] as Map)['items'] as List));
    s.fmButton(7);
    await _settle(tester);
    final want = (fx['bg137'] as List).cast<Map>();
    final got = s.debugSheet('bg137')!;
    expect(got.first['t'], want.first['t']);
    expect('${got[1]['t']}'.split(' · ').last, '0/2 kantong terscan');
    expect([for (final it in got.where((e) => e['type'] == 'input' || e['type'] == 'button')) '${it['type']}|${it['t'] ?? it['ph']}|${it['i']}'],
        [for (final it in want.where((e) => e['type'] == 'input' || e['type'] == 'button')) '${it['type']}|${it['t'] ?? it['ph']}|${it['i']}']);
    s.fmScoped('bg137', 'button', 11);
    s.fmScoped('bg137', 'input', 0, '${(await Business.load(_store())).orders.first.id}/2');
    expect(s.debugToast, startsWith('Lengkap ✓ · 2/2 kantong'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kurir · Tugas: kartu tugas sama dengan HTML (pilih kurir, Navigasi, WhatsApp, tahap berikut)', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/courier_task.json').readAsStringSync().replaceAll('Management Kurir', 'Pengaturan Kurir')) as Map;
    final kv = _store();
    final raw = jsonDecode(kv.data[Keys.business]!) as Map;
    (((raw['orders'] as List).first as Map)['dataset'] as Map)
      ..['st'] = 'jemput'
      ..['antar'] = '1';
    kv.data[Keys.business] = jsonEncode(raw);
    var s = await _pump(tester, kv);
    s.nav('couriers');
    await _settle(tester);
    List<String> shape(List items) => [
          for (final it in items.cast<Map>())
            it['type'] == 'buttons'
                ? 'buttons|${(it['options'] as List).map((o) => (o as Map)['t']).join(',')}'
                : it['type'] == 'select'
                    ? 'select|${(it['options'] as List).join(',')}'
                    : '${it['type']}|${'${it['t']}'.replaceAll(RegExp(r'GY-\d{6}-\d{4}'), 'ID')}',
        ];
    expect(shape(s.debugItems()), shape(fx['items'] as List));
    s.fmButton(1003);
    expect(s.debugToast, 'Pilih kurir dulu');
    s.fmButton(1000);
    expect(s.debugToast, 'Lokasi belum tersedia');

    kv.data['goyana-couriers181'] = jsonEncode([{'id': 'k1', 'name': 'Andi', 'phone': '081233334444', 'outlets': [], 'active': true}]);
    s = await _pump(tester, kv);
    s.nav('couriers');
    await _settle(tester);
    s.fmInput(0, 1);
    await _settle(tester);
    s.fmButton(1003);
    await _settle(tester);
    expect(s.debugToast, 'Sudah dijemput · masuk Antrian');
    final o = (await Business.load(kv)).orders.first;
    expect(o.status, 'antrian');
    expect(o.history.last['by'], 'Andi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('HPP v182: resep → pemakaian bahan otomatis saat pesanan diproduksi; pembelian lunas masuk kas', (tester) async {
    final kv = _store();
    final first = (await Business.load(kv)).orders.first;
    final item = first.items.first;
    kv.data[StockBook.key] = jsonEncode({
      'items': [{'id': 'b1', 'name': 'Deterjen', 'unit': 'ml', 'min': 0, 'cost': 20}],
      'ledger': [{'id': 'm0', 'itemId': 'b1', 'outletId': first.outlet, 'type': 'Stok Awal', 'qty': 1000, 'at': '2026-10-01T00:00:00.000Z'}],
      'suppliers': [], 'recipes': [{'id': 'r1', 'service': item.name, 'itemId': 'b1', 'qty': 30}],
      'purchases': [{'id': 'p1', 'itemId': 'b1', 'qty': 10, 'total': 5000, 'paid': 5000, 'at': '2026-10-02T03:00:00.000Z'}],
    });
    // Pesanan contoh sudah lewat 1 jam di Antrian → otomatis Proses → bahan terpakai.
    final s = await _pump(tester, kv);
    await _settle(tester);
    await _settle(tester);
    final stock = await StockBook.load(kv);
    final use = (stock.raw['ledger'] as List).cast<Map>().where((x) => x['type'] == 'Pemakaian Otomatis').single;
    expect(use['qty'], -30 * item.qty);
    expect(use['orderId'], first.id);
    final b = await Business.load(kv);
    expect(b.orders.first.dataset['hpp182'], '1');
    expect(hppTotal(stock, DateTime(2026, 10, 3), DateTime(2026, 10, 4)), 30 * item.qty * 20);
    final outs = (b.kas['outs'] as List).cast<Map>().where((x) => x['purchase182'] == 'p1').toList();
    expect(outs.single['t'], 'Bahan Baku · Deterjen');
    expect(outs.single['a'], 5000);
    // Dibuka ulang: tidak dicatat dua kali.
    await _pump(tester, kv);
    await _settle(tester);
    expect(((await StockBook.load(kv)).raw['ledger'] as List).where((x) => (x as Map)['type'] == 'Pemakaian Otomatis').length, 1);
    expect(s.debugToast, isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('Restore cadangan: menolak file asing, menimpa data utama & kunci tambahan', () async {
    final src = _store();
    final b = await Business.load(src);
    final kv = MemoryKvStore({});
    expect(await restoreBackup(kv, {'app': 'LAIN'}), 'File ini bukan cadangan GOYANA');
    expect(await restoreBackup(kv, {
      'app': 'GOYANA', 'version': 2, 'business': b.raw, 'services': b.services.map((e) => e.raw).toList(), 'outlets': b.outlets.map((e) => e.raw).toList(),
      'settings': {'x': 1}, 'perfumes': [], 'kv': {'goyana-couriers181': '[{"id":"k1"}]', 'kunci-asing': 'x'},
    }), isNull);
    final r = await Business.load(kv);
    expect(r.orders.length, b.orders.length);
    expect(r.customers.single.name, 'Budi Native');
    expect(r.outlets.single.name, b.outlets.single.name);
    expect(kv.data['goyana-couriers181'], '[{"id":"k1"}]');
    expect(kv.data.containsKey('kunci-asing'), isFalse);
  });

  testWidgets('Chatbot AI: Uji Jawaban dari data aplikasi (status pesanan per nomor, daftar harga)', (tester) async {
    planAccess.testPlan = 'PLATINUM';
    final s = await _pump(tester, _store());
    s.nav('ai191');
    await _settle(tester);
    String last() => '${s.debugItems().last['t']}';
    s.fmInput(5, 'cek status cucian saya');
    s.fmButton(2);
    if (last() == 'Chatbot AI belum diaktifkan.') {
      s.fmToggle(0);
      s.fmButton(2);
    }
    expect(last(), anyOf('Nomor WhatsApp pelanggan diperlukan untuk memeriksa pesanan.', startsWith('Pertanyaan ini membutuhkan koneksi AI')));
    s.fmInput(4, '0812-0000-0001');
    s.fmButton(2);
    expect(last(), anyOf(contains('GY-'), startsWith('Pertanyaan ini membutuhkan koneksi AI')));
    s.fmInput(5, 'halo');
    s.fmButton(2);
    expect(last(), startsWith('Pertanyaan ini membutuhkan koneksi AI'));
    planAccess.testPlan = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('Serah terima belum lunas: popup Pembayaran dengan Hutang Dulu; hutang masuk Belum Bayar; bayar → selesai', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    var b = await Business.load(kv);
    final id = b.orders.first.id;
    expect(b.orders.first.remaining, greaterThan(0));
    s.openOrder(id);
    await _settle(tester);
    // Maju sampai Siap Ambil: belum ada pertanyaan pembayaran.
    for (var k = 0; k < 8 && (await Business.load(kv)).orders.first.status != 'siap'; k++) {
      s.fmScoped('detail', 'button', 1);
      await _settle(tester);
      expect(s.debugHanding, isFalse);
    }
    expect((await Business.load(kv)).orders.first.status, 'siap');
    s.fmScoped('detail', 'button', 1);
    await _settle(tester);
    expect(s.debugHanding, isTrue, reason: 'Pembayaran muncul dulu');
    expect(find.text('HUTANG DULU'), findsOneWidget);
    expect((await Business.load(kv)).orders.first.status, 'siap', reason: 'status belum berubah');
    // Tombol Tutup terlihat: popup ditutup, status tetap (belum diambil).
    expect(find.text('TUTUP'), findsOneWidget);
    await tester.ensureVisible(find.text('TUTUP'));
    await tester.tap(find.text('TUTUP'));
    await _settle(tester);
    expect(s.debugHanding, isFalse);
    expect(find.text('HUTANG DULU'), findsNothing);
    expect((await Business.load(kv)).orders.first.status, 'siap', reason: 'menutup popup = batal serah terima');
    s.fmScoped('detail', 'button', 1);
    await _settle(tester);
    s.aoPayCancel();
    await _settle(tester);
    b = await Business.load(kv);
    expect(b.orders.first.status, anyOf('diambil', 'diantar'));
    expect(b.orders.first.isPaid, isFalse);
    expect(b.orders.first.dataset['hutang203'], '1');
    s.nav('orders');
    s.tab(8);
    await _settle(tester);
    expect((s.debugOrders()['cards'] as List).any((c) => '${(c as Map)['id']}' == id), isTrue, reason: 'tampil di Belum Bayar');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Import Data CSV: pratinjau (baru/duplikat/tidak lengkap) lalu simpan pelanggan, layanan dan transaksi lama', (tester) async {
    expect(parseCsv('a;b\n"x;1";"dia ""bilang"""\n\n'), [['a', 'b'], ['x;1', 'dia "bilang"']]);
    expect(importDate('31/12/2025 14.30'), DateTime(2025, 12, 31, 14, 30));
    expect(importDate('2025-12-31'), DateTime(2025, 12, 31, 12));
    expect(importPhone('+62 812-3456-7890'), '081234567890');
    final kv = _store();
    final s = await _pump(tester, kv);
    var b = await Business.load(kv);
    final have = b.customers.first.name, nCust = b.customers.length, nOrd = b.orders.length, nSvc = b.services.length;
    s.nav('datacenter');
    await _settle(tester);
    expect(s.debugItems().any((e) => e['t'] == 'Unduh Contoh File'), isTrue);
    final page = s.debugPage('datacenter') as DataCenterPage;
    List<Map> sheet() => s.debugSheet('import203')!;

    page.previewImport(0, 'Kode,Nama\n1,Sari\n');
    await _settle(tester);
    expect('${sheet()[1]['t']}', startsWith('Kolom wajib tidak ditemukan: No HP'));
    s.fmScoped('import203', 'button', 1);

    page.previewImport(0, 'Nama Pelanggan;No. HP;Alamat;JK\nSari Dewi;+62 812-9999-0000;Bekasi;P\n$have;0811111111;;L\nTanpa Nomor;;;\nSari Dewi;0812;;\n');
    await _settle(tester);
    expect([for (final c in sheet()[1]['cells'] as List) (c as Map)['v']], ['1', '1', '2']);
    expect('${sheet()[3]['t']}', contains('No HP ← kolom "No. HP"'));
    s.fmScoped('import203', 'button', 0);
    await _settle(tester);
    b = await Business.load(kv);
    expect(b.customers.length, nCust + 1);
    expect(b.customerByName('Sari Dewi')!.phone, '081299990000');
    expect(b.customerByName('Sari Dewi')!.gender, 'female');

    page.previewImport(1, importTemplates[1]);
    await _settle(tester);
    s.fmScoped('import203', 'button', 0);
    await _settle(tester);
    b = await Business.load(kv);
    expect(b.services.length, greaterThan(nSvc));
    expect(b.services.firstWhere((x) => x.name == 'Bed Cover').prices, {'Reguler': 25000, 'Express': 37500, 'Kilat': 50000});

    final kasBefore = jsonEncode(b.kas['sales'] ?? []);
    page.previewImport(2, importTemplates[2]);
    await _settle(tester);
    expect([for (final c in sheet()[1]['cells'] as List) (c as Map)['v']], ['2', '0', '0']);
    s.fmScoped('import203', 'button', 0);
    await _settle(tester);
    b = await Business.load(kv);
    expect(b.orders.length, nOrd + 2);
    final imp = b.orders.where((o) => o.dataset['import203'] == '1').toList();
    expect(imp.map((o) => o.status).toSet(), {'diambil'});
    final budi = imp.firstWhere((o) => o.name == 'Budi Santoso');
    expect(budi.total, 24500);
    expect(budi.isPaid, isTrue);
    expect(budi.created, DateTime(2026, 9, 1, 12));
    expect(imp.firstWhere((o) => o.name == 'Siti Aminah').isPaid, isFalse);
    expect(jsonEncode(b.kas['sales'] ?? []), kasBefore, reason: 'transaksi lama tidak masuk kas shift berjalan');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keyboard tetap terbuka di HP berbilah gestur (jarak aman bawah tidak membuat ulang halaman)', (tester) async {
    final s = await _pump(tester, _store());
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    s.nav('customers');
    s.cuAdd();
    await _settle(tester);
    s.fmScoped('gp128', 'button', 0);
    await _settle(tester);
    await tester.tap(find.byType(EditableText).first);
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);
    final field = tester.state(find.byType(EditableText).first);
    // Android: saat keyboard muncul, jarak aman bawah menjadi 0 dan viewInsets terisi.
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.state(find.byType(EditableText).first), same(field), reason: 'kolom isian tidak dibuat ulang');
    expect(tester.testTextInput.hasAnyClients, isTrue, reason: 'keyboard tidak tertutup');
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
    await tester.enterText(find.byType(EditableText).first, 'Sari');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Izin kasir sungguh membatasi: batal pesanan, kurangi kas, saldo, laporan; pemilik (PIN Admin) bebas', (tester) async {
    final kv = _store();
    kv.data[AppSettings.key] = jsonEncode({
      'seed203': {'services': true, 'expenseCats': true}, 'pinLock': true, 'adminPin': '9911',
      'employees': [{'name': 'Rina', 'phone': '0812', 'pin': '4321'}],
      'tpl': {'cashier': {'tg': {'0': false, '3': false, '4': false, '8': false}}},
    });
    var s = await _pump(tester, kv);
    expect(find.text('Masukkan PIN'), findsOneWidget);
    s.fmScoped('pin', 'input', 0, '4321');
    s.fmScoped('pin', 'button', 1);
    await _settle(tester);
    expect(s.debugToast, 'Halo, Rina');
    expect(s.kasirCan(3), isFalse);
    expect(s.kasirCan(6), isFalse, reason: 'bawaan: kasir tidak boleh mengurangi kas tunai');
    expect(s.kasirCan(1), isTrue);
    // Batalkan pesanan ditolak.
    final id = (await Business.load(kv)).orders.first.id;
    s.openOrder(id);
    await _settle(tester);
    s.fmScoped('detail', 'button', 3);
    expect(s.debugToast, 'Kasir tidak diizinkan membatalkan pesanan · hubungi pemilik');
    expect(s.debugSheet('cancel'), isNull);
    // Pengeluaran tunai ditolak, saldo disembunyikan.
    s.nav('cashout');
    await _settle(tester);
    final cash = s.debugPage('cashout') as CashEntryPage;
    expect(((cash.model()['stats'] as List).first as Map)['v'], 'Rp •••');
    cash
      ..type = 'Tunai'
      ..amount = '5000'
      ..submit();
    expect(s.debugToast, 'Kasir tidak diizinkan mengurangi kas tunai · hubungi pemilik');
    expect(((await Business.load(kv)).kas['outs'] as List), isEmpty);
    // Halaman izin & pegawai hanya untuk pemilik.
    s.nav('cashier');
    expect(s.debugToast, 'Hanya pemilik · buka aplikasi dengan PIN Admin');

    // Pemilik masuk dengan PIN Admin: semua bebas.
    s = await _pump(tester, kv);
    s.fmScoped('pin', 'input', 0, '9911');
    s.fmScoped('pin', 'button', 1);
    await _settle(tester);
    expect(s.debugToast, 'Halo, Pemilik');
    expect(s.kasirCan(3), isTrue);
    s.nav('cashier');
    await _settle(tester);
    expect(s.debugItems().where((e) => e['type'] == 'toggle').length, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Barcode & Label: sakelar isi label dan barcode struk benar-benar dipakai; angka ringkasan dari data', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('barcode');
    await _settle(tester);
    final cells = s.debugItems().first['cells'] as List;
    expect([(cells[0] as Map)['v'], (cells[1] as Map)['v']], ['0', '0'], reason: 'bukan angka contoh 128 / 6');
    expect([for (final t in s.debugItems().where((e) => e['type'] == 'toggle')) t['i']], [0, 2, 5, 6, 7, 8, 9, 10]);
    final label = s.debugPage('printlabel') as LabelPage;
    final o = (await Business.load(kv)).orders.first;
    expect(label.labelHtml(o), contains(o.name));
    expect(label.labelHtml(o), contains('BELUM BAYAR'));
    expect(label.labelHtml(o), isNot(contains('Rp')));
    final st = AppSettings.key;
    kv.data[st] = jsonEncode((jsonDecode(kv.data[st]!) as Map)..['tpl'] = {'barcode': {'tg': {'5': false, '9': true, '10': false, '2': false}}});
    final s2 = await _pump(tester, kv);
    await _settle(tester);
    final label2 = s2.debugPage('printlabel') as LabelPage;
    final html = label2.labelHtml(o);
    expect(html, isNot(contains('<b>${o.name}</b>')));
    expect(html, contains('Rp'));
    expect(html, isNot(contains('BELUM BAYAR')));
    final d = ReceiptData.of(o, outlet: 'Uji', barcode: false);
    final plain = await tester.runAsync(() => receiptPng(d));
    final withBar = await tester.runAsync(() => receiptPng(ReceiptData.of(o, outlet: 'Uji')));
    expect(plain!.length, lessThan(withBar!.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reminder Pekerjaan: aturan → pengingat (deadline 2 jam, terlambat, stok menipis, belum bayar) dan selisih jadwal', (tester) async {
    final kv = _store();
    final b = await Business.load(kv);
    final o = b.orders.first;
    final due = o.due!.toLocal();
    kv.data[StockBook.key] = jsonEncode({
      'items': [{'id': 'b1', 'name': 'Deterjen', 'unit': 'liter', 'min': 5, 'cost': 1000}],
      'ledger': [{'id': 'm0', 'itemId': 'b1', 'outletId': o.outlet, 'type': 'Stok Awal', 'qty': 3, 'at': '2026-10-01T00:00:00.000Z'}],
    });
    final stock = await StockBook.load(kv);
    List<Reminder> at(DateTime now, {Set<int> off = const {}}) => buildReminders(b: b, stock: stock, on: (i) => !off.contains(i), now: now);

    // Jauh sebelum deadline: dijadwalkan 2 jam sebelum & tepat saat deadline; stok menipis langsung; belum bayar pukul 09.00.
    final early = at(due.subtract(const Duration(hours: 10)));
    final d0 = early.firstWhere((r) => r.kind == 'due');
    expect(d0.at, due.subtract(const Duration(hours: 2)));
    expect(d0.immediate, isFalse);
    expect(early.firstWhere((r) => r.kind == 'late').at, due);
    expect(early.firstWhere((r) => r.kind == 'stock').body, 'Deterjen (sisa 3 liter)');
    final unpaid = early.firstWhere((r) => r.kind == 'unpaid');
    expect(unpaid.at.hour, 9);
    expect(unpaid.body, startsWith('1 pesanan · total Rp'));
    // Satu jam sebelum deadline: pengingat deadline langsung tampil.
    expect(at(due.subtract(const Duration(hours: 1))).firstWhere((r) => r.kind == 'due').immediate, isTrue);
    // Lewat deadline: hanya "terlambat" (langsung).
    final late = at(due.add(const Duration(hours: 1)));
    expect(late.where((r) => r.kind == 'due'), isEmpty);
    expect(late.firstWhere((r) => r.kind == 'late').immediate, isTrue);
    // Sakelar mati = aturan tidak menghasilkan pengingat.
    expect(at(due.add(const Duration(hours: 1)), off: {1, 2, 3}), isEmpty);

    // Selisih jadwal: yang sama tidak dijadwalkan ulang; yang hilang dibatalkan.
    final (c1, a1, m1) = diffReminders(const {}, early);
    expect(c1, isEmpty);
    expect(a1.length, early.length);
    final (c2, a2, _) = diffReminders(m1, early);
    expect([c2, a2], [isEmpty, isEmpty]);
    final (c3, a3, _) = diffReminders(m1, at(due.subtract(const Duration(hours: 10)), off: {2}));
    expect(c3, [3000001]);
    expect(a3, isEmpty);

    // Halaman Reminder menampilkan pengingat yang sedang berlaku dan membukanya.
    final s = await _pump(tester, kv);
    s.nav('reminder');
    await _settle(tester);
    expect(s.debugItems().where((e) => e['type'] == 'toggle').length, 4);
    final cards = s.debugItems().where((e) => e['type'] == 'card').toList();
    expect(cards.map((e) => e['t']), containsAll(['Stok bahan menipis', 'Pesanan belum dibayar']));
    s.fmToggle(2);
    await _settle(tester);
    expect(s.debugItems().where((e) => e['type'] == 'card').map((e) => e['t']), isNot(contains('Stok bahan menipis')));
    expect(HelpCenterPage.supportWa, '6285280218627');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hapus pelanggan: ditolak bila masih ada tagihan, berhasil setelah lunas; riwayat pesanan tetap; waNumber', (tester) async {
    expect([waNumber('0812-3456 789'), waNumber('+62 812 3456789'), waNumber('8123456789'), waNumber('')], ['628123456789', '628123456789', '628123456789', '']);
    final kv = _store();
    final s = await _pump(tester, kv);
    var b = await Business.load(kv);
    final name = b.customers.first.name, orders = b.orders.length;
    s.nav('customers');
    s.cuEdit(0);
    await _settle(tester);
    expect(s.debugItems().any((e) => e['t'] == 'Hapus Pelanggan'), isTrue);
    s.fmButton(9);
    await _settle(tester);
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(s.debugToast, 'Masih ada 1 pesanan belum lunas');
    expect((await Business.load(kv)).customerByName(name), isNotNull);
    b = await Business.load(kv);
    b.pay(b.orders.first, method: 'Tunai', amount: b.orders.first.remaining, now: DateTime(2026, 10, 3, 10));
    await b.save();
    final s2 = await _pump(tester, kv);
    s2.nav('customers');
    s2.cuEdit(0);
    await _settle(tester);
    s2.fmButton(9);
    await _settle(tester);
    s2.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(s2.debugToast, 'Pelanggan $name dihapus');
    b = await Business.load(kv);
    expect(b.customerByName(name), isNull);
    expect(b.orders.length, orders, reason: 'riwayat pesanan tetap');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Otomasi Pelanggan: tiap pesan otomatis bisa dinyalakan/dimatikan, hari pengingat bisa dipilih', (tester) async {
    planAccess.testPlan = 'PLATINUM';
    final s = await _pump(tester, _store());
    s.nav('automation');
    await _settle(tester);
    List<Map> tg() => s.debugItems().where((e) => e['type'] == 'toggle').toList();
    expect([for (final t in tg()) t['t']], ['Pesanan diterima', 'Pesanan siap diambil', 'Belum diambil 2 hari', 'Balas Status WhatsApp']);
    expect([for (final t in tg()) t['on']], [true, true, true, false]);
    s.fmToggle(0);
    s.fmInput(0, 3);
    expect(tg()[0]['on'], false);
    expect(tg()[2]['t'], 'Belum diambil 5 hari');
    s.fmToggle(2);
    expect(s.debugItems().any((e) => e['type'] == 'select'), isFalse);
    s.nav('settings');
    s.nav('automation');
    await _settle(tester);
    expect([for (final t in tg()) t['on']], [false, true, false, false]);
    planAccess.testPlan = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tambah Pelanggan (customeradd): popup pria/wanita lalu susunan halaman sama dengan HTML; lokasi Maps tersimpan', (tester) async {
    final fx = jsonDecode(File('test/fixtures/pure/customeradd.json').readAsStringSync()) as Map;
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('customers');
    s.cuAdd();
    await _settle(tester);
    List<String> shape(List items) => [
          for (final it in items.cast<Map>())
            it['type'] == 'buttons' ? 'buttons|${(it['options'] as List).map((o) => '${(o as Map)['t']}:${o['i']}').join(',')}' : '${it['type']}|${it['t'] ?? ''}|${it['s'] ?? ''}|${it['ph'] ?? ''}|${it['btn'] ?? ''}|${it['i'] ?? 0}',
        ];
    expect(shape(s.debugSheet('gp128')!), shape(fx['gp128'] as List), reason: 'popup jenis kelamin');
    s.fmScoped('gp128', 'button', 0);
    await _settle(tester);
    // Revisi Koiman: tombol lokasi cukup "Lokasi saya" & "Tempel link"; titik ditandai di peta dalam aplikasi.
    final want = shape((fx['page'] as Map)['items'] as List).map((e) => e.replaceFirst('Pilih Titik di Peta:4,', '')).toList();
    expect(shape(s.debugItems()), want, reason: 'halaman');
    s.fmButton(5); // GPS tidak tersedia di tes → peta tetap terbuka untuk digeser
    await _settle(tester);
    expect(find.text('Tandai Lokasi Ini'), findsOneWidget);
    await tester.tap(find.text('Tandai Lokasi Ini'));
    await _settle(tester);
    expect(s.debugItems().firstWhere((e) => e['type'] == 'input' && e['i'] == 3)['v'], '-6.200000, 106.816666');
    expect(s.debugItems().any((e) => e['t'] == 'Cek di Peta'), isTrue);
    s.fmButton(8);
    await _settle(tester);
    expect(find.text('TANDAI LOKASI'), findsOneWidget);
    s.closePageSheet('map203');
    await _settle(tester);
    s.fmInput(0, 'Sari');
    s.fmButton(7);
    expect(s.debugToast, isNot('Pelanggan Sari ditambahkan'), reason: 'no HP wajib');
    s.fmInput(1, '081299990000');
    s.fmInput(3, 'bukan link');
    s.fmButton(7);
    expect(s.debugToast, 'Link Maps tidak dikenali · kosongkan atau perbaiki dulu');
    s.fmInput(3, 'https://maps.app.goo.gl/abc');
    s.fmButton(7);
    await _settle(tester);
    expect((await Business.load(kv)).customerByName('Sari')!.maps, 'https://maps.app.goo.gl/abc');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Harga Paket: grid kartu paket, rincian fitur saat kartu diketuk, tanpa luapan tata letak', (tester) async {
    final s = await _pump(tester, _store());
    s.nav('upgrade');
    await _settle(tester);
    expect(find.text('HARGA PAKET'), findsOneWidget);
    expect(find.text('Pilih Paket'), findsOneWidget);
    for (final p in ['FREE', 'BASIC', 'SILVER', 'GOLD']) {
      expect(find.text(p), findsWidgets, reason: p);
    }
    expect(find.text('Paket Aktif'), findsOneWidget, reason: 'FREE (trial) sedang aktif');
    expect(tester.takeException(), isNull);
    await tester.drag(find.text('Pilih Paket'), const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('SILVER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Paket SILVER'), findsOneWidget);
    expect(find.text('Stok bahan, opname dan HPP'), findsOneWidget);
    await tester.tap(find.text('Pilih Paket Ini'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.debugToast, 'Pembayaran paket belum tersedia di versi ini · paket SILVER belum diaktifkan');
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
