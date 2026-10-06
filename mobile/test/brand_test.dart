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
    'First opening plays the 3s bird intro and stores an independent marker',
    (tester) async {
      final store = MemoryKvStore();
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrandIntro(ready: true, store: store, onDone: () => done++),
        ),
      );
      await tester.pump();
      expect(find.text('G'), findsOneWidget);
      expect(find.text('KASIR LAUNDRY'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2900));
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
  testWidgets('Later openings also take 3s', (tester) async {
    final store = MemoryKvStore({brandIntroKey: '1'});
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntro(ready: true, store: store, onDone: () => done++),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2900));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 120));
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
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1600));
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
  test('Bird flies in flapping, perches on the G and folds its wings', () {
    expect(birdAt(0).alpha, 0, reason: 'invisible at the very start');
    final fly = birdAt(.3);
    expect(fly.y, lessThan(14), reason: 'still above the perch');
    expect(fly.alpha, closeTo(1, 1e-9));
    final land = birdAt(.55);
    expect(land.x, closeTo(92, 1e-9));
    expect(land.y, closeTo(14, 1e-9));
    final rest = birdAt(1);
    expect(rest.x, closeTo(92, 1e-9));
    expect(rest.y, closeTo(14, 1e-9));
    expect(rest.flap, closeTo(-12, 1e-9), reason: 'wings folded');
    expect(rest.scale, closeTo(.8, 1e-9));
    final flaps = {
      for (var i = 8; i <= 55; i++) birdAt(i / 100).flap.round(),
    };
    expect(flaps.length, greaterThan(10), reason: 'wings really move');
  });
  test('Name letters appear one after another', () {
    expect(letterProgress(.5, 0), closeTo(0, 1e-9));
    expect(letterProgress(.62, 0), greaterThan(letterProgress(.62, 3)));
    for (var i = 0; i < 6; i++) {
      expect(letterProgress(1, i), closeTo(1, 1e-9));
    }
  });
}
