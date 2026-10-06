import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/native/form_page.dart';
import 'package:goyana_flutter/native/login_screen.dart';

class _Actions implements FormActions {
  final log = <String>[];
  @override
  void fmInput(int index, Object value) => log.add('input:$index:$value');
  @override
  void fmButton(int index) => log.add('button:$index');
  @override
  void scan() {}
  @override
  void nav(String pageId) {}
  @override
  void fmBack() {}
  @override
  void fmToggle(int index) {}
  @override
  void fmRadio(int index) {}
  @override
  void fmFile(String inputId) {}
  @override
  void fmTap(int index) {}
  @override
  void fmScoped(String scope, String kind, int index, [Object? value]) {}
}

const _items = <Map<String, dynamic>>[
  {'type': 'title', 't': 'GOYANA'},
  {'type': 'input', 'v': '', 'ph': 'user', 'i': 0},
  {'type': 'input', 'v': '', 'ph': 'Password', 'secret': true, 'i': 1},
  {'type': 'button', 't': 'MASUK', 'primary': true, 'i': 0},
  {'type': 'button', 't': 'Lupa password?', 'i': 1},
];

void main() {
  test('Bindings find user, password, login and forgot buttons', () {
    final b = LoginBindings.from(_items)!;
    expect(b.user, 0);
    expect(b.pass, 1);
    expect(b.login, 0);
    expect(b.forgot, 1);
  });
  test('Bindings are null when the HTML form has another shape', () {
    expect(LoginBindings.from(const [
      {'type': 'input', 'v': '', 'i': 0},
    ]), isNull);
    expect(LoginBindings.from(const [
      {'type': 'input', 'v': '', 'i': 0},
      {'type': 'input', 'v': '', 'i': 1, 'secret': true},
    ]), isNull, reason: 'no login button');
  });
  testWidgets('Typing and pressing Login drives the HTML form', (tester) async {
    final a = _Actions();
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: NativeLogin(items: _items, bindings: LoginBindings.from(_items)!, actions: a),
    ));
    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(find.text('Masuk dengan Google'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-user')), 'admin@goyana.id');
    await tester.enterText(find.byKey(const Key('login-pass')), 'rahasia');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(a.log, contains('input:0:admin@goyana.id'));
    expect(a.log, contains('input:1:rahasia'));
    expect(a.log.last, 'button:0');
    await tester.ensureVisible(find.byKey(const Key('login-forgot')));
    await tester.tap(find.byKey(const Key('login-forgot')));
    expect(a.log.last, 'button:1');
  });
  testWidgets('Google and register buttons say they are not available yet', (tester) async {
    final a = _Actions();
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: NativeLogin(items: _items, bindings: LoginBindings.from(_items)!, actions: a),
    ));
    await tester.ensureVisible(find.byKey(const Key('login-google')));
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pump();
    expect(find.textContaining('belum tersedia'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('login-register')));
    await tester.tap(find.byKey(const Key('login-register')));
    await tester.pump();
    expect(find.textContaining('menyusul'), findsOneWidget);
    expect(a.log, isEmpty, reason: 'neither touches the HTML login');
  });
}
