import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/native/brand_intro.dart';
import 'package:goyana_flutter/native/common.dart';

void main() {
  testWidgets('Brand header uses a PNG symbol and Flutter lettering', (
    tester,
  ) async {
    var scans = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GTopBar(top: 31, onScan: () => scans++)),
      ),
    );
    expect(find.text('Goyana'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as AssetImage).assetName, 'assets/branding/mark.png');
    expect(tester.getSize(find.byType(Image).first), const Size(34, 34));
    await tester.tap(find.byType(GWhiteSquare));
    expect(scans, 1);
  });
  testWidgets(
    'First opening lasts 3 seconds and stores an independent marker',
    (tester) async {
      final store = MemoryKvStore();
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrandIntro(ready: true, store: store, onDone: () => done++),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2900));
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pump();
      expect(done, 1);
      expect(await store.get(brandIntroKey), '1');
      expect(await store.get('goyana-onboarding189'), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Later openings finish in 350ms and do not repeat long intro', (
    tester,
  ) async {
    final store = MemoryKvStore({brandIntroKey: '1'});
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntro(ready: true, store: store, onDone: () => done++),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pump();
    expect(done, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Animation completion does not replace application initialization',
    (tester) async {
      final store = MemoryKvStore({brandIntroKey: '1'});
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrandIntro(ready: false, store: store, onDone: () => done++),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: BrandIntro(ready: true, store: store, onDone: () => done++),
        ),
      );
      await tester.pump();
      expect(done, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
