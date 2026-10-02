import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/app.dart';
import 'package:goyana_flutter/api.dart';

class FakeApi implements GoyanaApi {
  bool loggedOut = false;
  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<Map<String, dynamic>> profile() async => {
    'business': {'id': 1, 'name': 'Laundry Uji'},
    'access': {'package': 'Basic', 'source': 'trial', 'read_only': false},
    'outlets': [{'id': 1, 'name': 'Outlet Pusat'}],
  };
  @override
  Future<void> logout() async { loggedOut = true; }
}
void main() {
  for (final width in [320.0, 600.0, 800.0, 1280.0]) {
    testWidgets('Account panels adapt at width $width without overflow', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(GoyanaApp(apiFactory: (_) => FakeApi()));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'https://uji.example.test');
      await tester.enterText(fields.at(1), 'owner@example.test');
      await tester.enterText(fields.at(2), 'PasswordAman123');
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final package = tester.getTopLeft(find.text('PAKET USAHA'));
      final outlet = tester.getTopLeft(find.text('OUTLET'));
      if (width >= 800) {
        expect(outlet.dx, greaterThan(package.dx));
        expect(outlet.dy, closeTo(package.dy, 1));
      } else {
        expect(outlet.dy, greaterThan(package.dy));
      }
    });
  }

  testWidgets('Validates form and never invents business data before login', (tester) async {
    await tester.pumpWidget(const GoyanaApp());
    expect(find.text('Laundry Uji'), findsNothing);
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Isi alamat server uji.'), findsOneWidget);
  });
  testWidgets('Login loads API business and logout clears it', (tester) async {
    final api = FakeApi();
    await tester.pumpWidget(GoyanaApp(apiFactory: (_) => api));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'https://uji.example.test');
    await tester.enterText(fields.at(1), 'owner@example.test');
    await tester.enterText(fields.at(2), 'PasswordAman123');
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Laundry Uji'), findsOneWidget);
    expect(find.text('Outlet Pusat'), findsOneWidget);
    await tester.ensureVisible(find.text('Keluar'));
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(api.loggedOut, isTrue);
    expect(find.text('Laundry Uji'), findsNothing);
  });
  test('Refuses insecure production-style addresses and credential URLs', () {
    expect(() => HttpGoyanaApi('http://public.example.test'), throwsA(isA<ApiFailure>()));
    expect(() => HttpGoyanaApi('https://secret@public.example.test'), throwsA(isA<ApiFailure>()));
    expect(() => HttpGoyanaApi('https://public.example.test/other'), throwsA(isA<ApiFailure>()));
    expect(() => HttpGoyanaApi('https://public.example.test'), returnsNormally);
  });
}
