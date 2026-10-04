@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/perfume_page.dart';

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

  testWidgets('Parfum native sama dengan patokan cermin', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final model = Map<String, dynamic>.from(
      jsonDecode(File('test/fixtures/mirror_pages/perfume.json').readAsStringSync()) as Map,
    );
    final taps = <int>[];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: const Key('screen'),
        child: NativePerfumePage(
          model: model,
          topInset: 31,
          onButton: taps.add,
          onNav: (_) {},
          onHeaderScan: () {},
        ),
      ),
    ));

    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('screen')),
      matchesGoldenFile('screens/perfume_native.png'),
    );

    await tester.tap(find.byKey(const Key('perfume-add')));
    expect(taps.last, 2);
    await tester.tap(find.byKey(const Key('perfume-edit-0')));
    expect(taps.last, 3);
    await tester.tap(find.byKey(const Key('perfume-delete-0')));
    expect(taps.last, 4);
  });
}
