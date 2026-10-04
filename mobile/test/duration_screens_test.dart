@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/duration_page.dart';

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

  testWidgets('Durasi native sama dengan patokan cermin', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final model = Map<String, dynamic>.from(
      jsonDecode(File('test/fixtures/mirror_pages/duration.json').readAsStringSync()) as Map,
    );
    final taps = <int>[];

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: const Key('screen'),
        child: NativeDurationPage(
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
    expect(find.text('REGULER'), findsNothing);
    expect(find.text('Reguler'), findsOneWidget);
    expect(find.text('Express'), findsOneWidget);
    expect(find.text('Kilat'), findsOneWidget);

    await expectLater(
      find.byKey(const Key('screen')),
      matchesGoldenFile('screens/duration_native.png'),
    );

    await tester.tap(find.byKey(const Key('duration-add')));
    expect(taps.last, 3);
    await tester.tap(find.byKey(const Key('duration-edit-0')));
    expect(taps.last, 4);
    await tester.tap(find.byKey(const Key('duration-delete-0')));
    expect(taps.last, 5);
  });
}
