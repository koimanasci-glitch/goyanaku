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
  void scan() => calls.add(['scan']);
  @override
  void nav(String pageId) => calls.add(['nav', pageId]);
  @override
  void fmBack() => calls.add(['back']);
  @override
  void fmInput(int index, Object value) => calls.add(['input', index, value]);
  @override
  void fmToggle(int index) => calls.add(['toggle', index]);
  @override
  void fmRadio(int index) => calls.add(['radio', index]);
  @override
  void fmButton(int index) => calls.add(['button', index]);
  @override
  void fmFile(String inputId) => calls.add(['file', inputId]);
  @override
  void fmTap(int index) => calls.add(['tap', index]);
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) =>
      calls.add([scope, kind, index]);
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
    File('test/fixtures/parity/waautomation_active.json').readAsStringSync(),
  ) as List;
  for (final raw in cases) {
    final fixture = Map<String, dynamic>.from(raw as Map);
    final width = (fixture['width'] as num).toInt();
    final state = fixture['state'] as String;
    testWidgets('B11 halaman aktif $state $width: golden atas/bawah dan aksi', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 2.0, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      expect(fixture['page'], 'whatsappbot');
      final actions = _Actions();
      final model = FormModel.fromJson(
        'whatsappbot',
        Map<String, dynamic>.from(fixture['model'] as Map),
      );
      expect(model.items.any((i) => i['type'] == 'qr'), false);
      expect(
        model.items.where((i) => i['type'] == 'toggle').length,
        state == 'trial' ? 0 : 11,
      );
      if (state == 'changed') {
        expect(
          model.items
              .where((i) => i['type'] == 'toggle' && [0, 5].contains(i['i']))
              .map((i) => i['on']),
          [false, false],
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const Key('screen'),
            child: NativeForm(model: model, actions: actions, topInset: 31),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('WHATSAPP & CHATBOT'), findsOneWidget);
      expect(find.text('ONLINE'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      Future<void> golden(String position) async {
        final name = state == 'gold' && width == 390 && position == 'top'
            ? 'waautomation_native'
            : 'waautomation_${state}_${width}_$position';
        final file = 'screens/$name.png';
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
      }

      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      await golden('top');
      for (var i = 0; i < 3; i++) {
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(find.text('Layanan WhatsApp belum terhubung'), findsOneWidget);
      await golden('bottom');
      if (state == 'gold' && width == 390) {
        for (final item in model.items.where(
          (i) => i['type'] == 'button' || i['type'] == 'toggle',
        )) {
          scroll.position.jumpTo(0);
          await tester.pump();
          final target = find.text(item['t'] as String);
          await tester.scrollUntilVisible(
            target,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(target),
            alignment: 0.25,
          );
          await tester.pumpAndSettle();
          expect(
            tester.getCenter(target).dy,
            lessThan(734),
            reason: 'Aksi harus di atas footer, bukan terhalang navigasi',
          );
          await tester.tap(target);
          expect(
            actions.calls.last,
            item['file'] is String && (item['file'] as String).isNotEmpty
                ? ['file', item['file']]
                : [item['type'], item['i']],
          );
        }
        await tester.tap(find.text('‹'));
        expect(actions.calls.last, ['back']);
        await tester.tap(find.text('Pesanan'));
        expect(actions.calls.last, ['nav', 'orders']);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('B11 parser formulir kosong/bentuk berubah tidak crash', (
    tester,
  ) async {
    for (final json in <Map<String, dynamic>>[
      {},
      {'title': null, 'items': 'changed'},
      {
        'items': [null, 42, {}],
      },
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: NativeForm(
            model: FormModel.fromJson('whatsappbot', json),
            actions: _Actions(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
