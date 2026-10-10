// Audit tombol Mode Murni: membuka tiap halaman, menekan tiap tombol/kartu/pilihan satu per satu pada aplikasi
// yang baru dibuka, lalu mencatat tombol yang tidak menghasilkan apa pun, fitur yang masih "belum tersedia",
// dan galat. Hasil ditulis ke test/screens/audit.txt (ikut terkirim ke branch ci-screens).
@Tags(['screens'])
@Timeout(Duration(minutes: 25))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/pure/access.dart';
import 'package:goyana_flutter/pure/pure_shell.dart';

Map<String, String> _seed() {
  final s = jsonDecode(File('test/fixtures/core/snapshot.json').readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final k in [Keys.business, Keys.services, Keys.outlets, Keys.activeOutlet, Keys.perfumes])
      if (s[k] is String) k: s[k] as String,
  };
}

class _Hit {
  _Hit(this.kind, this.i, this.label);
  final String kind, label;
  final int i;
}

/// Semua elemen yang bisa ditekan di daftar butir (tombol, kartu, pilihan, tombol baris, sel statistik, sakelar).
List<_Hit> _hits(Object? node, [List<_Hit>? out]) {
  out ??= [];
  if (node is List) {
    for (final e in node) {
      _hits(e, out);
    }
  } else if (node is Map) {
    final type = '${node['type'] ?? ''}';
    final label = '${node['t'] ?? node['btn'] ?? node['v'] ?? ''}'.replaceAll('\n', ' ');
    // Dilewati: isian, pilihan yang sudah terpilih (menekannya memang tidak mengubah apa pun), dan pemindai kamera.
    // ⌫ pada isian PIN yang masih kosong memang tidak mengubah apa pun.
    final skip = node['on'] == true && type != 'toggle' || RegExp(r'^(Scan|📷|⌫)').hasMatch(label);
    if (!skip && node['i'] is int && !const {'input', 'select', 'date', 'stepper', 'labelprev'}.contains(type) && '${node['file'] ?? ''}'.isEmpty) {
      out.add(_Hit(type == 'toggle' ? 'toggle' : (type == 'radio' ? 'radio' : 'button'), node['i'] as int, label));
    }
    if (node['tap'] is int && (node['tap'] as int) >= 0) out.add(_Hit('tap', node['tap'] as int, label));
    for (final v in node.values) {
      if (v is List || v is Map) _hits(v, out);
    }
  }
  return out;
}

String explain(Object ex) {
  final lines = '$ex'.split('\n');
  final loc = lines.where((l) => l.contains('file:///')).map((l) => l.trim().replaceAll(RegExp(r'file:///.*/mobile/'), '')).take(2).join(' ; ');
  return '${lines.first}${loc.isEmpty ? '' : ' [$loc]'}';
}

