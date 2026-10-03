import 'dart:convert';

import 'package:flutter/services.dart';

/// Status bar style + top inset the web page needs, owned by the Flutter shell.
abstract class ShellHost {
  double get statusBarHeight;
  void setLoginStatusBar(bool login);
  Future<void> exitApp();
}

/// One request posted by `web_bridge/capacitor.js`.
class BridgeRequest {
  const BridgeRequest(this.id, this.plugin, this.method, this.args);

  final int id;
  final String plugin;
  final String method;
  final Map<String, dynamic> args;

  static BridgeRequest? parse(String message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map) return null;
      final id = data['id'];
      final plugin = data['plugin'];
      final method = data['method'];
      if (id is! int || plugin is! String || method is! String) return null;
      final args = data['args'];
      return BridgeRequest(
        id,
        plugin,
        method,
        args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }
}

/// Result sent back to the page as `__goyanaNative.finish(id, ok, value)`.
class BridgeResult {
  const BridgeResult.ok(this.value) : ok = true;
  const BridgeResult.error(String message)
      : ok = false,
        value = message;

  final bool ok;
  final Object? value;

  String script(int id) =>
      'window.__goyanaNative&&window.__goyanaNative.finish($id,$ok,${jsonEncode(value)});';
}

/// Routes Capacitor-style plugin calls to Flutter or to the Android host
/// (`MainActivity.kt`, channel `id.goyana/device`).
class NativeBridge {
  NativeBridge(this.host, {MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('id.goyana/device');

  final ShellHost host;
  final MethodChannel _channel;

  /// Methods the page may call. Anything else is rejected, so web content
  /// cannot reach arbitrary native code.
  static const allowed = <String, Set<String>>{
    'GoyanaDevice': {
      'requestAccess', 'permissions', 'openSettings', 'bluetoothSettings',
      'loginBar', 'insets', 'contacts', 'pairedPrinters', 'connectPrinter',
      'testPrint', 'printText', 'printerStatus', 'disconnectPrinter',
    },
    'Geolocation': {'getCurrentPosition', 'checkPermissions', 'requestPermissions'},
    'LocalNotifications': {
      'checkPermissions', 'requestPermissions', 'schedule', 'cancel', 'getPending',
    },
    'Files': {'save', 'share'},
    'Share': {'share'},
    'Clipboard': {'write', 'read'},
    'Print': {'html'},
    'App': {'exitApp', 'openUrl'},
  };

  Future<BridgeResult> handle(BridgeRequest request) async {
    final methods = allowed[request.plugin];
    if (methods == null || !methods.contains(request.method)) {
      return BridgeResult.error(
          'Fitur ${request.plugin}.${request.method} belum tersedia di aplikasi ini');
    }
    switch ('${request.plugin}.${request.method}') {
      case 'GoyanaDevice.insets':
        return BridgeResult.ok({'top': host.statusBarHeight});
      case 'GoyanaDevice.loginBar':
        host.setLoginStatusBar(request.args['login'] == true);
        return const BridgeResult.ok(null);
      case 'App.exitApp':
        await host.exitApp();
        return const BridgeResult.ok(null);
      case 'Share.share':
        return _native('Files', 'share', request.args);
    }
    return _native(request.plugin, request.method, request.args);
  }

  Future<BridgeResult> _native(String plugin, String method, Map<String, dynamic> args) async {
    try {
      final value = await _channel.invokeMethod<Object?>('$plugin.$method', args);
      return BridgeResult.ok(value);
    } on PlatformException catch (e) {
      return BridgeResult.error(e.message ?? 'Perintah perangkat gagal');
    } on MissingPluginException {
      return const BridgeResult.error('Fitur perangkat belum tersedia');
    }
  }
}
