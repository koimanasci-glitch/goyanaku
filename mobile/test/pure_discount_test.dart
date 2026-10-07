// Mode murni: Pengaturan → Diskon mengirim butir yang sama persis dengan HTML (tangkapan test/fixtures/pure/discount.json).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(s.debugDiscOptions(), ['Tidak', 'Member · 10% · min Rp50.000', 'Promo Satuan · Rp5.000 (Satuan)', 'Diskon manual (Rp)…']);
    s.aoSheetSelect(1, 1); // keranjang kosong: di bawah minimal
    expect(s.debugToast, '"Member" butuh minimal transaksi Rp50.000');
    s.aoSheetSelect(1, 3);
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
    final kv = _store();
    final s = await _pump(tester, kv);
    for (final f in Directory('test/fixtures/pure/pages').listSync().whereType<File>()) {
      final id = f.uri.pathSegments.last.replaceAll('.json', '');
      final fx = jsonDecode(f.readAsStringSync()) as Map;
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
}
