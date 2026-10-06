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
    'First opening plays the 1.2s dove intro and stores an independent marker',
    (tester) async {
      final store = MemoryKvStore();
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrandIntro(ready: true, store: store, onDone: () => done++),
        ),
      );
      await tester.pump();
      expect(find.text('Goyana'), findsOneWidget);
      expect(find.text('KASIR LAUNDRY'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(done, 0, reason: 'leave fade still running');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(done, 1);
      expect(await store.get(brandIntroKey), '1');
      expect(await store.get('goyana-onboarding189'), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Later openings take 0.9s', (tester) async {
    final store = MemoryKvStore({brandIntroKey: '1'});
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntro(ready: true, store: store, onDone: () => done++),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 850));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
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
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: BrandIntro(ready: true, store: store, onDone: () => done++),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(done, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('Dove settles in, looks left, then right, and ends facing right', () {
    final start = doveAt(0);
    expect(start.opacity, 0, reason: 'invisible at the very start');
    final rest = doveAt(.25);
    expect(rest.scaleX, 1);
    expect(rest.opacity, 1);
    expect(rest.lift, closeTo(0, 1e-9));
    expect(doveAt(.5).scaleX, closeTo(-1, 1e-9), reason: 'facing left');
    expect(doveAt(.9).scaleX, closeTo(1, 1e-9), reason: 'back to facing right');
    expect(doveAt(1).scaleX, closeTo(1, 1e-9));
    for (var i = 0; i <= 100; i++) {
      final p = doveAt(i / 100);
      expect(p.scaleX.abs(), greaterThanOrEqualTo(.12 - 1e-9));
      expect(p.opacity, inInclusiveRange(0, 1));
    }
  });
}
