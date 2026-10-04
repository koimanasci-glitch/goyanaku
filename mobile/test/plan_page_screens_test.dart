@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/plan_page.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/Poppins-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

List<Map<String, dynamic>> _items(Map<String, dynamic> model) =>
    (model['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

void main() {
  setUpAll(_loadFonts);

  testWidgets('Harga Paket plan111 Flutter asli', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final mirror = Map<String, dynamic>.from(
      jsonDecode(File('test/fixtures/mirror_pages/plan111.json').readAsStringSync()) as Map,
    );
    final pricing = Map<String, dynamic>.from(
      jsonDecode(File('test/fixtures/forms/upgrade.json').readAsStringSync()) as Map,
    );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: const Key('screen'),
        child: NativePlanPage(
          model: mirror,
          pricingItems: _items(pricing),
          onButton: (_) {},
          onPricingButton: (_) {},
          onNav: (_) {},
          onHeaderScan: () {},
          topInset: 31,
        ),
      ),
    ));

    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('screen')),
      matchesGoldenFile('screens/plan111_native.png'),
    );
  });
}
