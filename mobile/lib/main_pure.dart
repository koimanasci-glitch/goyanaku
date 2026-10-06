import 'package:flutter/material.dart';

import 'core/store.dart';
import 'pure/pure_shell.dart';

/// Pintu masuk "Mode Murni": seluruh aplikasi dari Dart, tanpa WebView/HTML.
/// Membaca kunci penyimpanan yang sama dengan versi hybrid.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GOYANA',
    home: PureShell(store: DeviceKvStore()),
  ));
}
