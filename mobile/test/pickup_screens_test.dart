@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/mirror_sheet.dart';
import 'package:goyana_flutter/native/pickup_page.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  for (final width in [390, 320]) {
    testWidgets('Jemput native identik dengan cermin $width', (tester) async {
      tester.view.physicalSize = Size(width * 2.0, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final model = Map<String, dynamic>.from(
        jsonDecode(File('test/fixtures/mirror_pages/pickup.json').readAsStringSync()) as Map,
      );
      final taps = <int>[];
      final nav = <String>[];

      Future<void> show(Widget page) async {
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: const Key('screen'), child: page),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      }

      await show(NativeMirrorPage(
        model: model,
        topInset: 31,
        env: MirrorEnv(onButton: taps.add, onTap: (_) {}, onInput: (_, _) {}),
        onNav: nav.add,
        onHeaderScan: () => taps.add((model['scan'] as num).toInt()),
      ));
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
      final reference = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
      expect(reference, isNotNull);
      addTearDown(reference!.dispose);

      await show(NativePickupPage(
        model: model,
        topInset: 31,
        onButton: taps.add,
        onNav: nav.add,
        onHeaderScan: () => taps.add((model['scan'] as num).toInt()),
      ));
      expect(find.text('PENGAMBILAN PESANAN'), findsOneWidget);
      expect(find.text('Pesanan ditemukan'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await expectLater(find.byKey(const Key('screen')), matchesReferenceImage(reference));
      if (width == 390) {
        await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/pickup_native.png'));
      }
      await tester.tap(find.byKey(const Key('pickup-back')));
      expect(taps, [1]);
      await tester.tap(find.byKey(const Key('pickup-pay')));
      await tester.tap(find.byKey(const Key('pickup-done')));
      expect(taps, [1, 2, 3]);
      await tester.tap(find.text('Pesanan'));
      expect(nav, ['orders']);
    });
  }
  testWidgets('Jemput model kosong tidak crash', (tester) async {
    await tester.pumpWidget(MaterialApp(home: NativePickupPage(
      model: const {}, topInset: 31, onButton: (_) {},
      onNav: (_) {}, onHeaderScan: () {},
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('PENGAMBILAN PESANAN'), findsOneWidget);
    expect(find.text('Pesanan ditemukan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pickup-back')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(home: NativePickupPage(
      model: const {'body': {'ch': [null, {'ch': 'changed'}]}, 'nav': 'changed', 'bg': 42},
      topInset: 31, onButton: (_) {}, onNav: (_) {}, onHeaderScan: () {},
    )));
    expect(tester.takeException(), isNull);
  });

}
