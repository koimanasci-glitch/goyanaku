@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/popup_components.dart';
import 'package:goyana_flutter/native/f61_print_sheet.dart';
import 'package:goyana_flutter/native/hist115_sheet.dart';
import 'package:goyana_flutter/native/photo115_sheet.dart';
import 'package:goyana_flutter/native/wa131_sheet.dart';
import 'package:goyana_flutter/native/wa138_sheet.dart';
import 'package:goyana_flutter/native/rm138s_sheet.dart';
import 'package:goyana_flutter/native/rs139_sheet.dart';
import 'package:goyana_flutter/native/contacts178_sheet.dart';
import 'package:goyana_flutter/native/guide135_sheet.dart';
import 'package:goyana_flutter/native/api135_sheet.dart';
import 'package:goyana_flutter/native/pay111_sheet.dart';
import 'package:goyana_flutter/native/upgrade_pay_modal_sheet.dart';
import 'package:goyana_flutter/native/g181_modal_sheet.dart';
import 'package:goyana_flutter/native/td175_sheet.dart';

import 'package:goyana_flutter/native/mirror_sheet.dart';

Widget nativePopup(
  String id,
  Map<String, dynamic> model,
  PopupActions actions,
) => switch (id) {
  'f61-print' => NativeF61PrintSheet(model: model, actions: actions),
  'hist115' => NativeHist115Sheet(model: model, actions: actions),
  'photo115' => NativePhoto115Sheet(model: model, actions: actions),
  'wa131' => NativeWa131Sheet(model: model, actions: actions),
  'wa138' => NativeWa138Sheet(model: model, actions: actions),
  'rm138s' => NativeRm138sSheet(model: model, actions: actions),
  'rs139' => NativeRs139Sheet(model: model, actions: actions),
  'contacts178' => NativeContacts178Sheet(model: model, actions: actions),
  'guide135' => NativeGuide135Sheet(model: model, actions: actions),
  'api135' => NativeApi135Sheet(model: model, actions: actions),
  'pay111' => NativePay111Sheet(model: model, actions: actions),
  'upgrade-pay-modal' => NativeUpgradePaySheet(model: model, actions: actions),
  'g181-modal' => NativeG181ModalSheet(model: model, actions: actions),
  'td175' => NativeTd175Sheet(model: model, actions: actions),
  _ => throw ArgumentError(id),
};

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
    File('test/fixtures/parity/remaining_popups.json').readAsStringSync(),
  ) as List;
  for (final id in [
    'f61-print',
    'hist115',
    'photo115',
    'wa131',
    'wa138',
    'rm138s',
    'rs139',
    'contacts178',
    'guide135',
    'api135',
    'pay111',
    'upgrade-pay-modal',
    'g181-modal',
    'td175',
  ]) {
    cases.add({
      'id': id,
      'state': 'canonical',
      'width': 390,
      'model': jsonDecode(
        File('test/fixtures/popups/$id.json').readAsStringSync(),
      ),
    });
  }
  for (final raw in cases) {
    final c = Map<String, dynamic>.from(raw as Map);
    final width = (c['width'] as num).toInt(),
        state = c['state'],
        id = c['id'] as String;
    testWidgets('$id $state $width identik cermin, keyboard, scroll dan aksi', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 2.0, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final model = Map<String, dynamic>.from(c['model'] as Map),
          buttons = <int>[],
          inputs = <List<Object>>[];
      var closed = 0;
      final taps = <int>[];
      final actions = PopupActions(
        id: id,
        onButton: buttons.add,
        onTap: taps.add,
        onInput: (i, v) => inputs.add([i, v]),
        onClose: () => closed++,
      );
      final native = nativePopup(id, model, actions);
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
          final prefix = id.replaceAll('-', '_');
          final file = state == 'current' && width == 390 && position == 'top'
              ? '${prefix}_native.png'
              : '${prefix}_${state}_${width}_$position.png';
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
      final modelButtons = <int>{};
      final modelTaps = <int>{}, linkButtons = <int>{}, linkTaps = <int>{};
      void collect(Object? v) {
        if (v is Map) {
          if (v['b'] is num) modelButtons.add((v['b'] as num).toInt());
          if (v['tap'] is num) modelTaps.add((v['tap'] as num).toInt());
          for (final span
              in v['spans'] is List ? v['spans'] as List : <Object>[]) {
            if (span is Map) {
              if (span['b'] is num) linkButtons.add((span['b'] as num).toInt());
              if (span['tap'] is num) {
                linkTaps.add((span['tap'] as num).toInt());
              }
            }
          }
          for (final child in v['ch'] is List ? v['ch'] as List : <Object>[]) {
            collect(child);
          }
        }
      }

      collect(model['box']);
      for (final index in modelButtons) {
        final target = find.byKey(ValueKey('$id-button-$index'));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final before = buttons.length;
        await tester.tap(target);
        expect(buttons.length, before + 1);
        expect(buttons.last, index);
      }
      for (final index in modelTaps) {
        final target = find.byKey(ValueKey('$id-tap-$index'));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final before = taps.length;
        await tester.tap(target);
        expect(taps.length, before + 1);
        expect(taps.last, index);
      }
      for (final indices in [linkButtons, linkTaps]) {
        final button = identical(indices, linkButtons);
        for (final index in indices) {
          final target = find.byKey(
            ValueKey('$id-link-${button ? 'button' : 'tap'}-$index'),
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          final list = button ? buttons : taps, before = list.length;
          await tester.tap(target);
          expect(list.length, before + 1);
          expect(list.last, index);
        }
      }
      final fields = find.byType(TextField);
      for (var k = 0; k < fields.evaluate().length; k++) {
        final field = fields.at(k);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        final current = tester.widget<TextField>(field).controller!.text,
            changed = current == '12' ? '24' : '12';
        final before = inputs.length;
        await tester.enterText(field, changed);
        expect(inputs.length, before + 1);
        final parent = find
            .ancestor(
              of: field,
              matching: find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey &&
                    (w.key as ValueKey).value.toString().startsWith(
                      '$id-input-',
                    ),
              ),
            )
            .first;
        final key = tester.widget(parent).key as ValueKey;
        expect(inputs.last, [
          int.parse(key.value.toString().substring('$id-input-'.length)),
          changed,
        ]);
      }
      final dropdowns = find.byType(DropdownButton<int>);
      for (var k = 0; k < dropdowns.evaluate().length; k++) {
        final field = dropdowns.at(k),
            widget = tester.widget<DropdownButton<int>>(dropdowns.at(k));
        if ((widget.items?.length ?? 0) < 2) continue;
        final next = ((widget.value ?? 0) + 1) % widget.items!.length;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        final target = find
            .byWidgetPredicate(
              (w) => w is DropdownMenuItem<int> && w.value == next,
            )
            .last;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final before = inputs.length;
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(inputs.length, before + 1);
        expect(inputs.last[1], next);
      }
      await tester.tapAt(const Offset(10, 10));
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    });
  }
  for (final id in [
    'f61-print',
    'hist115',
    'photo115',
    'wa131',
    'wa138',
    'rm138s',
    'rs139',
    'contacts178',
    'guide135',
    'api135',
    'pay111',
    'upgrade-pay-modal',
    'g181-modal',
    'td175',
  ]) {
    testWidgets('$id model kosong/bentuk rusak tidak crash', (tester) async {
      final actions = PopupActions(
        id: id,
        onButton: (_) {},
        onTap: (_) {},
        onInput: (_, _) {},
        onClose: () {},
      );
      for (final model in <Map<String, dynamic>>[
        {},
        {'box': 'changed'},
        {
          'box': {
            's': {'p': 'changed', 'bg': 42},
            'ch': [
              null,
              42,
              {
                's': {'fs': -4, 'c': 'rgb(no,no,no)'},
                'spans': [
                  {'t': 'Uji'},
                ],
              },
            ],
          },
        },
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: nativePopup(id, model, actions)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
