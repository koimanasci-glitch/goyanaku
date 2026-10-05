@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/cat99_sheet.dart';
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
    File('test/fixtures/parity/cat99_cases.json').readAsStringSync(),
  ) as List;
  for (final raw in cases) {
    final c = Map<String, dynamic>.from(raw as Map);
    final width = (c['width'] as num).toInt(), state = c['state'];
    testWidgets(
      'cat99 $state $width identik cermin, keyboard, scroll dan aksi',
      (tester) async {
        tester.view.physicalSize = Size(width * 2.0, 844 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final model = Map<String, dynamic>.from(c['model'] as Map),
            buttons = <int>[],
            inputs = <List<Object>>[];
        var closed = 0;
        final native = NativeCat99Sheet(
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
          Future<void> golden(String position) async {
            if (keyboard != 0) return;
            final file = state == 'empty' && width == 390 && position == 'top'
                ? 'cat99_native.png'
                : 'cat99_${state}_${width}_$position.png';
            final update = autoUpdateGoldenFiles;
            if (File('test/screens/$file').existsSync()) {
              autoUpdateGoldenFiles = false;
            }
            try {
              await expectLater(
                find.byKey(const Key('screen')),
                matchesGoldenFile('screens/$file'),
              );
            } finally {
              autoUpdateGoldenFiles = update;
            }
          }

          await golden('top');
          await bottom();
          await expectLater(
            find.byKey(const Key('screen')),
            matchesReferenceImage(end),
          );
          await golden('bottom');
        }
        await show(native, 0);
        for (final raw in c['buttons'] as List) {
          final b = Map<String, dynamic>.from(raw as Map);
          final target = find.byKey(ValueKey('cat99-button-${b['i']}'));
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          final before = buttons.length;
          await tester.tap(target);
          expect(buttons.length, before + 1);
          expect(buttons.last, b['i']);
        }
        for (var i = 0; i < (c['inputs'] as List).length; i++) {
          final field = find.byType(TextField).at(i);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          final current = tester.widget<TextField>(field).controller!.text;
          final changed = current == '12' ? '24' : '12';
          final previousCount = inputs.length;
          await tester.enterText(field, changed);
          expect(inputs.length, previousCount + 1);
          expect(inputs.last, [i, changed]);
        }
        await tester.tapAt(const Offset(10, 10));
        expect(closed, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cat99 kosong dan bentuk/gaya rusak tidak crash', (tester) async {
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
                {'t': 'Kategori Baru'},
              ],
            },
          ],
        },
      },
      {
        'box': {
          'ch': [
            ...List.generate(4, (_) => <String, dynamic>{}),
            {
              'input': {'i': 'changed', 'v': 42},
              's': {'fs': -4},
            },
            {},
            {
              'grid': -2,
              'colw': ['changed'],
              'gap': -9,
              'ch': [
                null,
                42,
                {
                  'ch': [
                    {'svg': 42},
                  ],
                },
              ],
            },
            {},
            {
              'grid': 'changed',
              'colw': [1e308],
              'ch': [{}],
            },
            {},
            {
              'gap': -3,
              'ch': [
                {
                  'b': 'changed',
                  'spans': [
                    {'t': 'Cuci'},
                  ],
                },
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
          home: NativeCat99Sheet(
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
