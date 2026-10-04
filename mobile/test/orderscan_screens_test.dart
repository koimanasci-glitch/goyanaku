@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/mirror_sheet.dart';
import 'package:goyana_flutter/native/orderscan_page.dart';

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
    testWidgets('Scan Pesanan native identik dengan cermin $width', (tester) async {
      tester.view.physicalSize = Size(width * 2.0, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final model = Map<String, dynamic>.from(
        jsonDecode(File('test/fixtures/mirror_pages/orderscan.json').readAsStringSync()) as Map,
      );
      final taps = <int>[];
      final inputs = <List<Object>>[];

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
        env: MirrorEnv(onButton: taps.add, onTap: (_) {}, onInput: (_, _) {},
          video: (_) => const ColoredBox(color: Color(0xff080a0d))),
        onNav: (_) {},
        onHeaderScan: () => taps.add((model['scan'] as num).toInt()),
      ));
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
      final reference = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
      expect(reference, isNotNull);
      addTearDown(reference!.dispose);

      await show(NativeOrderscanPage(
        model: model,
        topInset: 31,
        onButton: taps.add,
        onInput: (i, v) => inputs.add([i, v]),
        cameraBuilder: (_) => const ColoredBox(color: Color(0xff080a0d)),
      ));
      expect(find.text('Scan Barcode / QR Pesanan'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await expectLater(find.byKey(const Key('screen')), matchesReferenceImage(reference));
      if (width == 390) {
        final previous = autoUpdateGoldenFiles;
        autoUpdateGoldenFiles = false;
        try {
          await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/orderscan_native.png'));
        } finally {
          autoUpdateGoldenFiles = previous;
        }
      }
      await tester.tap(find.byKey(const Key('orderscan-close')));
      await tester.tap(find.byKey(const Key('orderscan-find')));
      expect(taps, [1, 2]);
      await tester.enterText(find.byKey(const Key('orderscan-input')), 'GY-001');
      expect(inputs.last, [0, 'GY-001']);

    });
  }
  for (final width in [390, 320]) {
  testWidgets('Scan Pesanan pilihan hasil meneruskan indeks HTML $width', (tester) async {
    final model = Map<String, dynamic>.from(
      jsonDecode(File('test/fixtures/mirror_pages/orderscan.json').readAsStringSync()) as Map,
    );
    final overlay = (model['body'] as Map)['ch'][1] as Map;
    (overlay['ch'] as List).add({
      'w': 320, 's': {'m': [8, 0, 0, 0], 'p': [8, 8, 8, 8], 'bg': 'rgb(255, 255, 255)', 'br': [12, 12, 12, 12]},
      'ch': [for (var i = 0; i < 2; i++) {
        'b': 3 + i, 's': {'p': [12, 12, 12, 12], 'fs': 13, 'fw': 400, 'lh': 18.2,
          'c': 'rgb(34, 34, 34)', 'bg': 'rgb(255, 255, 255)', 'bw': 1,
          'bc': 'rgb(238, 238, 238)', 'bs': [0, 0, 1, 0]},
        'spans': [{'t': 'Pilihan $i'}],
      }],
    });
    tester.view.physicalSize = Size(width * 2.0, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: const Key('results-screen'),
      child: NativeMirrorPage(model: model, topInset: 31, onNav: (_) {}, onHeaderScan: () {},
        env: MirrorEnv(onButton: (_) {}, onTap: (_) {}, onInput: (_, _) {},
          video: (_) => const ColoredBox(color: Color(0xff080a0d)))))));
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('results-screen')));
    final reference = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    expect(reference, isNotNull);
    addTearDown(reference!.dispose);
    await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: const Key('results-screen'),
      child: NativeOrderscanPage(
      model: model, topInset: 31, onButton: taps.add, onInput: (_, _) {},
      cameraBuilder: (_) => const ColoredBox(color: Color(0xff080a0d)),
    ))));
    expect(tester.takeException(), isNull);
    await tester.pump();
    await expectLater(find.byKey(const Key('results-screen')), matchesReferenceImage(reference));
    expect(find.text('Pilihan 0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('orderscan-result-1')));
    expect(taps, [4]);
  });
  }
  testWidgets('Scan Pesanan model kosong tidak crash', (tester) async {
    await tester.pumpWidget(MaterialApp(home: NativeOrderscanPage(
      model: const {}, topInset: 31, onButton: (_) {}, onInput: (_, _) {},
      cameraBuilder: (_) => const ColoredBox(color: Color(0xff080a0d)),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('Scan Barcode / QR Pesanan'), findsOneWidget);
  });
}
