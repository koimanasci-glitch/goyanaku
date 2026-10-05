@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/checkout_page.dart';
import 'package:goyana_flutter/native/mirror_sheet.dart';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : {};
Iterable<int> _buttons(Map<String, dynamic> node) sync* {
  if (node['b'] is num) yield (node['b'] as num).toInt();
  for (final key in ['ch', 'spans']) {
    if (node[key] is List) {
      for (final child in (node[key] as List).whereType<Map>()) {
        yield* _buttons(_map(child));
      }
    }
  }
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
  final cases = (jsonDecode(
    File('test/fixtures/parity/checkout111_cases.json')
        .readAsStringSync(),
  ) as List).map(_map);
  for (final fixture in cases) {
    final width = (fixture['width'] as num).toInt(),
        name = fixture['name'] as String;
    testWidgets('Checkout native identik $name $width, atas/bawah dan aksi', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 2.0, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final model = _map(fixture['model']);
      final taps = <int>[], nav = <String>[], inputs = <List<Object>>[];
      Future<void> show(Widget page) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(key: const Key('screen'), child: page),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      }

      Future<ui.Image> capture() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('screen')),
        );
        final image = await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        );
        final result = image!;
        addTearDown(result.dispose);
        return result;
      }

      Future<void> bottom() async {
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
      }

      await show(
        NativeMirrorPage(
          model: model,
          topInset: 31,
          env: MirrorEnv(onButton: (_) {}, onTap: (_) {}, onInput: (_, _) {}),
          onNav: (_) {},
          onHeaderScan: () {},
        ),
      );
      final topReference = await capture();
      await bottom();
      final bottomReference = await capture();
      await show(
        NativeCheckoutPage(
          model: model,
          topInset: 31,
          onButton: taps.add,
          onInput: (i, value) => inputs.add([i, value]),
          onNav: nav.add,
          onHeaderScan: () => taps.add(0),
        ),
      );
      expect(find.text('KONFIRMASI PEMBELIAN'), findsOneWidget);
      await expectLater(
        find.byKey(const Key('screen')),
        matchesReferenceImage(topReference),
      );
      if (name == 'plan' && width == 390) {
        // Initial B8 run creates its baseline. Once checked in, CI may not update it.
        final baseline = File('test/screens/checkout_native.png');
        final update = autoUpdateGoldenFiles;
        if (baseline.existsSync()) autoUpdateGoldenFiles = false;
        try {
          await expectLater(
            find.byKey(const Key('screen')),
            matchesGoldenFile('screens/checkout_native.png'),
          );
        } finally {
          autoUpdateGoldenFiles = update;
        }
      }
      await bottom();
      await expectLater(
        find.byKey(const Key('screen')),
        matchesReferenceImage(bottomReference),
      );
      for (final i in _buttons(_map(model['body'])).toSet()) {
        final button = find.byKey(ValueKey('checkout-button-$i'));
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        await tester.tap(button);
        expect(taps.last, i);
      }
      await tester.tap(find.text('Pesanan'));
      expect(nav, ['orders']);
      for (final field in find.byType(TextField).evaluate().toList()) {
        final widget = field.widget as TextField;
        final finder = find.byWidget(widget);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, 'uji');
        expect(inputs.last, [name == 'activation' ? 0 : 1, 'uji']);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Checkout kosong atau bentuk berubah tidak crash, tanpa aksi palsu',
    (tester) async {
      final taps = <int>[];
      for (final model in <Map<String, dynamic>>[
        {},
        {
          'body': {
            'ch': [
              null,
              {'ch': 'changed'},
            ],
          },
          'bg': 42,
          'nav': 'changed',
        },
        {
          'body': {
            'ch': [
              {
                'ch': [
                  {
                    'b': 'changed',
                    's': {
                      'fw': 'changed',
                      'fs': 'changed',
                      'br': [null],
                      'bg': '#zzzzzz',
                      'c': 'rgb(x, 2, 3)',
                      'bc': '#zzzzzz',
                      'bw': 1,
                    },
                  },
                ],
              },
              {
                'ch': [null, {}],
              },
            ],
          },
        },
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: NativeCheckoutPage(
              model: model,
              topInset: 31,
              onButton: taps.add,
              onInput: (_, _) {},
              onNav: (_) {},
              onHeaderScan: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('KONFIRMASI PEMBELIAN'), findsOneWidget);
      }
      expect(taps, isEmpty);
    },
  );
}