void main() {
  setUpAll(() async {
    // Font asli aplikasi; tanpa ini font uji yang lebih lebar membuat tampilan seolah meluber.
    final loader = FontLoader('Poppins');
    for (final f in ['Regular', 'Medium', 'SemiBold']) {
      final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });
  setUp(() => planAccess.testPlan = 'PLATINUM');
  tearDown(() => planAccess.testPlan = null);

  testWidgets('audit tombol Mode Murni', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var device = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('id.goyana/device'), (call) async {
      device++;
      return null;
    });
    late MemoryKvStore kv;
    final opening = <String, String>{};
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<PureShellState> fresh([String? page]) async {
      kv = MemoryKvStore(_seed());
      // Kunci baru di MaterialApp: Navigator ikut baru, jadi rute/popup dari tekanan sebelumnya tidak tersisa.
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: PureShell(store: kv, clock: () => DateTime(2026, 10, 3, 10))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
      final s = tester.state<PureShellState>(find.byType(PureShell, skipOffstage: false));
      if (page != null) {
        s.nav(page);
        await settle();
      }
      final ex = tester.takeException();
      if (ex != null) opening['${page ?? 'home'} (saat dibuka)'] = explain(ex);
      return s;
    }

    String snap(PureShellState s) =>
        '${s.debugState()}|${jsonEncode(s.debugItems())}|${jsonEncode([for (final id in s.debugSheetIds()) s.debugSheet(id)])}|${jsonEncode(kv.data)}|$device|${find.byType(BottomSheet).evaluate().length}';
    final dead = <String>[], stub = <String>[], errors = <String>[], ok = <String>[];
    final unreachable = <String>[];
    final stubRe = RegExp('belum tersedia|belum aktif|belum terhubung|sedang dipindah|menunggu (layanan|server)|segera hadir', caseSensitive: false);

    Future<void> judge(String where, PureShellState s, String before, void Function() press) async {
      try {
        press();
        await settle();
      } catch (e) {
        errors.add('$where → ${explain(e)}');
        return;
      }
      final ex = tester.takeException();
      if (ex != null) {
        errors.add('$where → ${explain(ex)}');
        return;
      }
      final toast = s.debugToast;
      if (snap(s) == before) {
        dead.add(where);
      } else if (stubRe.hasMatch(toast)) {
        stub.add('$where → "$toast"');
      } else {
        ok.add(where);
      }
    }

    String fatal = '';
    try {
    // ---- Beranda ----
    for (final (name, act) in <(String, void Function(PureShellState))>[
      for (var k = 0; k < 6; k++) ('Beranda · ikon $k', (s) => s.tile(k)),
      ('Beranda · MANAGE OUTLET', (s) => s.manageOutlet()), ('Beranda · QR', (s) => s.qr()), ('Beranda · Bulanan', (s) => s.monthly()),
      ('Beranda · Butuh bantuan', (s) => s.helpChat()), ('Beranda · banner 0', (s) => s.slide(0)),
    ]) {
      final s = await fresh();
      await judge(name, s, snap(s), () => act(s));
    }

    // ---- Pengaturan: tiap menu ----
    var s0 = await fresh('settings');
    final menu = s0.debugSettingsMenu();
    for (final g in (menu['groups'] as List).cast<Map>()) {
      final gi = (g['i'] as num).toInt();
      final items = (g['items'] as List? ?? const []).whereType<Map>().toList();
      if (g['accordion'] != true) {
        final s = await fresh('settings');
        await judge('Pengaturan · ${g['t']}', s, snap(s), () => s.stGroup(gi, false));
      }
      for (final it in items) {
        final s = await fresh('settings');
        await judge('Pengaturan · ${g['t']} › ${it['t']}', s, snap(s), () => s.stItem(gi, (it['j'] as num).toInt()));
      }
    }
    for (final (name, act) in <(String, void Function(PureShellState))>[
      ('Pengaturan · Simpan server', (s) => s.stSyncSave()), ('Pengaturan · Sinkron sekarang', (s) => s.stSyncNow()), ('Pengaturan · kartu akun', (s) => s.stAcctGo()),
      ('Pengaturan · Keluar', (s) => s.stLogout()), ('Pengaturan · Tutorial', (s) => s.stTutorial()),
    ]) {
      final s = await fresh('settings');
      await judge(name, s, snap(s), () => act(s));
    }

    // ---- Semua halaman formulir + popup tingkat pertama ----
    s0 = await fresh();
    final pages = s0.debugPageIds().toList();
    for (final page in pages) {
      final s1 = await fresh(page);
      if (s1.debugState().split('|').first != page) {
        unreachable.add('$page → ${s1.debugToast}');
        continue;
      }
      final seen = <String>{};
      for (final h in _hits(s1.debugItems())) {
        if (!seen.add('${h.kind}${h.i}')) continue;
        final where = '$page · ${h.kind == 'button' ? '' : '${h.kind} '}#${h.i} "${h.label}"';
        final s = await fresh(page);
        // Popup yang terbuka sendiri saat halaman dibuka (mis. jenis kelamin di Tambah Pelanggan) ditutup dulu,
        // seperti pengguna yang menutupnya sebelum menekan tombol di halaman.
        for (final id in s.debugSheetIds().toList()) {
          s.closePageSheet(id);
        }
        await settle();
        final sheetsBefore = s.debugSheetIds().toSet();
        void tap(PureShellState x) {
          switch (h.kind) {
            case 'toggle':
              x.fmToggle(h.i);
            case 'radio':
              x.fmRadio(h.i);
            case 'tap':
              x.fmTap(h.i);
            default:
              x.fmButton(h.i);
          }
        }

        await judge(where, s, snap(s), () => tap(s));
        // Popup yang baru terbuka: tekan tiap tombolnya (di aplikasi baru supaya tidak saling memengaruhi).
        final opened = s.debugSheetIds().where((id) => !sheetsBefore.contains(id)).toList();
        if (opened.isEmpty) continue;
        final sid = opened.last;
        final seen2 = <String>{};
        for (final h2 in _hits(s.debugSheet(sid) ?? const [])) {
          if (h2.kind != 'button' || !seen2.add('${h2.i}')) continue;
          final t = await fresh(page);
          tap(t);
          await settle();
          if (!t.debugSheetIds().contains(sid)) continue;
          await judge('$where › popup $sid #${h2.i} "${h2.label}"', t, snap(t), () => t.fmScoped(sid, 'button', h2.i));
        }
      }
    }

    } catch (e, st) {
      fatal = '${explain(e)}\n${'$st'.split('\n').take(6).join('\n')}';
    }
    tester.takeException();
    final report = StringBuffer()
      ..writeln('AUDIT TOMBOL MODE MURNI')
      ..writeln('diperiksa: ${dead.length + stub.length + errors.length + ok.length} · berfungsi: ${ok.length} · tidak bereaksi: ${dead.length} · belum tersedia: ${stub.length} · galat: ${errors.length}')
      ..writeln(fatal.isEmpty ? '' : '\n!! AUDIT BERHENTI DI TENGAH: $fatal')
      ..writeln('\n== GALAT SAAT HALAMAN DIBUKA (${opening.length}) ==\n${opening.entries.map((e) => '${e.key} → ${e.value}').join('\n')}')
      ..writeln('\n== GALAT (${errors.length}) ==\n${errors.join('\n')}')
      ..writeln('\n== TIDAK BEREAKSI (${dead.length}) ==\n${dead.join('\n')}')
      ..writeln('\n== BELUM TERSEDIA (${stub.length}) ==\n${stub.join('\n')}')
      ..writeln('\n== HALAMAN TIDAK TERBUKA (${unreachable.length}) ==\n${unreachable.join('\n')}')
      ..writeln('\n== BERFUNGSI (${ok.length}) ==\n${ok.join('\n')}');
    Directory('test/screens').createSync(recursive: true);
    File('test/screens/audit.txt').writeAsStringSync(report.toString());
  });
}
