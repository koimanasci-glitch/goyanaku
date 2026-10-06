import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/core/store.dart';
import 'package:goyana_flutter/native/guide_intro.dart';

Future<void> _open(WidgetTester tester, MemoryKvStore store, VoidCallback onDone) =>
    tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GuideIntro(store: store, onDone: onDone))),
    );

void main() {
  test('Guide has five distinct slides, chatbot text names the real plan', () {
    expect(guideSlides.length, 5);
    expect(guideSlides.map((s) => s.title).toSet().length, 5);
    expect(guideSlides.last.body, contains('paket Gold ke atas'));
    expect(guideSlides.map((s) => s.body).join(), isNot(contains('SUPER PRO')));
  });

  testWidgets('Next/back walk the five slides and the last button finishes', (
    tester,
  ) async {
    final store = MemoryKvStore();
    var done = 0;
    await _open(tester, store, () => done++);
    await tester.pumpAndSettle();
    expect(find.text('Catat pesanan, cetak struk & label barcode dengan cepat dan rapi.'), findsOneWidget);
    expect(find.text('KEMBALI'), findsNothing, reason: 'no back on the first slide');
    expect(find.text('LANJUT'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('guide-next')));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('paket Gold ke atas'), findsOneWidget);
    expect(find.text('MULAI'), findsOneWidget);
    expect(find.text('KEMBALI'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-prev')));
    await tester.pumpAndSettle();
    expect(find.text('LANJUT'), findsOneWidget);
    expect(find.text('Atur hingga beberapa cabang dalam satu aplikasi. Mudah dipantau dari mana saja.'), findsOneWidget);
    expect(done, 0);
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(await store.get(guideSeenKey), '1');
  });

  testWidgets('Lewati closes at once and remembers it', (tester) async {
    final store = MemoryKvStore();
    var done = 0;
    await _open(tester, store, () => done++);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-skip')));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(await store.get(guideSeenKey), '1');
  });

  testWidgets('Each slide shows its illustration without errors', (tester) async {
    await _open(tester, MemoryKvStore(), () {});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
