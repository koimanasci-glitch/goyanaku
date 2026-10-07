// Mode murni: halaman Parfum mengikuti HTML (tombol Tambah di atas, popup Tambah/Edit/Hapus).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/models.dart' show durationHours, durationOverrides;
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/native/duration_page.dart';
import 'package:goyana_flutter/native/perfume_page.dart';
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

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

List<List<String>> _saved(MemoryKvStore kv) {
  final raw = kv.data[Keys.perfumes];
  return [for (final e in jsonDecode(raw ?? '[]') as List) [for (final x in e as List) '$x']];
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('Parfum: daftar sama dengan HTML, tambah, ubah dan hapus lewat popup', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('perfume');
    await _settle(tester);
    final fx = jsonDecode(File('test/fixtures/forms/perfume.json').readAsStringSync()) as Map;
    expect(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').toLowerCase() == '+ tambah parfum'), findsOneWidget);
    for (final it in (fx['items'] as List).cast<Map>()) {
      if (it['type'] == 'entry') expect(find.text('${it['t']}'), findsWidgets, reason: '${it['t']}');
      if (it['type'] == 'hint') expect(find.text('${it['t']}'), findsOneWidget);
    }
    expect(find.byType(NativePerfumePage), findsOneWidget);

    // Tambah: popup "Tambah Parfum" dengan nama + warna label.
    s.fmButton(2);
    await _settle(tester);
    expect(find.text('Tambah Parfum'), findsOneWidget);
    expect(find.text('Nama parfum'), findsOneWidget);
    expect(find.text('Warna label'), findsOneWidget);
    // Nama kosong ditolak.
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(find.text('Tambah Parfum'), findsOneWidget, reason: 'popup tetap terbuka');
    s.fmScoped('gs107', 'input', 0, 'Vanilla');
    s.fmScoped('gs107', 'input', 1, 4); // warna ke-5 (#f07aa0)
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(find.text('Vanilla'), findsOneWidget);
    expect(_saved(kv).last, ['Vanilla', 'rgb(240, 122, 160)']);

    // Edit parfum pertama.
    s.fmButton(3);
    await _settle(tester);
    expect(find.text('Edit Parfum'), findsOneWidget);
    s.fmScoped('gs107', 'input', 0, 'Akasia Baru');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(_saved(kv).first.first, 'Akasia Baru');

    // Hapus parfum kedua: konfirmasi dulu.
    s.fmButton(6);
    await _settle(tester);
    expect(find.text('Hapus "Junjung Buih"?'), findsOneWidget);
    expect(find.text('Ya, Hapus'), findsOneWidget);
    s.fmScoped('gs107', 'button', 1); // Batal
    await _settle(tester);
    expect(_saved(kv).length, 6);
    s.fmButton(6);
    await _settle(tester);
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(_saved(kv).map((e) => e.first), ['Akasia Baru', 'Lavender', 'Ocean', 'Sakura', 'Vanilla']);
  });

  testWidgets('Durasi: 3 durasi utama, jam bisa diubah dan dipakai di Tambah Transaksi, tidak bisa dihapus', (tester) async {
    final kv = _store();
    final s = await _pump(tester, kv);
    s.nav('duration');
    await _settle(tester);
    expect(find.byType(NativeDurationPage), findsOneWidget);
    for (final n in ['Reguler', 'Express', 'Kilat']) {
      expect(find.text(n), findsOneWidget);
    }
    s.fmButton(8); // hapus Kilat
    await _settle(tester);
    expect(find.text('Durasi Kilat tidak bisa dihapus. Matikan per layanan di Pengaturan → Layanan & Harga.'), findsOneWidget);
    s.fmButton(6); // ubah Express
    await _settle(tester);
    expect(find.text('Edit Durasi Express'), findsOneWidget);
    s.fmScoped('gs107', 'input', 0, '12');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(jsonDecode(kv.data['goyana-durations199']!), {'Express': 12});
    expect(durationHours('Express'), 12);
    s.fmButton(3); // tambah (tidak disimpan, sama dengan HTML)
    await _settle(tester);
    s.fmScoped('gs107', 'input', 0, 'Super Kilat');
    s.fmScoped('gs107', 'input', 1, '3');
    s.fmScoped('gs107', 'button', 0);
    await _settle(tester);
    expect(find.text('Super Kilat'), findsOneWidget);
    durationOverrides.clear();
  });
}
