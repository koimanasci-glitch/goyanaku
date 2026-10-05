@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/gs107_sheet.dart';
import 'package:goyana_flutter/native/mirror_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final w in ['Regular', 'Medium', 'SemiBold']) {
      final b = File('assets/fonts/Poppins-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(b.buffer)));
    }
    await loader.load();
  });
  final cases = jsonDecode(
    File('test/fixtures/parity/gs107_cases.json').readAsStringSync(),
  ) as List;
  for (final raw in cases) {
    final c = Map<String, dynamic>.from(raw as Map);
    final width = (c['width'] as num).toInt(), state = c['state'];
    testWidgets(
      'gs107 $state $width identik cermin, keyboard, scroll dan aksi',
      (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final model = Map<String, dynamic>.from(c['model'] as Map),
            buttons = <int>[],
            inputs = <List<Object>>[];
        var closed = 0;
        final native = NativeGs107Sheet(
          model: model,
          onButton: buttons.add,
          onInput: (i, v) => inputs.add([i, v]),
          onClose: () => closed++,
        );
        Future<void> show(Widget sheet, double keyboard) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width.toDouble(), 844),
                  devicePixelRatio: 2,
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                ),
                child: RepaintBoundary(
                  key: const Key('screen'),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0xfff6f7f9)),
                      ),
                      Positioned.fill(child: sheet),
                    ],
                  ),
                ),
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
        }

        Future<ui.Image> capture() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('screen')),
          );
          final result = (await tester.runAsync(
            () => boundary.toImage(pixelRatio: 1),
          ))!;
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

        for (final keyboard in [0.0, 280.0, 500.0]) {
          await show(
            NativeMirrorSheet(
              model: model,
              onButton: (_) {},
              onTap: (_) {},
              onInput: (_, _) {},
              onClose: () {},
            ),
            keyboard,
          );
          final top = await capture();
          await bottom();
          final end = await capture();
          await show(native, keyboard);
          await expectLater(
            find.byKey(const Key('screen')),
            matchesReferenceImage(top),
          );
          await bottom();
          await expectLater(
            find.byKey(const Key('screen')),
            matchesReferenceImage(end),
          );
          if (state == 'perfume' && width == 390 && keyboard == 0) {
            final update = autoUpdateGoldenFiles;
            if (File('test/screens/gs107_native.png').existsSync())
              autoUpdateGoldenFiles = false;
            try {
              await expectLater(
                find.byKey(const Key('screen')),
                matchesGoldenFile('screens/gs107_native.png'),
              );
            } finally {
              autoUpdateGoldenFiles = update;
            }
          }
        }
        await show(native, 0);
        for (final raw in c['buttons'] as List) {
          final b = Map<String, dynamic>.from(raw as Map);
          final target = find.byKey(ValueKey('gs107-button-${b['i']}'));
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          expect(buttons.last, b['i']);
        }
        for (var i = 0; i < (c['inputs'] as List).length; i++) {
          final field = find.byType(TextField).at(i);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, '12');
          expect(inputs.last, [i, '12']);
        }
        await tester.tapAt(const Offset(10, 10));
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('gs107 kosong dan bentuk/gaya rusak tidak crash', (tester) async {
    for (final model in <Map<String, dynamic>>[
      {},
      {'box': 'changed'},
      {
        'box': {
          's': {
            'bg': 42,
            'br': [1],
            'p': 'changed',
          },
          'ch': [
            null,
            42,
            {
              's': {'fs': -1, 'c': 'rgb(no,no,no)'},
              'spans': [
                {'t': 'Judul'},
              ],
            },
          ],
        },
      },
      {
        'box': {
          'ch': [
            {},
            {},
            {},
            {
              'ch': [
                {
                  'input': {'i': 'changed', 'v': null},
                  's': {'fs': -4},
                },
              ],
            },
          ],
        },
      },
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: NativeGs107Sheet(
            model: model,
            onButton: (_) {},
            onInput: (_, _) {},
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
