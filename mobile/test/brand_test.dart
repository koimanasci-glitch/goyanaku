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
    'First opening plays the 1.1s butterfly intro and stores an independent marker',
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
      await tester.pump(const Duration(milliseconds: 1000));
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
  testWidgets('Later openings take 0.8s', (tester) async {
    final store = MemoryKvStore({brandIntroKey: '1'});
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntro(ready: true, store: store, onDone: () => done++),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
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
      await tester.pump(const Duration(milliseconds: 900));
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
  test('Butterfly starts above the logo and lands on the G', () {
    final (x0, y0, _) = ButterflyPainter.poseAt(0, 800);
    final (x1, y1, a1) = ButterflyPainter.poseAt(1, 800);
    expect(y0, lessThan(-300), reason: 'starts above the screen top');
    expect(x0, greaterThan(x1));
    expect((x1, y1), (36.0, 12.0));
    expect(a1, closeTo(.45, 1e-9));
    expect(ButterflyPainter.openAt(.72), closeTo(.8, 1e-9));
  });
}
