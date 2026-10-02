import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyana_flutter/hybrid/bridge.dart';

class FakeHost implements ShellHost {
  bool? login;
  bool exited = false;
  @override
  double get statusBarHeight => 28;
  @override
  void setLoginStatusBar(bool value) => login = value;
  @override
  Future<void> exitApp() async => exited = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('id.goyana/device-test');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'GoyanaDevice.connectPrinter') {
        throw PlatformException(code: 'failed', message: 'Printer mati');
      }
      return {'granted': true};
    });
  });

  test('parses page requests and rejects malformed ones', () {
    final r = BridgeRequest.parse(
        '{"id":3,"plugin":"GoyanaDevice","method":"insets","args":{}}');
    expect(r?.id, 3);
    expect(r?.method, 'insets');
    expect(BridgeRequest.parse('not json'), isNull);
    expect(BridgeRequest.parse('{"id":"x"}'), isNull);
  });

  test('status bar and inset are answered by Flutter', () async {
    final host = FakeHost();
    final bridge = NativeBridge(host, channel: channel);
    final inset = await bridge.handle(const BridgeRequest(1, 'GoyanaDevice', 'insets', {}));
    expect(inset.value, {'top': 28.0});
    await bridge.handle(const BridgeRequest(2, 'GoyanaDevice', 'loginBar', {'login': true}));
    expect(host.login, isTrue);
    expect(calls, isEmpty);
  });

  test('device calls go to Android and errors keep their message', () async {
    final bridge = NativeBridge(FakeHost(), channel: channel);
    final ok = await bridge.handle(
        const BridgeRequest(1, 'GoyanaDevice', 'requestAccess', {'alias': 'camera'}));
    expect(ok.ok, isTrue);
    expect(calls.single.method, 'GoyanaDevice.requestAccess');
    final fail = await bridge.handle(
        const BridgeRequest(2, 'GoyanaDevice', 'connectPrinter', {'address': 'AA'}));
    expect(fail.ok, isFalse);
    expect(fail.script(2), contains('"Printer mati"'));
  });

  test('unknown native methods are blocked', () async {
    final bridge = NativeBridge(FakeHost(), channel: channel);
    final r = await bridge.handle(const BridgeRequest(1, 'System', 'exec', {}));
    expect(r.ok, isFalse);
    expect(calls, isEmpty);
  });
}
