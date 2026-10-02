// Renders native Flutter pages to PNG so they can be compared with the HTML design.
// CI: flutter test --tags screens --update-goldens (pushes test/screens/*.png to branch ci-screens).
@Tags(['screens'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/home_page.dart';

class _NoActions implements HomeActions {
  @override
  void scan() {}
  @override
  void slide(int index) {}
  @override
  void tile(int index) {}
  @override
  void manageOutlet() {}
  @override
  void qr() {}
  @override
  void monthly() {}
  @override
  void helpChat() {}
  @override
  void nav(String pageId) {}
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  for (final width in [320.0, 390.0, 412.0]) {
    testWidgets('Beranda native at $width px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const Key('screen'),
          child: NativeHome(model: const HomeModel(badge: '3'), actions: _NoActions(), topInset: 0),
        ),
      ));
      // flutter_svg decodes asynchronously.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('screens/home_${width.toInt()}.png'));
    });
  }
}
