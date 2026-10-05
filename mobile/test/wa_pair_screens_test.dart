@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/form_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _Actions implements FormActions {
  final calls = <List<Object?>>[];
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) =>
      calls.add([scope, kind, index]);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      final bytes = File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });
  final cases = jsonDecode(
    File('test/fixtures/parity/wa_pair195.json').readAsStringSync(),
  ) as List;
  for (final raw in cases) {
    final fixture = Map<String, dynamic>.from(raw as Map);
    final width = (fixture['width'] as num).toInt();
    final method = fixture['method'] as String;
    testWidgets('Hubungkan WA $method $width: pilihan dan indeks HTML', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 2.0, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final actions = _Actions();
      final sheet = Map<String, dynamic>.from(fixture['sheet'] as Map);
      final items = (sheet['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final options =
          (items.firstWhere((i) => i['type'] == 'buttons')['options'] as List);
      expect(options[method == 'qr' ? 0 : 1]['on'], true);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const Key('screen'),
            child: Stack(
              children: [
                NativeForm(
                  model: FormModel.fromJson(
                    'wadevices195',
                    Map<String, dynamic>.from(fixture['model'] as Map),
                  ),
                  actions: actions,
                  topInset: 31,
                ),
                Positioned.fill(
                  child: NativeSheet(
                    id: 'wa195-pair',
                    items: items,
                    actions: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(NativeSheet),
          matching: find.text('Hubungkan WhatsApp'),
        ),
        findsOneWidget,
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.textContaining(
          method == 'qr' ? 'pindai QR dari CHATKU' : 'Kode ini bukan OTP SMS',
        ),
        findsOneWidget,
      );
      final file = 'screens/wa_pair_${method}_$width.png';
      final update = autoUpdateGoldenFiles;
      if (File('test/$file').existsSync()) autoUpdateGoldenFiles = false;
      try {
        await expectLater(
          find.byKey(const Key('screen')),
          matchesGoldenFile(file),
        );
      } finally {
        autoUpdateGoldenFiles = update;
      }
      for (final entry in [
        'Scan QR',
        'Kode WhatsApp',
        'Tutup',
      ].asMap().entries) {
        await tester.tap(find.text(entry.value));
        expect(actions.calls.last, ['wa195-pair', 'button', entry.key]);
      }
      await tester.tapAt(const Offset(10, 50));
      expect(actions.calls.last, ['wa195-pair', 'close', 0]);
      expect(tester.takeException(), isNull);
    });
  }
}
