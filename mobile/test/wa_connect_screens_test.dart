// Hubungkan WhatsApp tampilan baru (mockup Paduka 9 Oktober 2026): daftar perangkat, popup QR, popup kode, popup berhasil.
@Tags(['screens'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/form_page.dart';

class _Actions implements FormActions {
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) {}
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void fmBack() {}
  @override
  void fmInput(int index, Object value) {}
  @override
  void fmToggle(int index) {}
  @override
  void fmRadio(int index) {}
  @override
  void fmButton(int index) {}
  @override
  void fmFile(String inputId) {}
  @override
  void fmTap(int index) {}
}

const _page = {
  'title': 'HUBUNGKAN WHATSAPP',
  'items': [
    {'type': 'hint', 't': 'Kelola nomor WhatsApp untuk setiap perangkat.'},
    {'type': 'button', 't': '+ Tambah Device', 'primary': true, 'file': '', 'after': false, 'i': 0},
    {
      'type': 'wadevice', 't': 'Goyana Pusat', 'ok': false, 'avatar': 'G',
      'lines': ['+6281210274179 · Goyana', 'Belum dihubungkan'],
      'btns': [
        {'t': 'Hubungkan', 'ic': 'link', 'on': true, 'i': 1000},
        {'t': 'Edit', 'ic': 'edit', 'on': false, 'i': 1001},
        {'t': 'Hapus', 'ic': 'delete', 'on': false, 'i': 1002},
      ],
    },
  ],
};

List<Map<String, dynamic>> _pair(bool qr) => [
      {'type': 'sheethead', 't': 'Hubungkan WhatsApp', 's': 'Goyana Pusat · +6281210274179', 'i': 2},
      {'type': 'methods', 'options': [
        {'t': 'Scan QR', 'kind': 'qr', 'on': qr, 'i': 0},
        {'t': 'Kode WhatsApp', 'kind': 'code', 'on': !qr, 'i': 1},
      ]},
      if (qr)
        {'type': 'qr', 'data': '2@Hk3+abcDEF123/ghi456,JKLmno789pqr,STUvwx012yz=,ABCdef345ghi', 'size': 210, 'frame': true}
      else
        {'type': 'pcode', 't': '5289-7143', 'i': 5},
      {'type': 'tip', 't': qr ? 'Pindai QR ini di WhatsApp' : 'Masukkan kode ini di WhatsApp',
          's': 'Buka WhatsApp di HP outlet, pilih **Perangkat Tertaut** lalu masukkan kode ini.'},
      {'type': 'button', 't': qr ? 'Tampilkan QR' : 'Buat Kode Baru', 'ic': qr ? 'share' : 'refresh', 'primary': true, 'file': '', 'after': false, 'i': 3},
      {'type': 'button', 't': 'Tutup', 'primary': false, 'file': '', 'after': false, 'i': 2},
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      final bytes = File('assets/fonts/Poppins-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  for (final (name, sheet) in [
    ('wa_connect_daftar', null),
    ('wa_connect_qr', _pair(true)),
    ('wa_connect_kode', _pair(false)),
    ('wa_connect_berhasil', [
      {'type': 'success', 't': 'Kode berhasil dibuat', 's': 'Masukkan kode ini di WhatsApp pada Perangkat Tertaut.'},
      {'type': 'button', 't': 'OK', 'primary': true, 'file': '', 'after': false, 'i': 0},
    ]),
  ]) {
    testWidgets('Hubungkan WhatsApp: $name', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final a = _Actions();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: Stack(children: [
            NativeForm(model: FormModel.fromJson('wadevices195', Map<String, dynamic>.from(_page)), actions: a),
            if (sheet != null) Positioned.fill(child: NativeSheet(id: name, items: sheet, actions: a)),
          ]),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/$name.png'));
    });
  }
}
